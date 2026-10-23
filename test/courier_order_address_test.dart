import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/features/deliveries/domain/courier_order.dart';

void main() {
  test(
    'office delivery retains company and structured destination details',
    () {
      final order = CourierOrder.fromJson({
        'id': 1,
        'status': 'assigned',
        'created_at': '2026-10-23T10:00:00Z',
        'customer': {'phone': '01000000000'},
        'delivery_address': {
          'formatted_address': 'Map street, Cairo',
          'street': 'Customer street',
          'company_name': 'Office destination',
          'building_name': 'Building 7',
          'floor': '4',
          'apartment_number': '12',
          'recipient_phone': '01111111111',
          'additional_instructions': 'Call at gate',
          'latitude': 30.0444,
          'longitude': 31.2357,
        },
      });

      for (final detail in [
        'Map street, Cairo',
        'Customer street',
        'Office destination',
        'Building 7',
        '4',
        '12',
      ]) {
        expect(order.address, contains(detail));
      }
      expect(order.mapQuery, contains('Office destination'));
      expect(order.phone, '01111111111');
      expect(order.addressInstructions, 'Call at gate');
      expect(order.customerLocation?.latitude, 30.0444);
      expect(order.customerLocation?.longitude, 31.2357);
    },
  );

  test('legacy destination works without a company', () {
    final order = CourierOrder.fromJson({
      'id': 2,
      'delivery_address': {'details': 'Legacy street'},
    });
    expect(order.address, 'Legacy street');
  });
}
