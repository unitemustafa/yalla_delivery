import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/features/deliveries/domain/courier_account.dart';

void main() {
  test('null order capacity is displayed as unlimited', () {
    final profile = CourierProfile.fromJson({'max_active_orders': null});

    expect(profile.maxActiveOrders, isNull);
    expect(profile.maxActiveOrdersLabel, 'غير محدود');
  });

  test('configured order capacity remains visible', () {
    final profile = CourierProfile.fromJson({'max_active_orders': 4});

    expect(profile.maxActiveOrdersLabel, '4');
  });

  test('shipping company response retains its fixed operating details', () {
    final account = CourierAccount.fromJson({
      'role': 'representative',
      'courier_profile': {
        'is_shipping_company': true,
        'service_city': null,
        'service_city_name': null,
        'max_active_orders': null,
        'vehicle_type': 'شركة شحن',
        'plate_number': 'شركة شحن',
      },
    });

    expect(account.profile?.isShippingCompany, isTrue);
    expect(account.profile?.serviceCityLabel, 'كل المدن');
    expect(account.profile?.maxActiveOrdersLabel, 'غير محدود');
    expect(account.profile?.vehicleTypeLabel, 'شركة شحن');
    expect(account.profile?.plateNumberLabel, 'شركة شحن');
  });

  test('regular courier retains the assigned service city', () {
    final profile = CourierProfile.fromJson({'service_city_name': 'القاهرة'});

    expect(profile.isShippingCompany, isFalse);
    expect(profile.serviceCityLabel, 'القاهرة');
  });
}
