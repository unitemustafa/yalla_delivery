import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_exception.dart';
import '../domain/app_release.dart';
import 'app_update_models.dart';

class AppUpdateApi {
  AppUpdateApi({http.Client? client, String Function()? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? (() => AuthSession.apiBaseUrl);

  final http.Client _client;
  final String Function() _baseUrl;

  Future<AppRelease?> latest(int installedVersion) async {
    final uri = Uri.parse(
      '${_baseUrl()}/dashboard/app-updates/latest/',
    ).replace(queryParameters: {'version_code': '$installedVersion'});
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw ApiException(
        'تعذّر فحص التحديثات.',
        statusCode: response.statusCode,
      );
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic> || !data.containsKey('update')) {
      throw const FormatException('Missing release response.');
    }
    if (data['update'] == null) return null;
    final release = parseAppRelease(data['update']);
    return release.versionCode > installedVersion ? release : null;
  }

  void dispose() => _client.close();
}
