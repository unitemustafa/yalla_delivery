import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/app_update_factory.dart';
import '../../../core/routing/app_navigator.dart';
import 'app_update_cubit.dart';
import 'app_update_panel.dart';

class AppUpdateHost extends StatefulWidget {
  const AppUpdateHost({super.key, required this.child, this.cubit, this.ready});
  final Widget child;
  final AppUpdateCubit? cubit;
  final ValueListenable<bool>? ready;

  @override
  State<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends State<AppUpdateHost>
    with WidgetsBindingObserver {
  late final AppUpdateCubit _cubit;
  final _promptedVersions = <int>{};
  bool _dialogOpen = false;
  AppUpdateState? _hiddenState;

  @override
  void initState() {
    super.initState();
    _cubit = widget.cubit ?? createAppUpdateCubit();
    WidgetsBinding.instance.addObserver(this);
    widget.ready?.addListener(_onReady);
    _onReady();
  }

  void _onReady() {
    if (widget.ready?.value == false) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_cubit.check());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.ready?.value != false) {
      unawaited(_cubit.check());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.ready?.removeListener(_onReady);
    if (widget.cubit == null) unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _prompt(AppUpdateState state) async {
    if (state is! AppUpdateAvailable ||
        _dialogOpen ||
        !_promptedVersions.add(state.release.versionCode)) {
      return;
    }
    final navigator = AppNavigator.key.currentState;
    if (navigator == null) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: navigator.context,
        builder: (context) =>
            BlocProvider.value(value: _cubit, child: const AppUpdateDialog()),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocListener<AppUpdateCubit, AppUpdateState>(
      listener: (_, state) => unawaited(_prompt(state)),
      child: Column(
        children: [
          Expanded(child: widget.child),
          BlocBuilder<AppUpdateCubit, AppUpdateState>(
            builder: (context, state) {
              if (state is AppUpdateIdle || identical(state, _hiddenState)) {
                return const SizedBox.shrink();
              }
              return Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: AppUpdatePanel(
                      state: state,
                      compact: true,
                      onDismiss:
                          state is AppUpdateCurrent || state is AppUpdateError
                          ? () => setState(() => _hiddenState = state)
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Wait for session restoration to replace the splash route. A dialog pushed
/// sooner could itself be replaced by splash navigation and corrupt the stack.
class AppUpdateNavigationObserver extends NavigatorObserver {
  AppUpdateNavigationObserver(this.ready, {required this.splashRoute});
  final ValueNotifier<bool> ready;
  final String splashRoute;

  void _observe(Route<dynamic>? route) {
    if (route?.settings.name != null && route!.settings.name != splashRoute) {
      ready.value = true;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _observe(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _observe(newRoute);
}
