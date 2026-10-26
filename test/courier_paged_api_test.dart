import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yalla_home/core/auth/auth_session.dart';
import 'package:yalla_home/core/auth/auth_token_store.dart';
import 'package:yalla_home/core/domain/api_result.dart';
import 'package:yalla_home/features/deliveries/data/courier_orders_api.dart';
import 'package:yalla_home/features/deliveries/data/courier_orders_repository_impl.dart';
import 'package:yalla_home/features/deliveries/data/courier_notifications_api.dart';
import 'package:yalla_home/features/deliveries/data/courier_notifications_repository_impl.dart';
import 'package:yalla_home/features/deliveries/domain/courier_orders_use_cases.dart';

Future<AuthSession> _session(
  Future<http.Response> Function(http.Request) handler,
) async {
  final now = DateTime.utc(2030);
  final session = AuthSession.forTesting(
    now: () => now,
    tokenStore: InMemoryAuthTokenStore(),
    client: MockClient((request) async {
      if (request.url.path.endsWith('login/representative/')) {
        return _response({
          'accessToken': 'fixture-access',
          'refreshToken': 'fixture-refresh',
          'user': {'id': 1, 'role': 'representative'},
          'session': {
            'mode': 'temporary',
            'remember': false,
            'startedAt': now.toIso8601String(),
            'accessExpiresAt': now
                .add(const Duration(minutes: 15))
                .toIso8601String(),
            'refreshExpiresAt': now
                .add(const Duration(hours: 8))
                .toIso8601String(),
            'absoluteExpiresAt': now
                .add(const Duration(hours: 8))
                .toIso8601String(),
          },
        });
      }
      return handler(request);
    }),
  );
  addTearDown(session.disposeForTesting);
  await session.login(
    identifier: 'fixture',
    password: 'fixture',
    remember: false,
  );
  return session;
}

http.Response _response(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'active use case fetches a single 30-order page and server totals',
    () async {
      final paths = <Uri>[];
      final session = await _session((request) async {
        paths.add(request.url);
        return _response({
          'results': List.generate(
            30,
            (i) => {'id': i + 1, 'status': 'assigned'},
          ),
          'next': 'next',
          'summary': {
            'count': 300,
            'total_value': '3000.00',
            'total_delivery_fees': '300.00',
            'pickup_required_count': 200,
          },
        });
      });
      final useCase = LoadActiveCourierOrders(
        CourierOrdersRepositoryImpl(CourierOrdersApi(session: session)),
      );
      final result = await useCase.page();
      expect(paths, hasLength(1));
      expect(paths.single.queryParameters, {
        'scope': 'active',
        'page': '1',
        'page_size': '30',
      });
      final page = (result as ApiSuccess).data;
      expect(page.orders.length, 30);
      expect(page.totals.count, 300);
      expect(page.totals.pickupRequiredCount, 200);
      expect(page.hasNext, isTrue);
    },
  );
  test(
    'notification pages reuse embedded unread count without a second request',
    () async {
      final paths = <Uri>[];
      final session = await _session((request) async {
        paths.add(request.url);
        return _response({
          'results': List.generate(30, (i) => {'id': i + 1}),
          'count': 1000,
          'unread_count': 900,
          'next': 'next',
        });
      });
      final repository = CourierNotificationsRepositoryImpl(
        CourierNotificationsApi(session: session),
      );
      final result = await repository.loadPage();
      expect(paths, hasLength(1));
      expect(paths.single.queryParameters, {'page': '1', 'page_size': '30'});
      final page = (result as ApiSuccess).data;
      expect(page.items.length, 30);
      expect(page.unreadCount, 900);
      expect(page.count, 1000);
    },
  );
  test(
    'invalid notification metadata and duplicate rows map to typed failures',
    () async {
      var body = <String, Object?>{'results': [], 'count': 1000, 'next': null};
      final session = await _session((_) async => _response(body));
      final repository = CourierNotificationsRepositoryImpl(
        CourierNotificationsApi(session: session),
      );
      var result = await repository.loadPage();
      expect((result as ApiFailure).reason, ApiFailureReason.invalidResponse);
      body = {
        'results': [
          {'id': 1},
          {'id': 1},
        ],
        'count': 2,
        'unread_count': 1,
        'next': null,
      };
      result = await repository.loadPage();
      expect((result as ApiFailure).reason, ApiFailureReason.invalidResponse);
      body = {
        'results': List.generate(31, (i) => {'id': i}),
        'count': 31,
        'unread_count': 1,
        'next': null,
      };
      result = await repository.loadPage();
      expect((result as ApiFailure).reason, ApiFailureReason.invalidResponse);
    },
  );
}
