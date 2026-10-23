import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/presentation/widgets/layouts/android_tablet_viewport.dart';

void main() {
  testWidgets('centers a 3:4 viewport on a landscape iPad', (tester) async {
    final observed = await _pumpViewport(
      tester,
      size: const Size(1024, 768),
      platform: TargetPlatform.iOS,
      padding: const FakeViewPadding(top: 24, bottom: 20),
      viewInsets: const FakeViewPadding(bottom: 300),
    );

    expect(
      tester.getRect(find.byKey(const ValueKey('android_tablet_viewport'))),
      const Rect.fromLTWH(224, 0, 576, 768),
    );
    expect(observed.size, const Size(576, 768));
    expect(observed.orientation, Orientation.portrait);
    expect(observed.padding, const EdgeInsets.only(top: 24, bottom: 20));
    expect(observed.viewInsets.bottom, 300);
  });

  testWidgets('keeps a portrait iPad full screen', (tester) async {
    final observed = await _pumpViewport(
      tester,
      size: const Size(768, 1024),
      platform: TargetPlatform.iOS,
    );

    expect(
      find.byKey(const ValueKey('android_tablet_letterbox')),
      findsNothing,
    );
    expect(observed.size, const Size(768, 1024));
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('keeps iPhone $size full screen', (tester) async {
      final observed = await _pumpViewport(
        tester,
        size: size,
        platform: TargetPlatform.iOS,
      );

      expect(
        find.byKey(const ValueKey('android_tablet_letterbox')),
        findsNothing,
      );
      expect(observed.size, size);
    });
  }

  testWidgets('keeps a portrait phone full screen', (tester) async {
    final observed = await _pumpViewport(tester, size: const Size(412, 915));

    expect(
      find.byKey(const ValueKey('android_tablet_letterbox')),
      findsNothing,
    );
    expect(observed.size, const Size(412, 915));
    expect(
      tester.getSize(find.byKey(const ValueKey('viewport_probe'))),
      const Size(412, 915),
    );
  });

  testWidgets('keeps a portrait tablet full screen', (tester) async {
    final observed = await _pumpViewport(tester, size: const Size(800, 1280));

    expect(
      find.byKey(const ValueKey('android_tablet_letterbox')),
      findsNothing,
    );
    expect(observed.size, const Size(800, 1280));
    expect(
      tester.getSize(find.byKey(const ValueKey('viewport_probe'))),
      const Size(800, 1280),
    );
  });

  testWidgets('keeps a landscape phone full screen', (tester) async {
    final observed = await _pumpViewport(tester, size: const Size(915, 412));

    expect(
      find.byKey(const ValueKey('android_tablet_letterbox')),
      findsNothing,
    );
    expect(observed.size, const Size(915, 412));
  });

  testWidgets('centers a 3:4 viewport on an Android landscape tablet', (
    tester,
  ) async {
    final observed = await _pumpViewport(
      tester,
      size: const Size(1280, 800),
      padding: const FakeViewPadding(top: 24, bottom: 16),
      viewInsets: const FakeViewPadding(bottom: 280),
    );

    expect(
      find.byKey(const ValueKey('android_tablet_letterbox')),
      findsOneWidget,
    );
    final viewportRect = tester.getRect(
      find.byKey(const ValueKey('android_tablet_viewport')),
    );
    expect(viewportRect, const Rect.fromLTWH(340, 0, 600, 800));
    expect(observed.size, const Size(600, 800));
    expect(observed.padding, const EdgeInsets.only(top: 24, bottom: 16));
    expect(observed.viewInsets.bottom, 280);
  });

  testWidgets('does not letterbox a desktop landscape window', (tester) async {
    final observed = await _pumpViewport(
      tester,
      size: const Size(1280, 800),
      platform: TargetPlatform.windows,
    );

    expect(
      find.byKey(const ValueKey('android_tablet_letterbox')),
      findsNothing,
    );
    expect(observed.size, const Size(1280, 800));
  });

  testWidgets('translates side insets into the centered viewport', (
    tester,
  ) async {
    final observed = await _pumpViewport(
      tester,
      size: const Size(1280, 800),
      padding: const FakeViewPadding(left: 360, top: 24, right: 16),
      viewPadding: const FakeViewPadding(left: 360, top: 24, right: 16),
      viewInsets: const FakeViewPadding(left: 380, bottom: 280),
      systemGestureInsets: const FakeViewPadding(left: 360, right: 16),
    );

    expect(observed.padding, const EdgeInsets.only(left: 20, top: 24));
    expect(observed.viewPadding, const EdgeInsets.only(left: 20, top: 24));
    expect(observed.viewInsets, const EdgeInsets.only(left: 40, bottom: 280));
    expect(observed.systemGestureInsets, const EdgeInsets.only(left: 20));
  });
}

Future<MediaQueryData> _pumpViewport(
  WidgetTester tester, {
  required Size size,
  TargetPlatform platform = TargetPlatform.android,
  FakeViewPadding padding = FakeViewPadding.zero,
  FakeViewPadding viewPadding = FakeViewPadding.zero,
  FakeViewPadding viewInsets = FakeViewPadding.zero,
  FakeViewPadding systemGestureInsets = FakeViewPadding.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  tester.view.viewPadding = viewPadding;
  tester.view.viewInsets = viewInsets;
  tester.view.systemGestureInsets = systemGestureInsets;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(tester.view.resetSystemGestureInsets);

  MediaQueryData? observed;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => AndroidTabletViewport(
        platformOverride: platform,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Builder(
        builder: (context) {
          observed = MediaQuery.of(context);
          return const SizedBox.expand(
            key: ValueKey('viewport_probe'),
            child: ColoredBox(color: Colors.white),
          );
        },
      ),
    ),
  );

  return observed!;
}
