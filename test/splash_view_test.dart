import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lottie/lottie.dart';

import 'package:yalla_home/core/routing/app_routes.dart';
import 'package:yalla_home/features/splash/presentation/views/splash_view.dart';

void main() {
  testWidgets(
    'SplashView displays Lottie, Arabic title and translated subtitle',
    (WidgetTester tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.login: (context) =>
                const Scaffold(body: Text('Login Screen')),
            AppRoutes.dashboard: (context) =>
                const Scaffold(body: Text('Dashboard Screen')),
          },
          home: const SplashView(),
        ),
      );

      // Verify Lottie widget is present
      expect(find.byType(Lottie), findsOneWidget);

      // Verify Arabic branding texts
      expect(find.textContaining('يلا'), findsOneWidget);
      expect(find.textContaining('دليفري'), findsOneWidget);
      expect(find.text('استلم، تتبّع وسلّم الطلبات بسهولة'), findsOneWidget);

      // Pump past delay to let session restore navigation finish cleanly
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      expect(find.text('Login Screen'), findsOneWidget);
    },
  );
}
