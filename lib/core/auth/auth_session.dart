import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../network/api_exception.dart';
import 'auth_api_client.dart';
import 'auth_token_store.dart';
import 'password_changed_notifier.dart';
import 'session_expired_notifier.dart';

enum AuthRestoreResult { restored, noSession, expired, temporaryFailure }

typedef AuthNow = DateTime Function();
typedef AuthTimerFactory =
    Timer Function(Duration duration, void Function() callback);
typedef AuthDelay = Future<void> Function(Duration duration);

class AuthSession {
  AuthSession._({
    http.Client? client,
    AuthTokenStore? tokenStore,
    AuthNow? now,
    AuthTimerFactory? timerFactory,
    AuthDelay? delay,
    Duration requestTimeout = const Duration(seconds: 20),
    String? baseUrl,
  }) : _api = AuthApiClient(
         client: client ?? http.Client(),
         baseUrl: () => baseUrl ?? AuthSession.apiBaseUrl,
         requestTimeout: requestTimeout,
       ),
       _tokenStore = tokenStore ?? SecureAuthTokenStore(),
       _now = now ?? DateTime.now,
       _timerFactory = timerFactory ?? _createTimer,
       _delay = delay ?? ((duration) => Future<void>.delayed(duration));

  static final instance = AuthSession._();

  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  @visibleForTesting
  factory AuthSession.forTesting({
    required http.Client client,
    required AuthTokenStore tokenStore,
    AuthNow? now,
    AuthTimerFactory? timerFactory,
    AuthDelay? delay,
    Duration requestTimeout = const Duration(seconds: 20),
    String baseUrl = 'http://localhost/api/v1',
  }) {
    return AuthSession._(
      client: client,
      tokenStore: tokenStore,
      now: now,
      timerFactory: timerFactory,
      delay: delay,
      requestTimeout: requestTimeout,
      baseUrl: baseUrl,
    );
  }

  static String get apiBaseUrl {
    final configured = _configuredApiBaseUrl.trim();

    if (configured.isEmpty && kReleaseMode) {
      throw StateError(
        'API_BASE_URL is required for release builds. '
        'Provide it using --dart-define=API_BASE_URL=<url> or '
        '--dart-define-from-file=env/production.json.',
      );
    }

    final baseUrl = configured.isNotEmpty
        ? configured
        : kIsWeb
        ? 'http://127.0.0.1:8000/api/v1'
        : 'http://10.0.2.2:8000/api/v1';

    return _normalizeApiBaseUrl(baseUrl);
  }

  static String _normalizeApiBaseUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl.trim());
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.isEmpty) return uri.replace(path: '/api/v1').toString();
    return uri.replace(path: path).toString();
  }

  final AuthApiClient _api;
  final AuthTokenStore _tokenStore;
  final AuthNow _now;
  final AuthTimerFactory _timerFactory;
  final AuthDelay _delay;

  StoredAuthTokens? _tokens;
  Future<void>? _refreshInFlight;
  Timer? _expiryTimer;
  bool _sessionExpiredEventSent = false;
  bool _passwordChanged = false;
  bool _accountInactiveHandled = false;
  int _sessionVersion = 0;

  Map<String, dynamic>? currentUser;

  String? get _accessToken => _tokens?.accessToken;

  @visibleForTesting
  StoredAuthTokens? get tokensForTesting => _tokens;

  Uri uri(String path) => _api.uri(path);

  String? absoluteUrl(Object? value) => _api.absoluteUrl(value);

  Future<AuthRestoreResult> restore() async {
    final restoredTokens = await _tokenStore.read();
    if (restoredTokens == null) return AuthRestoreResult.noSession;
    if (restoredTokens.sessionHasExpired(_now().toUtc())) {
      await _expireSession(notify: true);
      return AuthRestoreResult.expired;
    }

    _tokens = restoredTokens;
    _sessionExpiredEventSent = false;
    _passwordChanged = false;
    _accountInactiveHandled = false;
    _scheduleExpiryTimer();

    try {
      await _refreshOnce();
      final user = await _fetchCurrentUserForRestore();
      if (user['role'] == 'representative') {
        currentUser = user;
        return AuthRestoreResult.restored;
      }
      await _expireSession(notify: true);
      return AuthRestoreResult.expired;
    } on ApiException catch (error) {
      if (_isAuthenticationFailure(error.statusCode)) {
        final passwordChanged = error.message == _passwordChangedMessage;
        if (passwordChanged) _notifyPasswordChanged();
        await _expireSession(notify: !passwordChanged);
        return AuthRestoreResult.expired;
      }
      return AuthRestoreResult.temporaryFailure;
    } catch (_) {
      return AuthRestoreResult.temporaryFailure;
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
    required bool remember,
  }) async {
    final cleanIdentifier = _api.removeWhitespace(identifier);
    final cleanPassword = _api.removeWhitespace(password);
    final response = await _api.postJson('auth/login/representative/', {
      'identifier': cleanIdentifier,
      'password': cleanPassword,
      'remember': remember,
    });
    final data = _api.decode(response);
    _accountInactiveHandled = false;
    await _handleAccountInactiveResponse(data, notify: false);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _api.responseException(
        response,
        data,
        '\u062a\u0639\u0630\u0631 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644.',
      );
    }

    final map = data as Map<String, dynamic>;
    final user = map['user'];
    if (user is! Map || user['role'] != 'representative') {
      await clear();
      throw const ApiException(
        '\u0627\u0633\u062a\u062c\u0627\u0628\u0629 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u063a\u064a\u0631 \u0645\u0643\u062a\u0645\u0644\u0629.',
      );
    }

    late final StoredAuthTokens tokens;
    try {
      tokens = tokensFromApiPayload(map);
    } on FormatException {
      await clear();
      throw const ApiException(
        '\u0627\u0633\u062a\u062c\u0627\u0628\u0629 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u063a\u064a\u0631 \u0645\u0643\u062a\u0645\u0644\u0629.',
      );
    }

    _sessionVersion += 1;
    _sessionExpiredEventSent = false;
    _passwordChanged = false;
    _accountInactiveHandled = false;
    await _activateTokens(tokens);
    currentUser = Map<String, dynamic>.from(user);
  }

  Future<dynamic> getJson(String path) async {
    final response = await _sendWithRefresh<http.Response>(
      send: () => _authorizedGet(path),
      statusCode: (response) => response.statusCode,
    );
    final data = _api.decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _api.responseException(
        response,
        data,
        '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a.',
      );
    }
    return data;
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final response = await _sendWithRefresh<http.Response>(
      send: () => _authorizedPost(path, body),
      statusCode: (response) => response.statusCode,
    );
    final data = _api.decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _api.responseException(
        response,
        data,
        '\u062a\u0639\u0630\u0631 \u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0637\u0644\u0628.',
      );
    }
    return data;
  }

  Future<dynamic> patchJson(String path, Map<String, dynamic> body) async {
    final response = await _sendWithRefresh<http.Response>(
      send: () => _authorizedPatch(path, body),
      statusCode: (response) => response.statusCode,
    );
    final data = _api.decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _api.responseException(
        response,
        data,
        '\u062a\u0639\u0630\u0631 \u062a\u062d\u062f\u064a\u062b \u0627\u0644\u0637\u0644\u0628.',
      );
    }
    return data;
  }

  Future<dynamic> deleteJson(String path) async {
    final response = await _sendWithRefresh<http.Response>(
      send: () => _authorizedDelete(path),
      statusCode: (response) => response.statusCode,
    );
    final data = _api.decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _api.responseException(
        response,
        data,
        '\u062a\u0639\u0630\u0631 \u062d\u0630\u0641 \u0627\u0644\u0639\u0646\u0635\u0631.',
      );
    }
    return data;
  }

  Future<dynamic> patchMultipart(
    String path, {
    required Map<String, String> fields,
    List<int>? proofBytes,
    String? proofName,
  }) async {
    Future<http.StreamedResponse> send() {
      return _api.patchMultipart(
        path,
        accessToken: _accessToken,
        fields: fields,
        proofBytes: proofBytes,
        proofName: proofName,
      );
    }

    final streamed = await _sendWithRefresh<http.StreamedResponse>(
      send: send,
      statusCode: (response) => response.statusCode,
    );
    final response = await _api.responseFromStream(streamed);
    final data = _api.decode(response);
    await _handleAccountInactiveResponse(data);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _api.responseException(
        response,
        data,
        '\u062a\u0639\u0630\u0631 \u062a\u0623\u0643\u064a\u062f \u0627\u0644\u062a\u0633\u0644\u064a\u0645.',
      );
    }
    return data;
  }

  Future<void> logout() async {
    try {
      final tokens = _tokens;
      if (tokens != null && !tokens.sessionHasExpired(_now().toUtc())) {
        if (!tokens.hasAccessToken ||
            tokens.accessExpiresSoon(_now().toUtc())) {
          await _refreshOnce();
        }
        final active = _tokens;
        if (active == null || !active.hasAccessToken) return;
        await _api.postJson('auth/logout/', {
          'refreshToken': active.refreshToken,
        }, accessToken: active.accessToken);
      }
    } catch (_) {
      // Local logout must still complete when the network is unavailable.
    } finally {
      await clear();
    }
  }

  Future<void> clear() async {
    _sessionVersion += 1;
    _tokens = null;
    _sessionExpiredEventSent = false;
    _passwordChanged = false;
    _accountInactiveHandled = false;
    _refreshInFlight = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    currentUser = null;
    await _tokenStore.clear();
  }

  Future<void> validateForForeground() async {
    await _ensureSessionStillActive();
    await _refreshAccessIfNeeded();
  }

  Future<Map<String, dynamic>> _fetchCurrentUserForRestore() async {
    final response = await _authorizedGet('auth/me/');
    final data = _api.decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _api.responseException(
        response,
        data,
        '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062d\u0633\u0627\u0628.',
      );
    }
    if (data is Map<String, dynamic>) return data;
    throw const ApiException(
      '\u062a\u0639\u0630\u0631 \u0642\u0631\u0627\u0621\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062d\u0633\u0627\u0628.',
    );
  }

  Future<http.Response> _authorizedGet(String path) {
    return _api.get(path, accessToken: _accessToken);
  }

  Future<http.Response> _authorizedPost(
    String path,
    Map<String, dynamic> body,
  ) {
    return _api.postJson(path, body, accessToken: _accessToken);
  }

  Future<http.Response> _authorizedPatch(
    String path,
    Map<String, dynamic> body,
  ) {
    return _api.patchJson(path, body, accessToken: _accessToken);
  }

  Future<http.Response> _authorizedDelete(String path) {
    return _api.delete(path, accessToken: _accessToken);
  }

  Future<T> _sendWithRefresh<T>({
    required Future<T> Function() send,
    required int Function(T response) statusCode,
  }) async {
    await _ensureSessionStillActive();
    await _refreshAccessIfNeeded();
    var response = await send();
    if (response is http.Response) {
      await _handleAccountInactiveResponse(_api.decode(response));
    }
    if (statusCode(response) == 401 && await _tryRefresh()) {
      response = await send();
      if (response is http.Response) {
        await _handleAccountInactiveResponse(_api.decode(response));
      }
      if (statusCode(response) == 401) {
        await _expireSession(notify: true);
      }
    }
    return response;
  }

  Future<void> _refreshAccessIfNeeded() async {
    final tokens = _tokens;
    if (tokens == null) return;
    if (!tokens.hasAccessToken || tokens.accessExpiresSoon(_now().toUtc())) {
      await _refreshOnce();
    }
  }

  Future<bool> _tryRefresh() async {
    try {
      await _refreshOnce();
      return _accessToken != null;
    } on ApiException catch (error) {
      final passwordChanged = error.message == _passwordChangedMessage;
      if (passwordChanged) _notifyPasswordChanged();
      if (passwordChanged || _isAuthenticationFailure(error.statusCode)) {
        await _expireSession(notify: !passwordChanged);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshOnce() async {
    final activeRefresh = _refreshInFlight;

    if (activeRefresh != null) {
      await activeRefresh;
      return;
    }

    final refreshFuture = _refresh();
    _refreshInFlight = refreshFuture;

    try {
      await refreshFuture;
    } finally {
      if (identical(_refreshInFlight, refreshFuture)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> _refresh() async {
    if (_isSessionExpired()) {
      throw const ApiException(
        '\u0627\u0646\u062a\u0647\u062a \u0627\u0644\u062c\u0644\u0633\u0629.',
      );
    }

    final refreshVersion = _sessionVersion;
    final current = _tokens;
    final refresh = current?.refreshToken;
    if (refresh == null) {
      throw const ApiException(
        '\u0644\u0627 \u062a\u0648\u062c\u062f \u062c\u0644\u0633\u0629 \u0645\u062d\u0641\u0648\u0638\u0629.',
      );
    }

    Future<http.Response> sendRefresh() {
      return _api.postJson('auth/refresh/', {'refreshToken': refresh});
    }

    var response = await sendRefresh();
    var data = _api.decode(response);
    if (response.statusCode == 429) {
      final retryAfter = _api.retryAfterSeconds(response, data) ?? 1;
      await _delay(Duration(seconds: retryAfter.clamp(1, 60).toInt()));
      if (refreshVersion != _sessionVersion || _isSessionExpired()) {
        throw const ApiException(
          '\u0627\u0646\u062a\u0647\u062a \u0627\u0644\u062c\u0644\u0633\u0629.',
        );
      }
      response = await sendRefresh();
      data = _api.decode(response);
    }
    await _handleAccountInactiveResponse(data);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (_api.isPasswordChangedResponse(data)) {
        throw const ApiException(_passwordChangedMessage, statusCode: 401);
      }
      throw _api.responseException(
        response,
        data,
        '\u0627\u0646\u062a\u0647\u062a \u0627\u0644\u062c\u0644\u0633\u0629.',
      );
    }

    if (refreshVersion != _sessionVersion) {
      throw const ApiException(
        '\u0627\u0646\u062a\u0647\u062a \u0627\u0644\u062c\u0644\u0633\u0629.',
      );
    }

    final map = data as Map<String, dynamic>;
    final next = tokensFromApiPayload(map);
    _validateSessionContinuity(current!, next);
    final activated = await _activateTokens(
      next,
      expectedVersion: refreshVersion,
    );
    if (!activated) {
      throw const ApiException(
        '\u0627\u0646\u062a\u0647\u062a \u0627\u0644\u062c\u0644\u0633\u0629.',
      );
    }
  }

  void _validateSessionContinuity(
    StoredAuthTokens current,
    StoredAuthTokens next,
  ) {
    if (current.mode != next.mode ||
        current.sessionStartedAt != next.sessionStartedAt ||
        current.absoluteExpiresAt != next.absoluteExpiresAt) {
      throw const FormatException('Refresh changed session identity.');
    }
  }

  bool _isSessionExpired() {
    final tokens = _tokens;
    return tokens == null || tokens.sessionHasExpired(_now().toUtc());
  }

  bool _isAuthenticationFailure(int? statusCode) {
    return statusCode == 400 || statusCode == 401 || statusCode == 403;
  }

  Future<void> _ensureSessionStillActive() async {
    if (!_isSessionExpired()) return;
    await _expireSession(notify: true);
    throw ApiException(
      _passwordChanged
          ? _passwordChangedMessage
          : '\u0627\u0646\u062a\u0647\u062a \u0627\u0644\u062c\u0644\u0633\u0629.',
    );
  }

  void _scheduleExpiryTimer() {
    _expiryTimer?.cancel();
    final tokens = _tokens;
    if (tokens == null) return;
    final delay = tokens.sessionDeadline.difference(_now().toUtc());
    _expiryTimer = _timerFactory(delay.isNegative ? Duration.zero : delay, () {
      unawaited(_expireSession(notify: true));
    });
  }

  Future<void> _expireSession({required bool notify}) async {
    final shouldNotify =
        notify && !_sessionExpiredEventSent && !_passwordChanged;
    _sessionVersion += 1;
    _tokens = null;
    _refreshInFlight = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    currentUser = null;
    await _tokenStore.clear();
    if (shouldNotify) {
      _sessionExpiredEventSent = true;
      SessionExpiredNotifier.instance.notifyExpired();
    }
  }

  Future<bool> _activateTokens(
    StoredAuthTokens tokens, {
    int? expectedVersion,
  }) async {
    if (expectedVersion != null && expectedVersion != _sessionVersion) {
      return false;
    }

    final previous = _tokens;
    _tokens = tokens;
    _scheduleExpiryTimer();
    try {
      await _tokenStore.save(tokens);
    } catch (_) {
      if (identical(_tokens, tokens)) {
        _tokens = previous;
        _scheduleExpiryTimer();
      }
      rethrow;
    }

    if (expectedVersion != null && expectedVersion != _sessionVersion) {
      final active = _tokens;
      if (active == null) {
        await _tokenStore.clear();
      } else if (active.refreshToken != tokens.refreshToken) {
        await _tokenStore.save(active);
      }
      return false;
    }
    return true;
  }

  @visibleForTesting
  void disposeForTesting() {
    _expiryTimer?.cancel();
    _api.close();
  }

  Future<void> _handleAccountInactiveResponse(
    dynamic data, {
    bool notify = true,
  }) async {
    if (!_api.hasErrorCode(data, 'account_inactive') ||
        _accountInactiveHandled) {
      return;
    }
    _accountInactiveHandled = true;
    await _expireSession(notify: notify);
  }

  void _notifyPasswordChanged() {
    if (_passwordChanged) return;
    _passwordChanged = true;
    PasswordChangedNotifier.instance.notifyPasswordChanged();
  }

  static const _passwordChangedMessage = 'تم تغيير كلمة المرور.';
}

Timer _createTimer(Duration duration, void Function() callback) {
  return Timer(duration, callback);
}
