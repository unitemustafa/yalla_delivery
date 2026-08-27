import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../network/api_exception.dart';

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

  Future<http.Response> delete(String path, {required String? accessToken}) {
    return withRequestTimeout(
      _client.delete(
        uri(path),
        headers: {'Authorization': 'Bearer $accessToken'},
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
      request.send(),
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
      throw const ApiException(
        'انتهت مهلة الاتصال. تحقق من الإنترنت وحاول مرة أخرى.',
      );
    } on http.ClientException {
      throw const ApiException('تعذر الاتصال بالخادم. حاول مرة أخرى.');
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
    if (normalized.contains('this account belongs to an admin')) {
      return _localizedCode('admin_account_not_allowed');
    }
    if (normalized.contains('this account belongs to a client')) {
      return _localizedCode('client_account_not_allowed');
    }
    if (normalized.contains('this login is only for representative accounts')) {
      return _localizedCode('representative_account_required');
    }
    if (normalized.contains('account email has not been verified')) {
      return 'الحساب لم يتم تفعيله بعد.';
    }
    if (normalized.contains('not found')) {
      return 'المسار غير موجود. تأكد من إعداد رابط الخادم.';
    }
    return message;
  }

  String _localizedCode(String code) {
    return switch (code.trim()) {
      'admin_account_not_allowed' =>
        'هذا حساب مسؤول، سجّل الدخول من لوحة الإدارة.',
      'client_account_not_allowed' => 'هذا حساب عميل، استخدم تطبيق يلا ماركت.',
      'representative_account_required' =>
        'تسجيل الدخول هنا مخصص لحسابات الطيارين فقط.',
      'account_inactive' => 'تم إيقاف حسابك. تواصل مع الدعم.',
      'session_expired' || 'token_not_valid' => 'انتهت الجلسة.',
      'rate_limited' => 'طلبات كتير في وقت قصير. استنى شوية وحاول تاني.',
      _ => code,
    };
  }

  static const _invalidCredentialsMessage = 'الإيميل أو كلمة السر غير صحيحين.';
}
