import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/auth_session.dart';

class LoginMediaRepository {
  LoginMediaRepository({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  Future<String?> loadDeliveryImage() async {
    try {
      final uri = Uri.parse('${AuthSession.apiBaseUrl}/dashboard/app-media/');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final value = data['delivery_login_url'];
      if (value is! String) return null;
      final url = Uri.tryParse(value);
      return url != null && (url.scheme == 'https' || url.scheme == 'http')
          ? value
          : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
