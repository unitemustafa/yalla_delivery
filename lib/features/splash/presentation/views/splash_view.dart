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
                    child: const _CompactSplashLogo(),
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

class _CompactSplashLogo extends StatelessWidget {
  const _CompactSplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          AppAssets.appIconLogo,
          fit: BoxFit.cover,
          cacheWidth: 192,
          cacheHeight: 192,
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
