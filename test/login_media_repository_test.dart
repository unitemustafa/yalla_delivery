import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yalla_home/features/auth/data/login_media.dart';
import 'package:yalla_home/features/auth/data/login_media_repository.dart';
import 'package:yalla_home/core/domain/api_result.dart';
import 'package:yalla_home/features/auth/domain/load_delivery_media.dart';

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

  test('maps delivery focus and bounds invalid coordinates', () async {
    final media = LoginMediaModel.fromJson({
      'delivery_login_url': 'https://example.com/login.webp',
      'delivery_login_focus': {'x': 1.4, 'y': -1},
    });

    expect(media.focusX, 1);
    expect(media.focusY, 0);
  });

  test('use case preserves typed infrastructure failures', () async {
    final repository = LoginMediaRepository(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    final load = LoadDeliveryMedia(repository);
    final result = await load();
    expect(result, isA<ApiFailure>());
    expect((result as ApiFailure).reason, ApiFailureReason.network);
    load.dispose();
  });

  test(
    'missing media is a successful bundled fallback, malformed media fails',
    () async {
      final absent = LoginMediaRepository(
        client: MockClient(
          (_) async => http.Response('{"delivery_login_url":null}', 200),
        ),
      );
      expect(await absent.load(), isA<ApiSuccess>());
      absent.dispose();
      final invalid = LoginMediaRepository(
        client: MockClient(
          (_) async =>
              http.Response('{"delivery_login_url":"file:///secret"}', 200),
        ),
      );
      final result = await invalid.load();
      expect((result as ApiFailure).reason, ApiFailureReason.invalidResponse);
      invalid.dispose();
    },
  );
}
