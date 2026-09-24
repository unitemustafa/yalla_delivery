import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

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
  late final AnimationController _splashController;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _exitOpacity;
  Timer? _minDelayTimer;
  Completer<void>? _delayCompleter;
  bool _motionPreferenceApplied = false;
  bool _hasTemporaryRestoreFailure = false;
  bool _isRestoring = false;

  static const Duration _animationDuration = Duration(milliseconds: 4200);
  static const Duration _minimumDisplayDuration = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _splashController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    // Text gently fades in around ~1.2s and finishes at ~2.4s
    _textOpacity = CurvedAnimation(
      parent: _splashController,
      curve: const Interval(0.28, 0.58, curve: Curves.easeOut),
    );

    // Text slides up smoothly matching the video motion
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _splashController,
            curve: const Interval(0.28, 0.62, curve: Curves.easeOutCubic),
          ),
        );

    // Contents gently dissolve to pure white near the end (~3.6s - 4.2s)
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeInOut),
      ),
    );

    _splashController.forward();
    _restoreSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionPreferenceApplied) return;
    _motionPreferenceApplied = true;
    if (MediaQuery.of(context).disableAnimations) {
      _splashController.value = 1;
      _minDelayTimer?.cancel();
      if (!(_delayCompleter?.isCompleted ?? true)) {
        _delayCompleter?.complete();
      }
    }
  }

  Future<void> _restoreSession({bool isRetry = false}) async {
    if (mounted) {
      setState(() {
        _hasTemporaryRestoreFailure = false;
        _isRestoring = true;
      });
    }

    final completer = Completer<void>();
    _delayCompleter = completer;
    _minDelayTimer?.cancel();

    final waitDuration = isRetry ? Duration.zero : _minimumDisplayDuration;
    if (waitDuration == Duration.zero) {
      completer.complete();
    } else {
      _minDelayTimer = Timer(waitDuration, () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
    }

    final restoreResult = await AuthSession.instance.restore();
    if (!completer.isCompleted) {
      await completer.future;
    }

    if (!mounted) return;
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
    _minDelayTimer?.cancel();
    if (_delayCompleter != null && !_delayCompleter!.isCompleted) {
      _delayCompleter!.complete();
    }
    _splashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.splashBackground,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                child: FadeTransition(
                  opacity: _hasTemporaryRestoreFailure
                      ? const AlwaysStoppedAnimation(1.0)
                      : _exitOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        height: 300,
                        child: Lottie.asset(
                          AppAssets.deliveryLottie,
                          controller: _splashController,
                          onLoaded: (composition) {
                            _splashController.duration = composition.duration;
                            if (!_splashController.isAnimating &&
                                !_splashController.isCompleted) {
                              _splashController.forward();
                            }
                          },
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeTransition(
                        opacity: _textOpacity,
                        child: SlideTransition(
                          position: _textSlide,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text.rich(
                                const TextSpan(
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    height: 1.2,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'يلا ',
                                      style: TextStyle(
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'دليفري',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'استلم، تتبّع وسلّم الطلبات بسهولة',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_hasTemporaryRestoreFailure) ...[
                        const SizedBox(height: 28),
                        _RestoreFailureActions(
                          isRestoring: _isRestoring,
                          onRetry: _isRestoring
                              ? null
                              : () => _restoreSession(isRetry: true),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
            color: const Color(0xFFDC2626),
            fontWeight: FontWeight.w700,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF111827),
            foregroundColor: Colors.white,
            minimumSize: const Size(140, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isRestoring ? 'جاري المحاولة...' : 'إعادة المحاولة',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
