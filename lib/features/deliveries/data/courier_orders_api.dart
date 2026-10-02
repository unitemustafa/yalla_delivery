import '../../../core/auth/auth_session.dart';
import '../domain/courier_order.dart';
import '../domain/courier_order_page.dart';
import '../../../core/network/api_exception.dart';

class CourierOrdersApi {
  const CourierOrdersApi({AuthSession? session}) : _session = session;
  final AuthSession? _session;
  AuthSession get session => _session ?? AuthSession.instance;
  CourierOrder _order(Map<String, dynamic> data) =>
      CourierOrder.fromJson(data, resolveUrl: session.absoluteUrl);

  Future<List<CourierOrder>> loadOrders() async {
    final orders = <CourierOrder>[];
    var page = 1;
    while (true) {
      final result = await _loadPage('scope=active&page=$page&page_size=100');
      orders.addAll(result.orders);
      if (!result.hasNext) return orders;
      page++;
    }
  }

  Future<CourierOrderPage> loadHistoryPage({
    int page = 1,
    DateTime? from,
    DateTime? before,
  }) {
    final query = Uri(
      queryParameters: {
        'scope': 'history',
        'status': 'delivered',
        'page': '$page',
        'page_size': '30',
        if (from != null) 'delivered_from': from.toUtc().toIso8601String(),
        if (before != null)
          'delivered_before': before.toUtc().toIso8601String(),
      },
    ).query;
    return _loadPage(query);
  }

  Future<CourierOrderPage> _loadPage(String query) async {
    final data = await session.getJson('courier/orders/?$query');
    if (data is! Map<String, dynamic> ||
        data['results'] is! List ||
        data['summary'] is! Map) {
      throw const FormatException('Missing paginated order response.');
    }
    final summary = data['summary'] as Map;
    return CourierOrderPage(
      orders: (data['results'] as List)
          .map((row) => _order(Map<String, dynamic>.from(row as Map)))
          .toList(),
      hasNext: data['next'] != null,
      totals: CourierOrderTotals(
        count: int.parse(summary['count'].toString()),
        value: double.parse(summary['total_value'].toString()),
        deliveryFees: double.parse(summary['total_delivery_fees'].toString()),
      ),
    );
  }

  Future<CourierOrder> loadOrder(String orderId) async {
    final data = await session.getJson('courier/orders/$orderId/');
    return _order(data as Map<String, dynamic>);
  }

  Future<CourierOrder> markPickedUp(String orderId) async {
    final data = await session.patchJson('courier/orders/$orderId/status/', {
      'status': 'picked_up',
    });
    return _order(data as Map<String, dynamic>);
  }

  Future<CourierOrder> markMarketPickedUp(String orderId, int sectionId) async {
    final data = await session.patchJson(
      'courier/orders/$orderId/markets/$sectionId/pickup/',
      const <String, String>{},
    );
    return _order(data as Map<String, dynamic>);
  }

  Future<CourierOrder> markDelivered(
    String orderId, {
    String? note,
    List<int>? proofBytes,
    String? proofName,
  }) async {
    final deliveryNote = note?.trim();
    final fields = <String, String>{
      'status': 'delivered',
      if (deliveryNote != null && deliveryNote.isNotEmpty)
        'delivery_note': deliveryNote,
    };
    try {
      final data = proofBytes == null || proofName == null
          ? await session.patchJson('courier/orders/$orderId/status/', fields)
          : await session.patchMultipart(
              'courier/orders/$orderId/status/',
              fields: fields,
              proofBytes: proofBytes,
              proofName: proofName,
            );
      return _order(data as Map<String, dynamic>);
    } on ApiException catch (error) {
      // An interrupted response can follow a successful commit. Read once;
      // retrying the same upload would otherwise report a false failure.
      if (error.code != 'session_changed' &&
          (error.statusCode == null || (error.statusCode ?? 0) >= 500)) {
        try {
          final current = await loadOrder(orderId);
          if (current.isDelivered) return current;
        } catch (_) {
          /* Preserve the original failure and the editable draft. */
        }
      }
      rethrow;
    }
  }
}
