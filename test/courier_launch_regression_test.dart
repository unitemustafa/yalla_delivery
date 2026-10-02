import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yalla_home/core/auth/auth_session.dart';
import 'package:yalla_home/core/auth/auth_token_store.dart';
import 'package:yalla_home/core/network/api_exception.dart';
import 'package:yalla_home/core/notifications/courier_push_service.dart';
import 'package:yalla_home/features/deliveries/data/courier_orders_api.dart';
import 'package:yalla_home/features/deliveries/data/courier_orders_repository_impl.dart';
import 'package:yalla_home/features/deliveries/presentation/widgets/delivery_confirmation_sheet.dart';
import 'package:yalla_home/core/domain/api_result.dart';

final _now = DateTime.utc(2030, 1, 1);

class _DelayedClearStore extends InMemoryAuthTokenStore {
  final started = Completer<void>();
  final finish = Completer<void>();
  @override
  Future<void> clear() async {
    started.complete();
    await finish.future;
    await super.clear();
  }
}

class _DeferredMultipartClient extends http.BaseClient {
  final bodyStarted = Completer<void>();
  late final StreamController<List<int>> body = StreamController(
    onListen: () => bodyStarted.complete(),
  );
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'PATCH') {
      return http.StreamedResponse(body.stream, 403);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(_login()))),
      200,
    );
  }
}

Map<String, dynamic> _login({
  String refresh = 'refresh',
  String access = 'access',
  int id = 1,
}) => {
  'accessToken': access,
  'refreshToken': refresh,
  'session': {
    'mode': 'temporary',
    'remember': false,
    'startedAt': _now.toIso8601String(),
    'absoluteExpiresAt': _now.add(const Duration(hours: 8)).toIso8601String(),
    'accessExpiresAt': _now.add(const Duration(minutes: 15)).toIso8601String(),
    'refreshExpiresAt': _now.add(const Duration(hours: 8)).toIso8601String(),
  },
  'user': {'id': id, 'role': 'representative'},
};
http.Response _response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);
Map<String, dynamic> _row(int id, {String status = 'assigned'}) => {
  'id': id,
  'status': status,
  'created_at': _now.toIso8601String(),
  'items': [
    {
      'quantity': 1,
      'unit_price': '15',
      'additions': [
        {'id': 3, 'name': 'Extra', 'price': '5'},
      ],
    },
  ],
};
Map<String, dynamic> _page(List<Object> rows, {bool next = false}) => {
  'results': rows,
  'next': next ? 'next' : null,
  'summary': {
    'count': 301,
    'total_value': '4500.00',
    'total_delivery_fees': '301.00',
  },
};

Future<AuthSession> _session(
  Future<http.Response> Function(http.Request) handler,
) async {
  final session = AuthSession.forTesting(
    client: MockClient(
      (request) async => request.url.path.endsWith('login/representative/')
          ? _response(_login())
          : handler(request),
    ),
    tokenStore: InMemoryAuthTokenStore(),
    now: () => _now,
  );
  await session.login(identifier: 'test', password: 'test', remember: false);
  addTearDown(session.disposeForTesting);
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'multipart response body from previous session cannot disable replacement login',
    () async {
      final client = _DeferredMultipartClient();
      final session = AuthSession.forTesting(
        client: client,
        tokenStore: InMemoryAuthTokenStore(),
        now: () => _now,
      );
      addTearDown(session.disposeForTesting);
      await session.login(
        identifier: 'first',
        password: 'test',
        remember: false,
      );
      final upload = session.patchMultipart(
        'courier/orders/7/status/',
        fields: {'status': 'delivered'},
        proofBytes: [1, 2],
        proofName: 'proof.jpg',
      );
      final rejected = expectLater(
        upload,
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'session_changed',
          ),
        ),
      );
      await client.bodyStarted.future;
      await session.clear();
      await session.login(
        identifier: 'replacement',
        password: 'test',
        remember: false,
      );
      client.body.add(utf8.encode(jsonEncode({'code': 'account_inactive'})));
      await client.body.close();
      await rejected;
      expect(session.currentUser, isNotNull);
    },
  );

  test(
    'delayed login response cannot replace a newer completed login',
    () async {
      final pending = Completer<http.Response>();
      var logins = 0;
      final session = AuthSession.forTesting(
        client: MockClient((_) async {
          if (++logins == 1) return pending.future;
          return _response(_login(id: 2, refresh: 'new'));
        }),
        tokenStore: InMemoryAuthTokenStore(),
        now: () => _now,
      );
      addTearDown(session.disposeForTesting);
      final first = session.login(
        identifier: 'old',
        password: 'test',
        remember: false,
      );
      final rejected = expectLater(first, throwsA(isA<ApiException>()));
      await Future<void>.delayed(Duration.zero);
      await session.login(identifier: 'new', password: 'test', remember: false);
      pending.complete(_response(_login(id: 1)));
      await rejected;
      expect(session.currentUser!['id'], 2);
      expect(session.tokensForTesting!.refreshToken, 'new');
    },
  );

  test(
    'delayed old logout cannot revoke or clear the replacement account',
    () async {
      final release = Completer<void>();
      var blacklists = 0;
      final session = await _session((_) async {
        blacklists++;
        return _response({});
      });
      session.beforeLogout = () => release.future;
      final logout = session.logout();
      await session.login(
        identifier: 'replacement',
        password: 'test',
        remember: false,
      );
      release.complete();
      await logout;
      expect(blacklists, 0);
      expect(session.currentUser, isNotNull);
      expect(session.tokensForTesting, isNotNull);
    },
  );

  test(
    'slow previous token clear is ordered before replacement save and cleanup',
    () async {
      final store = _DelayedClearStore();
      final session = AuthSession.forTesting(
        client: MockClient((_) async => _response(_login())),
        tokenStore: store,
        now: () => _now,
      );
      addTearDown(session.disposeForTesting);
      await session.login(
        identifier: 'first',
        password: 'test',
        remember: false,
      );
      var staleCleanups = 0;
      session.onSessionCleared = () async {
        staleCleanups++;
      };
      final clear = session.clear();
      await store.started.future;
      final login = session.login(
        identifier: 'second',
        password: 'test',
        remember: false,
      );
      await Future<void>.delayed(Duration.zero);
      store.finish.complete();
      await Future.wait([clear, login]);
      expect(store.tokens, isNotNull);
      expect(session.currentUser, isNotNull);
      expect(staleCleanups, 0);
    },
  );

  test(
    'active fetch follows all active pages without loading lifetime history',
    () async {
      final pages = <String>[];
      final session = await _session((request) async {
        expect(request.url.queryParameters['scope'], 'active');
        pages.add(request.url.queryParameters['page']!);
        return _response(_page([_row(pages.length)], next: pages.length == 1));
      });
      final orders = await CourierOrdersApi(session: session).loadOrders();
      expect(pages, ['1', '2']);
      expect(orders.map((order) => order.id), ['1', '2']);
      expect(orders.first.items.single.additions, ['Extra']);
    },
  );

  test(
    'history uses one bounded page, timezone date filter and server aggregates',
    () async {
      final session = await _session((request) async {
        expect(request.url.queryParameters, containsPair('scope', 'history'));
        expect(
          request.url.queryParameters,
          containsPair('status', 'delivered'),
        );
        expect(request.url.queryParameters, containsPair('page_size', '30'));
        expect(
          request.url.queryParameters['delivered_from'],
          _now.toIso8601String(),
        );
        return _response(_page([_row(1, status: 'delivered')], next: true));
      });
      final page = await CourierOrdersApi(
        session: session,
      ).loadHistoryPage(from: _now);
      expect(page.orders, hasLength(1));
      expect(page.totals.count, 301);
      expect(page.totals.value, 4500);
      expect(page.hasNext, isTrue);
    },
  );

  test(
    'lost delivery commit response reconciles once without duplicate write',
    () async {
      var writes = 0;
      var reads = 0;
      final session = await _session((request) async {
        if (request.method == 'PATCH') {
          writes++;
          throw http.ClientException('lost response');
        }
        reads++;
        return _response(_row(7, status: 'delivered'));
      });
      final order = await CourierOrdersApi(
        session: session,
      ).markDelivered('7', note: 'kept');
      expect(order.isDelivered, isTrue);
      expect(writes, 1);
      expect(reads, 1);
    },
  );

  test(
    'failure before commit stays typed failure after reconciliation',
    () async {
      final session = await _session((request) async {
        if (request.method == 'PATCH') throw http.ClientException('offline');
        return _response(_row(7, status: 'picked_up'));
      });
      final result = await CourierOrdersRepositoryImpl(
        CourierOrdersApi(session: session),
      ).deliver('7', note: 'draft');
      expect(
        result,
        isA<ApiFailure>().having(
          (failure) => failure.reason,
          'reason',
          ApiFailureReason.network,
        ),
      );
    },
  );

  test('old request cannot replay after account replacement', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    var refreshes = 0;
    final session = await _session((request) async {
      if (request.url.path.endsWith('auth/refresh/')) {
        refreshes++;
        return _response(_login());
      }
      started.complete();
      return pending.future;
    });
    final request = session.getJson('courier/orders/');
    final failure = expectLater(request, throwsA(isA<ApiException>()));
    await started.future;
    await session.clear();
    await session.login(identifier: 'new', password: 'test', remember: false);
    pending.complete(_response({'detail': 'expired'}, 401));
    await failure;
    expect(refreshes, 0);
    expect(session.currentUser, isNotNull);
  });

  test(
    'logout unbinds the device while credentials are active then clears notifications',
    () async {
      final steps = <String>[];
      final session = await _session((request) async {
        steps.add('blacklist');
        return _response({});
      });
      session.beforeLogout = () async {
        expect(session.tokensForTesting, isNotNull);
        steps.add('unbind');
      };
      session.onSessionCleared = () async {
        expect(session.currentUser, isNull);
        steps.add('notifications');
      };
      await session.logout();
      expect(steps, ['unbind', 'blacklist', 'notifications']);
    },
  );

  test(
    'cold push stays queued despite global listener and is filtered after restoration',
    () async {
      final service = CourierPushService.instance;
      service.detachOpenedEventRouter();
      AuthSession.instance.currentUser = null;
      var emitted = 0;
      final subscription = service.events.listen((_) => emitted++);
      await service.handleData({
        'event': 'courier_order_assigned',
        'recipient_id': 1,
        'notification_id': 'cold-1',
      }, opened: true);
      await service.handleData({
        'event': 'courier_order_assigned',
        'recipient_id': 2,
        'notification_id': 'cold-2',
      }, opened: true);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, 0);
      AuthSession.instance.currentUser = {'id': 2, 'role': 'representative'};
      expect(service.takePendingOpenedEvents().single.data['recipient_id'], 2);
      expect(service.takePendingOpenedEvents(), isEmpty);
      AuthSession.instance.currentUser = null;
      await subscription.cancel();
    },
  );

  testWidgets(
    'failed confirmation preserves editable note until successful retry',
    (tester) async {
      var attempts = 0;
      final notes = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showModalBottomSheet<DeliveryConfirmationResult>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => DeliveryConfirmationSheet(
                        orderId: '7',
                        onConfirm: (result) async {
                          notes.add(result.note);
                          if (++attempts == 1) {
                            throw const ApiException('offline');
                          }
                        },
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Delivery draft');
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(find.text('Delivery draft'), findsOneWidget);
      expect(find.byType(DeliveryConfirmationSheet), findsOneWidget);
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(find.byType(DeliveryConfirmationSheet), findsNothing);
      expect(notes, ['Delivery draft', 'Delivery draft']);
    },
  );
}
