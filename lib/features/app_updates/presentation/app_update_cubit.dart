import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/api_result.dart';
import '../domain/app_release.dart';
import '../domain/app_update_use_cases.dart';

sealed class AppUpdateState {
  const AppUpdateState();
}

final class AppUpdateIdle extends AppUpdateState {
  const AppUpdateIdle();
}

final class AppUpdateChecking extends AppUpdateState {
  const AppUpdateChecking();
}

final class AppUpdateCurrent extends AppUpdateState {
  const AppUpdateCurrent();
}

final class AppUpdateAvailable extends AppUpdateState {
  const AppUpdateAvailable(this.release);
  final AppRelease release;
}

final class AppUpdateProgress extends AppUpdateState {
  const AppUpdateProgress(this.download);
  final UpdateDownload download;
}

final class AppUpdateReady extends AppUpdateState {
  const AppUpdateReady(this.download, {this.installing = false});
  final UpdateDownload download;
  final bool installing;
}

final class AppUpdateError extends AppUpdateState {
  const AppUpdateError(this.message);
  final String message;
}

class AppUpdateCubit extends Cubit<AppUpdateState> {
  AppUpdateCubit(this._check, this._download, this._read, this._install)
    : super(const AppUpdateIdle());
  final CheckForAppUpdate _check;
  final DownloadAppUpdate _download;
  final ReadAppUpdateDownload _read;
  final InstallAppUpdate _install;
  Timer? _timer;
  bool _busy = false;
  bool _polling = false;
  AppRelease? _release;
  DateTime? _lastCheck;

  Future<void> check({bool manual = false}) async {
    if (_busy ||
        isClosed ||
        state is AppUpdateProgress ||
        (state is AppUpdateReady && (state as AppUpdateReady).installing)) {
      return;
    }
    if (!manual &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(minutes: 15)) {
      if (state is AppUpdateReady) await _poll();
      return;
    }
    _busy = true;
    final previous = state;
    if (manual) emit(const AppUpdateChecking());
    try {
      final restored = await _read();
      if (isClosed) return;
      if (restored case ApiSuccess<UpdateDownload>(:final data)
          when data.phase != UpdateDownloadPhase.idle &&
              data.phase != UpdateDownloadPhase.failed) {
        _accept(data);
        return;
      }
      final result = await _check();
      if (isClosed) return;
      switch (result) {
        case ApiSuccess<AppRelease?>(:final data):
          _lastCheck = DateTime.now();
          _release = data;
          if (data == null) {
            if (restored case ApiSuccess<UpdateDownload>(
              :final data,
            ) when data.phase == UpdateDownloadPhase.failed) {
              emit(AppUpdateError(data.message));
            } else {
              emit(manual ? const AppUpdateCurrent() : const AppUpdateIdle());
            }
          } else {
            emit(AppUpdateAvailable(data));
          }
        case ApiFailure<AppRelease?>(:final message):
          emit(
            manual
                ? AppUpdateError(message ?? 'تعذّر فحص التحديثات.')
                : previous,
          );
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> download() async {
    final release = _release;
    if (_busy || isClosed || release == null) return;
    _busy = true;
    emit(
      AppUpdateProgress(
        UpdateDownload(
          phase: UpdateDownloadPhase.downloading,
          versionCode: release.versionCode,
          versionName: release.versionName,
          total: release.fileSize,
        ),
      ),
    );
    try {
      final result = await _download(release);
      if (isClosed) return;
      switch (result) {
        case ApiSuccess<UpdateDownload>(:final data):
          _accept(data);
        case ApiFailure<UpdateDownload>(:final message):
          emit(AppUpdateError(message ?? 'تعذّر بدء التحميل.'));
      }
    } finally {
      _busy = false;
    }
  }

  void _accept(UpdateDownload value) {
    if (isClosed) return;
    _timer?.cancel();
    switch (value.phase) {
      case UpdateDownloadPhase.downloading || UpdateDownloadPhase.verifying:
        emit(AppUpdateProgress(value));
        _timer = Timer(const Duration(seconds: 1), _poll);
      case UpdateDownloadPhase.ready:
        emit(AppUpdateReady(value));
      case UpdateDownloadPhase.failed:
        emit(AppUpdateError(value.message));
      case UpdateDownloadPhase.idle:
        emit(const AppUpdateIdle());
    }
  }

  Future<void> _poll() async {
    if (_polling || isClosed) return;
    _polling = true;
    try {
      final result = await _read();
      if (isClosed) return;
      switch (result) {
        case ApiSuccess<UpdateDownload>(:final data):
          _accept(data);
        case ApiFailure<UpdateDownload>(:final message):
          emit(AppUpdateError(message ?? 'تعذّر متابعة التحميل. أعد الفحص.'));
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> install() async {
    final current = state;
    if (current is! AppUpdateReady || current.installing || isClosed) return;
    emit(AppUpdateReady(current.download, installing: true));
    final result = await _install();
    if (isClosed) return;
    switch (result) {
      case ApiSuccess<void>():
        emit(AppUpdateReady(current.download));
      case ApiFailure<void>(:final message):
        emit(
          AppUpdateError(message ?? 'تعذّر فتح التثبيت. أعد الفحص للمحاولة.'),
        );
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
