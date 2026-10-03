import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/features/auth/presentation/views/login_view.dart';
import 'package:yalla_home/features/splash/presentation/views/splash_view.dart';
import 'package:yalla_home/yalla_home_app.dart';

void main() {
  for (final nativeRoute in ['courier_order_details', 'courier_orders']) {
    testWidgets('restores the session before native route $nativeRoute', (
      tester,
    ) async {
      tester.platformDispatcher.defaultRouteNameTestValue = nativeRoute;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(const YallaHomeApp());
      expect(find.byType(SplashView), findsOneWidget);
      expect(find.byType(LoginView), findsNothing);

      // A genuinely absent saved session still goes through the splash restore
      // before reaching login; a native notification route cannot bypass it.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(LoginView), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
