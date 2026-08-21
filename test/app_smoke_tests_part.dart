part of 'widget_test.dart';

void _registerAppSmokeTests() {
  testWidgets('shows Yalla Delivery login screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const YallaHomeApp());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(find.text('أهلاً يا كابتن'), findsOneWidget);
    expect(find.text('موبايل / إيميل / اسم مستخدم'), findsOneWidget);
    expect(find.text('دخول Demo'), findsNothing);
    expect(find.text('تذكرني'), findsOneWidget);
    expect(find.text('الدعم الفني'), findsOneWidget);

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.elementAt(0).controller?.text, isEmpty);
    expect(fields.elementAt(1).controller?.text, isEmpty);

    final rememberMe = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(rememberMe.value, isTrue);
    await tester.tap(find.text('تذكرني'));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    final supportButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'الدعم الفني'),
    );
    expect(supportButton.onPressed, isNotNull);
  });
}
