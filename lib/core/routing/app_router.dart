import 'package:flutter/material.dart';

import '../../features/auth/presentation/views/login_view.dart';
import '../../features/deliveries/presentation/views/courier_shell_view.dart';
import '../../features/splash/presentation/views/splash_view.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final page = switch (settings.name) {
      AppRoutes.splash => const SplashView(),
      AppRoutes.login => const LoginView(),
      AppRoutes.dashboard => const CourierShellView(),
      _ => const LoginView(),
    };

    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
    );
  }
}
