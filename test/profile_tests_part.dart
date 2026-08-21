part of 'widget_test.dart';

void _registerProfileTests() {
  test('parses real auth/me courier profile response', () {
    final account = CourierProfileApi.parseUserResponse(
      _courierAccountJson(isAvailable: true),
    );

    expect(account.role, 'representative');
    expect(account.displayName, 'مصطفى علي');
    expect(account.secondaryLabel, '@captain_mostafa');
    expect(account.avatarUrl, '/media/avatars/courier.png');
    expect(account.profile?.serviceCityName, 'الجيزة');
    expect(account.profile?.vehicleType, 'دراجة نارية');
    expect(account.profile?.plateNumber, 'ج ي ز 1234');
    expect(account.profile?.maxActiveOrders, 4);
    expect(account.profile?.isAvailable, isTrue);
  });

  testWidgets('profile shows loaded account fields and avatar url', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: CourierProfileView(
          controller: _profileControllerWith([
            _courierAccount(isAvailable: true),
          ]),
          activeOrders: 3,
          deliveredOrders: 1,
          onActiveOrdersTap: () {},
          onDeliveredSummaryTap: () {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('مصطفى علي'), findsOneWidget);
    expect(find.text('@captain_mostafa'), findsOneWidget);
    expect(find.text('مدينة الخدمة'), findsOneWidget);
    expect(find.text('الجيزة'), findsOneWidget);
    expect(find.text('متاح لاستقبال الطلبات'), findsOneWidget);
    expect(find.text('نوع المركبة'), findsOneWidget);
    expect(find.text('دراجة نارية'), findsOneWidget);
    expect(find.text('رقم اللوحة'), findsOneWidget);
    expect(find.text('ج ي ز 1234'), findsOneWidget);
    expect(find.text('الحد الأقصى للطلبات النشطة'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets(
    'profile shows unavailable state without tying it to connection',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: CourierProfileView(
            controller: _profileControllerWith([
              _courierAccount(isAvailable: false),
            ]),
            activeOrders: 0,
            deliveredOrders: 0,
            onActiveOrdersTap: () {},
            onDeliveredSummaryTap: () {},
            onLogout: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('غير متاح حاليًا'), findsOneWidget);
      expect(find.textContaining('حالة الاتصال:'), findsNothing);
      expect(find.text('Online'), findsNothing);
      expect(find.text('Offline'), findsNothing);
    },
  );

  testWidgets(
    'profile does not assume available when is_available is missing',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: CourierProfileView(
            controller: _profileControllerWith([
              _courierAccount(isAvailable: null),
            ]),
            activeOrders: 0,
            deliveredOrders: 0,
            onActiveOrdersTap: () {},
            onDeliveredSummaryTap: () {},
            onLogout: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('الحالة غير معروفة'), findsOneWidget);
      expect(find.text('متاح لاستقبال الطلبات'), findsNothing);
    },
  );

  testWidgets('profile uses safe fallbacks for missing courier fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: CourierProfileView(
          controller: _profileControllerWith([
            CourierAccount.fromJson({
              ..._courierAccountJson(),
              'avatar_url': null,
              'courier_profile': null,
            }),
          ]),
          activeOrders: 0,
          deliveredOrders: 0,
          onActiveOrdersTap: () {},
          onDeliveredSummaryTap: () {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('courier_profile_avatar_fallback')),
      findsOneWidget,
    );
    expect(find.text('بيانات تشغيل المندوب غير مكتملة.'), findsOneWidget);
    expect(find.text('مدينة الخدمة غير محددة'), findsOneWidget);
    expect(find.text('الحالة غير معروفة'), findsOneWidget);
    expect(find.text('غير محدد'), findsWidgets);
  });

  test('profile page has no fixed Cairo city or delivery area name flow', () {
    final profileSource = _readSources([
      'lib/features/deliveries/presentation/views/courier_profile_view.dart',
      'lib/features/deliveries/presentation/views/courier_profile_content_part.dart',
      'lib/features/deliveries/presentation/views/courier_profile_settings_part.dart',
    ]);
    final modelSource = File(
      'lib/features/deliveries/domain/courier_account.dart',
    ).readAsStringSync();

    expect(profileSource, contains('AuthSession.instance.absoluteUrl'));
    expect(profileSource, contains('NetworkImageOrPlaceholder'));
    expect(profileSource, isNot(contains('القاهرة')));
    expect(profileSource, isNot(contains('delivery_area_name')));
    expect(modelSource, isNot(contains('delivery_area_name')));
  });

  testWidgets('profile shows loading, error, and retry', (
    WidgetTester tester,
  ) async {
    final failedLoad = Completer<CourierAccount>();
    final api = _FakeProfileApi()..loadCompleter = failedLoad;
    final controller = CourierProfileController(api: api);

    await tester.pumpWidget(
      _TestApp(
        child: CourierProfileView(
          controller: controller,
          activeOrders: 0,
          deliveredOrders: 0,
          onActiveOrdersTap: () {},
          onDeliveredSummaryTap: () {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('courier_profile_loading')), findsOneWidget);
    failedLoad.completeError(Exception('انقطع الاتصال'));
    await tester.pump();

    expect(find.byKey(const Key('courier_profile_error')), findsOneWidget);
    expect(find.text('تعذر تحميل بيانات حساب المندوب'), findsOneWidget);

    api.accounts = [_courierAccount(serviceCityName: 'الإسكندرية')];
    await tester.tap(find.byKey(const Key('courier_profile_retry')));
    await tester.pump();
    await tester.pump();

    expect(api.loadCalls, 2);
    expect(find.text('الإسكندرية'), findsOneWidget);
  });

  testWidgets('profile pull to refresh reloads auth me data', (
    WidgetTester tester,
  ) async {
    final api = _FakeProfileApi(
      accounts: [
        _courierAccount(serviceCityName: 'الجيزة'),
        _courierAccount(serviceCityName: 'الإسكندرية'),
      ],
    );

    await tester.pumpWidget(
      _TestApp(
        child: CourierProfileView(
          controller: CourierProfileController(api: api),
          activeOrders: 0,
          deliveredOrders: 0,
          onActiveOrdersTap: () {},
          onDeliveredSummaryTap: () {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('الجيزة'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(api.loadCalls, 2);
    expect(find.text('الإسكندرية'), findsOneWidget);
  });

  testWidgets('profile stats navigate, theme changes, and logout confirms', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppThemeController.instance.setThemeMode(ThemeMode.system);
    var activeTapped = false;
    var deliveredTapped = false;
    var loggedOut = false;

    await tester.pumpWidget(
      _TestApp(
        child: CourierProfileView(
          controller: _profileControllerWith([_courierAccount()]),
          activeOrders: 3,
          deliveredOrders: 1,
          onActiveOrdersTap: () => activeTapped = true,
          onDeliveredSummaryTap: () => deliveredTapped = true,
          onLogout: () => loggedOut = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('طلبات نشطة'));
    expect(activeTapped, isTrue);

    await tester.tap(find.text('طلبات مسلّمة'));
    expect(deliveredTapped, isTrue);

    await tester.tap(find.text('ثيم التطبيق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('داكن').last);
    await tester.pump();
    expect(AppThemeController.instance.value, ThemeMode.dark);

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.text('متأكد إنك عايز تسجل خروج؟'), findsOneWidget);
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);

    AppThemeController.instance.setThemeMode(ThemeMode.system);
  });
}
