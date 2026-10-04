import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../network/api_exception.dart';
import '../texts/app_texts.dart';

class AuthApiClient {
  AuthApiClient({
    required http.Client client,
    required String Function() baseUrl,
    required Duration requestTimeout,
  }) : _client = client,
       _baseUrl = baseUrl,
       _requestTimeout = requestTimeout;

  final http.Client _client;
  final String Function() _baseUrl;
  final Duration _requestTimeout;

  Uri uri(String path) {
    final parsed = Uri.tryParse(path.trim());
    if (parsed != null && parsed.hasScheme) {
      final base = Uri.parse(_baseUrl());
      if (parsed.origin != base.origin) {
        throw ArgumentError.value(path, 'path', 'Must use the API origin.');
      }
      return parsed;
    }
    return Uri.parse('${_baseUrl()}/${path.replaceFirst(RegExp(r'^/+'), '')}');
  }

  String? absoluteUrl(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    final root = Uri.parse(_baseUrl()).origin;
    return '$root/${text.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Future<http.Response> get(String path, {required String? accessToken}) {
    return withRequestTimeout(
      _client.get(uri(path), headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<http.Response> postJson(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) {
    return withRequestTimeout(
      _client.post(
        uri(path),
        headers: {
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
  }

  Future<http.Response> patchJson(
    String path,
    Map<String, dynamic> body, {
    required String? accessToken,
  }) {
    return withRequestTimeout(
      _client.patch(
        uri(path),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
  }

  Future<http.Response> delete(
    String path, {
    required String? accessToken,
    Map<String, dynamic>? body,
  }) {
    return withRequestTimeout(
      _client.delete(
        uri(path),
        headers: {
          'Authorization': 'Bearer $accessToken',
          if (body != null) 'Content-Type': 'application/json',
        },
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<http.StreamedResponse> patchMultipart(
    String path, {
    required String? accessToken,
    required Map<String, String> fields,
    List<int>? proofBytes,
    String? proofName,
  }) {
    final request = http.MultipartRequest('PATCH', uri(path));
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.fields.addAll(fields);
    if (proofBytes != null && proofName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'delivery_proof',
          proofBytes,
          filename: proofName,
        ),
      );
    }
    return withRequestTimeout(
      _client.send(request),
      timeout: const Duration(seconds: 45),
    );
  }

  Future<http.Response> responseFromStream(http.StreamedResponse response) {
    return withRequestTimeout(
      http.Response.fromStream(response),
      timeout: const Duration(seconds: 45),
    );
  }

  Future<T> withRequestTimeout<T>(
    Future<T> request, {
    Duration? timeout,
  }) async {
    try {
      return await request.timeout(timeout ?? _requestTimeout);
    } on TimeoutException {
      throw const ApiException(AuthTexts.connectionTimeout);
    } on http.ClientException {
      throw const ApiException(CommonTexts.serverConnectionFailed);
    }
  }

  dynamic decode(http.Response response) {
    if (response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  bool hasErrorCode(dynamic data, String expectedCode) {
    return data is Map && data['code']?.toString() == expectedCode;
  }

  bool isPasswordChangedResponse(dynamic data) {
    if (hasErrorCode(data, 'password_changed')) return true;
    if (data is! Map) return false;
    final detail = data['detail']?.toString().toLowerCase() ?? '';
    return detail.contains('password changed');
  }

  ApiException responseException(
    http.Response response,
    dynamic data,
    String fallback,
  ) {
    return ApiException(
      _message(data, fallback),
      statusCode: response.statusCode,
      code: data is Map ? data['code']?.toString() : null,
      retryAfterSeconds: retryAfterSeconds(response, data),
    );
  }

  int? retryAfterSeconds(http.Response response, dynamic data) {
    if (data is Map) {
      final value = data['retry_after_seconds'];
      if (value is num && value > 0) return value.ceil();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    final parsed = int.tryParse(response.headers['retry-after'] ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  String removeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  void close() => _client.close();

  String _message(dynamic data, String fallback) {
    if (data is String && data.trim().isNotEmpty) {
      return _localizedMessage(data);
    }
    if (data is List) {
      for (final value in data) {
        final message = _message(value, '');
        if (message.isNotEmpty) return message;
      }
    }
    if (data is Map) {
      if (data['code'] is String) {
        return _localizedCode(data['code'] as String);
      }
      if (data['detail'] is String) {
        return _localizedMessage(data['detail'] as String);
      }
      for (final value in data.values) {
        final message = _message(value, '');
        if (message.isNotEmpty) return message;
      }
    }
    return _localizedMessage(fallback);
  }

  String _localizedMessage(String message) {
    final normalized = message.trim().toLowerCase();
    if (normalized.contains('invalid email or password')) {
      return _invalidCredentialsMessage;
    }
    if (normalized.contains('this account belongs to an admin') ||
        normalized.contains('this account belongs to a client') ||
        normalized.contains('this login is only for representative accounts')) {
      return _invalidCredentialsMessage;
    }
    if (normalized.contains('account email has not been verified')) {
      return AuthTexts.accountNotActivated;
    }
    if (normalized.contains('not found')) {
      return AuthTexts.routeNotFound;
    }
    return message;
  }

  String _localizedCode(String code) {
    return switch (code.trim()) {
      'admin_account_not_allowed' ||
      'client_account_not_allowed' ||
      'representative_account_required' => _invalidCredentialsMessage,
      'account_inactive' => AuthTexts.accountDisabled,
      'session_expired' || 'token_not_valid' => AuthTexts.sessionEnded,
      'rate_limited' => AuthTexts.rateLimited,
      _ => code,
    };
  }

  static const _invalidCredentialsMessage = AuthTexts.invalidCredentials;
}
