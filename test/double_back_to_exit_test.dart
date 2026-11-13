import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/routing/double_back_to_exit.dart';
import 'package:yalla_home/core/texts/app_texts.dart';

void main() {
  late List<MethodCall> platformCalls;
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    platformCalls = [];
    navigatorKey = GlobalKey<NavigatorState>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Iterable<MethodCall> exitCalls() =>
      platformCalls.where((call) => call.method == 'SystemNavigator.pop');

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const DoubleBackToExit(child: Scaffold(body: Text('Home'))),
    ),
  );

  testWidgets(
    'first back prompts and second back exits',
    (tester) async {
      await pumpApp(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text(CommonTexts.pressBackAgainToExit), findsOneWidget);
      expect(exitCalls(), isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exitCalls(), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'back after the confirmation window prompts again',
    (tester) async {
      await pumpApp(tester);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 3));

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exitCalls(), isEmpty);
      expect(find.text(CommonTexts.pressBackAgainToExit), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'pushed pages pop normally and reset exit confirmation',
    (tester) async {
      await pumpApp(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) =>
              const DoubleBackToExit(child: Scaffold(body: Text('Details'))),
        ),
      );
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Details'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(exitCalls(), isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exitCalls(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'back dismisses a dialog without exiting',
    (tester) async {
      await pumpApp(tester);
      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Dialog')),
      );
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Dialog'), findsNothing);
      expect(find.text(CommonTexts.pressBackAgainToExit), findsNothing);
      expect(exitCalls(), isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'backgrounding resets exit confirmation',
    (tester) async {
      await pumpApp(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exitCalls(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS keeps its existing back behavior',
    (tester) async {
      await pumpApp(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text(CommonTexts.pressBackAgainToExit), findsNothing);
      expect(exitCalls(), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
