import '../domain/login_media.dart';

/// Public login artwork returned by the app-media endpoint.
///
/// Focus coordinates are normalized so an invalid response can never move a
/// cover crop outside its bounds.
class LoginMediaModel extends LoginMedia {
  const LoginMediaModel({required super.url, super.focusX, super.focusY});

  factory LoginMediaModel.fromJson(Map<String, dynamic> json) {
    final url = json['delivery_login_url'];
    if (url is! String) throw const FormatException('Missing login image URL');
    final trimmedUrl = url.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('Unsafe login image URL');
    }
    final focus = json['delivery_login_focus'];
    return LoginMediaModel(
      url: trimmedUrl,
      focusX: _coordinate(focus is Map ? focus['x'] : null, 0.5),
      focusY: _coordinate(focus is Map ? focus['y'] : null, 0),
    );
  }

  static double _coordinate(Object? value, double fallback) {
    final number = switch (value) {
      num value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };
    if (number == null || !number.isFinite) return fallback;
    return number.clamp(0, 1).toDouble();
  }
}
