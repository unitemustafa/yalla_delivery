import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:yalla_home/core/theme/app_theme_controller.dart';
import 'package:yalla_home/core/constants/app_assets.dart';
import 'package:yalla_home/core/presentation/widgets/network_image_or_placeholder.dart';
import 'package:yalla_home/core/presentation/widgets/authenticated_network_image.dart';
import 'package:yalla_home/features/deliveries/data/courier_notifications_api.dart';
import 'package:yalla_home/features/deliveries/data/courier_orders_api.dart';
import 'package:yalla_home/features/deliveries/data/courier_profile_api.dart';
import 'package:yalla_home/features/deliveries/domain/courier_notification.dart';
import 'package:yalla_home/features/deliveries/domain/courier_order.dart';
import 'package:yalla_home/features/deliveries/presentation/extensions/courier_order_status_presentation.dart';
import 'package:yalla_home/features/deliveries/domain/courier_account.dart';
import 'package:yalla_home/features/deliveries/presentation/controllers/courier_notifications_controller.dart';
import 'package:yalla_home/features/deliveries/presentation/controllers/courier_profile_controller.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_notifications_view.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_orders_view.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_profile_view.dart';
import 'package:yalla_home/features/deliveries/presentation/views/delivered_history_view.dart';
import 'package:yalla_home/features/deliveries/presentation/widgets/courier_notifications_button.dart';
import 'package:yalla_home/features/deliveries/presentation/widgets/delivery_confirmation_sheet.dart';
import 'package:yalla_home/features/deliveries/presentation/widgets/order_card.dart';
import 'package:yalla_home/yalla_home_app.dart';

part 'app_smoke_tests_part.dart';
part 'delivery_tests_part.dart';
part 'notification_tests_part.dart';
part 'profile_tests_part.dart';
part 'widget_test_helpers_part.dart';

void main() {
  _registerAppSmokeTests();
  _registerDeliveryTests();
  _registerNotificationTests();
  _registerProfileTests();
}

String _readSources(List<String> paths) {
  return paths.map((path) => File(path).readAsStringSync()).join('\n');
}
