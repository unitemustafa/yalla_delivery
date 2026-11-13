import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/domain/api_result.dart';
import 'package:yalla_home/features/app_updates/domain/app_release.dart';
import 'package:yalla_home/features/app_updates/domain/app_update_repository.dart';
import 'package:yalla_home/features/app_updates/domain/app_update_use_cases.dart';
import 'package:yalla_home/features/app_updates/presentation/app_update_cubit.dart';

final _release = AppRelease(
  versionCode: 4016,
  versionName: '1.0.12',
  downloadUrl: Uri.parse('https://api.example.com/yalla.apk'),
  sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  fileSize: 1234,
);

class _Repository implements AppUpdateRepository {
  ApiResult<AppRelease?> checkResult = ApiSuccess(_release);
  ApiResult<UpdateDownload> statusResult = const ApiSuccess(
    UpdateDownload(phase: UpdateDownloadPhase.idle),
  );
  ApiResult<UpdateDownload> downloadResult = const ApiSuccess(
    UpdateDownload(phase: UpdateDownloadPhase.ready, versionCode: 4016),
  );
  ApiResult<void> installResult = const ApiSuccess(null);
  int checks = 0;
  int reads = 0;
  int downloads = 0;
  int installs = 0;
  Completer<ApiResult<AppRelease?>>? pendingCheck;

  @override
  Future<ApiResult<AppRelease?>> check() {
    checks++;
    return pendingCheck?.future ?? Future.value(checkResult);
  }

  @override
  Future<ApiResult<UpdateDownload>> download(AppRelease release) async {
    downloads++;
    return downloadResult;
  }

  @override
  Future<ApiResult<void>> install() async {
    installs++;
    return installResult;
  }

  @override
  Future<ApiResult<UpdateDownload>> status() async {
    reads++;
    return statusResult;
  }
}

AppUpdateCubit _cubitFor(_Repository repository) => AppUpdateCubit(
  CheckForAppUpdate(repository),
  DownloadAppUpdate(repository),
  ReadAppUpdateDownload(repository),
  InstallAppUpdate(repository),
);

void main() {
  test('check exposes a newly available release', () async {
    final repository = _Repository();
    final cubit = _cubitFor(repository);
    addTearDown(cubit.close);

    await cubit.check(manual: true);

    expect(cubit.state, isA<AppUpdateAvailable>());
    expect((cubit.state as AppUpdateAvailable).release.versionCode, 4016);
    expect(repository.reads, 1);
    expect(repository.checks, 1);
  });

  test('restores a ready download without checking the server', () async {
    final repository = _Repository()
      ..statusResult = const ApiSuccess(
        UpdateDownload(phase: UpdateDownloadPhase.ready, versionCode: 4016),
      );
    final cubit = _cubitFor(repository);
    addTearDown(cubit.close);

    await cubit.check();

    expect(cubit.state, isA<AppUpdateReady>());
    expect(repository.checks, 0);
  });

  test(
    'download then install updates ready state and invokes each operation once',
    () async {
      final repository = _Repository();
      final cubit = _cubitFor(repository);
      addTearDown(cubit.close);
      await cubit.check();

      await cubit.download();
      expect(cubit.state, isA<AppUpdateReady>());
      await cubit.install();

      expect(repository.downloads, 1);
      expect(repository.installs, 1);
      expect((cubit.state as AppUpdateReady).installing, isFalse);
    },
  );

  test('surfaces check download and install failures', () async {
    final repository = _Repository()
      ..checkResult = const ApiFailure(
        ApiFailureReason.network,
        message: 'offline',
      );
    final cubit = _cubitFor(repository);
    addTearDown(cubit.close);

    await cubit.check(manual: true);
    expect((cubit.state as AppUpdateError).message, 'offline');
    repository.checkResult = ApiSuccess(_release);
    await cubit.check(manual: true);
    repository.downloadResult = const ApiFailure(
      ApiFailureReason.network,
      message: 'download failed',
    );
    await cubit.download();
    expect((cubit.state as AppUpdateError).message, 'download failed');
  });

  test('ignores duplicate checks and emits nothing after disposal', () async {
    final repository = _Repository()
      ..pendingCheck = Completer<ApiResult<AppRelease?>>();
    final cubit = _cubitFor(repository);
    final first = cubit.check(manual: true);
    await Future<void>.delayed(Duration.zero);
    final second = cubit.check(manual: true);
    expect(repository.checks, 1);

    await cubit.close();
    repository.pendingCheck!.complete(ApiSuccess(_release));
    await Future.wait([first, second]);

    expect(cubit.isClosed, isTrue);
  });
}
