import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/domain/api_result.dart';
import 'package:yalla_home/core/routing/app_navigator.dart';
import 'package:yalla_home/features/app_updates/domain/app_release.dart';
import 'package:yalla_home/features/app_updates/domain/app_update_repository.dart';
import 'package:yalla_home/features/app_updates/domain/app_update_use_cases.dart';
import 'package:yalla_home/features/app_updates/presentation/app_update_cubit.dart';
import 'package:yalla_home/features/app_updates/presentation/app_update_host.dart';

final _release = AppRelease(
  versionCode: 4016,
  versionName: '1.0.12',
  downloadUrl: Uri.parse('https://api.example.com/yalla.apk'),
  sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  fileSize: 1234,
  releaseNotes: 'إصلاحات مهمة.',
);

class _Repository implements AppUpdateRepository {
  _Repository({this.release});
  final AppRelease? release;
  int checks = 0;
  int downloads = 0;
  int installs = 0;

  @override
  Future<ApiResult<AppRelease?>> check() async {
    checks++;
    return ApiSuccess(release ?? _release);
  }

  @override
  Future<ApiResult<UpdateDownload>> download(AppRelease release) async {
    downloads++;
    return ApiSuccess(
      UpdateDownload(
        phase: UpdateDownloadPhase.ready,
        versionCode: release.versionCode,
        versionName: release.versionName,
      ),
    );
  }

  @override
  Future<ApiResult<void>> install() async {
    installs++;
    return const ApiSuccess(null);
  }

  @override
  Future<ApiResult<UpdateDownload>> status() async =>
      const ApiSuccess(UpdateDownload(phase: UpdateDownloadPhase.idle));
}

AppUpdateCubit _cubitFor(_Repository repository) => AppUpdateCubit(
  CheckForAppUpdate(repository),
  DownloadAppUpdate(repository),
  ReadAppUpdateDownload(repository),
  InstallAppUpdate(repository),
);

Widget _app(AppUpdateCubit cubit, {ValueListenable<bool>? ready}) =>
    MaterialApp(
      navigatorKey: AppNavigator.key,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: AppUpdateHost(
          cubit: cubit,
          ready: ready,
          child: const Scaffold(body: Center(child: Text('الطلبات'))),
        ),
      ),
    );

void main() {
  testWidgets('waits for splash replacement before checking for an update', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    final observer = AppUpdateNavigationObserver(ready, splashRoute: '/splash');
    final splash = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/splash'),
      builder: (_) => const SizedBox(),
    );
    final login = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/login'),
      builder: (_) => const SizedBox(),
    );
    observer.didPush(splash, null);
    expect(ready.value, isFalse);
    observer.didReplace(newRoute: login, oldRoute: splash);
    expect(ready.value, isTrue);

    ready.value = false;
    final repository = _Repository();
    final cubit = _cubitFor(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit, ready: ready));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    ready.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(repository.checks, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();
  });

  testWidgets('automatic update dialog offers download now and later', (
    tester,
  ) async {
    final repository = _Repository();
    final cubit = _cubitFor(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    expect(find.text('تحميل الآن'), findsNWidgets(2));
    expect(find.text('لاحقًا'), findsOneWidget);
    expect(repository.downloads, 0);
    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();
  });

  testWidgets('later dismisses dialog while compact update banner remains', (
    tester,
  ) async {
    final repository = _Repository();
    final cubit = _cubitFor(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();

    expect(find.text('لاحقًا'), findsNothing);
    expect(find.text('تحميل الآن'), findsOneWidget);
    expect(repository.downloads, 0);
  });

  testWidgets(
    'download reaches ready state and install needs an explicit tap',
    (tester) async {
      final repository = _Repository();
      final cubit = _cubitFor(repository);
      addTearDown(cubit.close);

      await tester.pumpWidget(_app(cubit));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'تحميل الآن'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.downloads, 1);
      expect(repository.installs, 0);
      expect(find.text('تثبيت الآن'), findsNWidgets(2));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'تثبيت الآن'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.installs, 1);
      await tester.tap(find.text('متابعة استخدام التطبيق'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('long notes fit in a narrow update dialog without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longNotesRelease = AppRelease(
      versionCode: _release.versionCode,
      versionName: _release.versionName,
      downloadUrl: _release.downloadUrl,
      sha256: _release.sha256,
      fileSize: _release.fileSize,
      releaseNotes: List.filled(20, 'تفاصيل التحديث المهمة للمندوب').join('\n'),
    );
    final cubit = _cubitFor(_Repository(release: longNotesRelease));
    addTearDown(cubit.close);

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -250),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('تحميل الآن'), findsNWidgets(2));
    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();
  });
}
