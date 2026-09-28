import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yalla_home/features/auth/data/login_media_repository.dart';

void main() {
  test('loads the delivery login image from the public endpoint', () async {
    final repository = LoginMediaRepository(
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/dashboard/app-media/'));
        return http.Response(
          '{"delivery_login_url":"https://example.com/login.webp"}',
          200,
        );
      }),
    );

    expect(
      await repository.loadDeliveryImage(),
      'https://example.com/login.webp',
    );
    repository.dispose();
  });

  test('uses the bundled image when the response is unavailable', () async {
    final repository = LoginMediaRepository(
      client: MockClient((_) async => http.Response('error', 500)),
    );

    expect(await repository.loadDeliveryImage(), isNull);
    repository.dispose();
  });
}
