import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/courier_push_service.dart';
import '../../../../core/routing/app_routes.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _taglineOpacity;
  bool _motionPreferenceApplied = false;
  bool _hasTemporaryRestoreFailure = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.55, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.72, curve: Curves.easeOutBack),
      ),
    );
    _taglineOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.42, 1, curve: Curves.easeOut),
    );
    _taglineSlide =
        Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.42, 1, curve: Curves.easeOutCubic),
          ),
        );
    _entranceController.forward();
    _restoreSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionPreferenceApplied) return;
    _motionPreferenceApplied = true;
    if (MediaQuery.of(context).disableAnimations) {
      _entranceController.value = 1;
    }
  }

  Future<void> _restoreSession() async {
    if (mounted) {
      setState(() {
        _hasTemporaryRestoreFailure = false;
        _isRestoring = true;
      });
    }
    final results = await Future.wait<dynamic>([
      Future<void>.delayed(const Duration(milliseconds: 1500)),
      AuthSession.instance.restore(),
    ]);
    if (!mounted) return;
    final restoreResult = results[1] as AuthRestoreResult;
    setState(() {
      _isRestoring = false;
    });
    if (restoreResult == AuthRestoreResult.restored) {
      await CourierPushService.instance.registerAuthenticatedDevice();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      return;
    }
    if (restoreResult == AuthRestoreResult.noSession ||
        restoreResult == AuthRestoreResult.expired) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }
    setState(() {
      _hasTemporaryRestoreFailure = true;
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        AppAssets.appIconLogo,
                        width: 248,
                        height: 248,
                        fit: BoxFit.contain,
                        cacheWidth: 496,
                        cacheHeight: 496,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: SlideTransition(
                    position: _taglineSlide,
                    child: Text(
                      'نوصلها لك أسرع',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                if (_hasTemporaryRestoreFailure) ...[
                  const SizedBox(height: 28),
                  _RestoreFailureActions(
                    isRestoring: _isRestoring,
                    onRetry: _isRestoring ? null : _restoreSession,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestoreFailureActions extends StatelessWidget {
  const _RestoreFailureActions({
    required this.isRestoring,
    required this.onRetry,
  });

  final bool isRestoring;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'تعذر الاتصال. حاول مرة أخرى.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.splashBackground,
            minimumSize: const Size(128, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(isRestoring ? 'جاري المحاولة' : 'إعادة المحاولة'),
        ),
      ],
    );
  }
}
