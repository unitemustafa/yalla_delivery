import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared Android tablet and iPad presentation policy.
///
/// The Android name is retained for existing callers.
abstract final class AndroidTabletDisplayPolicy {
  static const double tabletBreakpoint = 600;
  static const double portraitWidthToHeightRatio = 3 / 4;
  static const Color letterboxColor = Colors.black;

  static bool needsPortraitViewport({
    required Size windowSize,
    required TargetPlatform platform,
  }) {
    return (platform == TargetPlatform.android ||
            platform == TargetPlatform.iOS) &&
        windowSize.shortestSide >= tabletBreakpoint &&
        windowSize.width > windowSize.height;
  }

  static Size portraitViewportSize(Size windowSize) {
    return Size(
      math.min(
        windowSize.width,
        windowSize.height * portraitWidthToHeightRatio,
      ),
      windowSize.height,
    );
  }
}

/// Centers portrait content on landscape Android tablets and iPads.
///
/// Also reproduces Android's portrait letterbox if a large-screen policy
/// ignores the native orientation request.
///
/// The [MediaQuery] override is intentional: route contents, overlays, sheets,
/// and dialogs must lay themselves out against the centered viewport rather
/// than the full landscape window.
class AndroidTabletViewport extends StatelessWidget {
  const AndroidTabletViewport({
    super.key,
    required this.child,
    this.platformOverride,
  });

  final Widget child;

  @visibleForTesting
  final TargetPlatform? platformOverride;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final windowSize = mediaQuery.size;
    final platform = platformOverride ?? defaultTargetPlatform;
    if (!AndroidTabletDisplayPolicy.needsPortraitViewport(
      windowSize: windowSize,
      platform: platform,
    )) {
      return child;
    }

    final viewportSize = AndroidTabletDisplayPolicy.portraitViewportSize(
      windowSize,
    );
    final horizontalGutter = (windowSize.width - viewportSize.width) / 2;
    final viewportMediaQuery = mediaQuery.copyWith(
      size: viewportSize,
      padding: _translateInsets(mediaQuery.padding, horizontalGutter),
      viewPadding: _translateInsets(mediaQuery.viewPadding, horizontalGutter),
      viewInsets: _translateInsets(mediaQuery.viewInsets, horizontalGutter),
      systemGestureInsets: _translateInsets(
        mediaQuery.systemGestureInsets,
        horizontalGutter,
      ),
    );

    return ColoredBox(
      key: const ValueKey('android_tablet_letterbox'),
      color: AndroidTabletDisplayPolicy.letterboxColor,
      child: Center(
        child: ClipRect(
          child: SizedBox.fromSize(
            key: const ValueKey('android_tablet_viewport'),
            size: viewportSize,
            child: MediaQuery(data: viewportMediaQuery, child: child),
          ),
        ),
      ),
    );
  }
}

EdgeInsets _translateInsets(EdgeInsets insets, double horizontalGutter) {
  return EdgeInsets.fromLTRB(
    math.max(0, insets.left - horizontalGutter),
    insets.top,
    math.max(0, insets.right - horizontalGutter),
    insets.bottom,
  );
}
