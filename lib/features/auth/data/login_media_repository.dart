import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/auth_session.dart';
import '../../../core/domain/api_result.dart';
import '../domain/login_media.dart';
import '../domain/login_media_repository.dart';
import 'login_media.dart';

class LoginMediaRepository implements LoginMediaSource {
  LoginMediaRepository({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  Future<String?> loadDeliveryImage() async {
    return (await loadDeliveryMedia())?.url;
  }

  Future<LoginMedia?> loadDeliveryMedia() async {
    return switch (await load()) {
      ApiSuccess<LoginMedia?>(:final data) => data,
      ApiFailure<LoginMedia?>() => null,
    };
  }

  @override
  Future<ApiResult<LoginMedia?>> load() async {
    try {
      final uri = Uri.parse('${AuthSession.apiBaseUrl}/dashboard/app-media/');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return const ApiFailure(ApiFailureReason.server);
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return const ApiFailure(ApiFailureReason.invalidResponse);
      }
      if (data['delivery_login_url'] == null) return const ApiSuccess(null);
      return ApiSuccess(LoginMediaModel.fromJson(data));
    } on FormatException {
      return const ApiFailure(ApiFailureReason.invalidResponse);
    } catch (_) {
      return const ApiFailure(ApiFailureReason.network);
    }
  }

  @override
  void dispose() => _client.close();
}
