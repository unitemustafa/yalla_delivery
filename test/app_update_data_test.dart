import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yalla_home/core/domain/api_result.dart';
import 'package:yalla_home/features/app_updates/data/android_update_platform.dart';
import 'package:yalla_home/features/app_updates/data/app_update_api.dart';
import 'package:yalla_home/features/app_updates/data/app_update_models.dart';
import 'package:yalla_home/features/app_updates/data/app_update_repository_impl.dart';
import 'package:yalla_home/features/app_updates/domain/app_release.dart';

const _sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, Object> validRelease({int code = 4016}) => {
  'version_code': code,
  'version_name': '1.0.12',
  'download_url': 'https://api.example.com/media/yalla.apk',
  'sha256': _sha,
  'file_size': 1234,
  'release_notes': 'إصلاحات',
};

class _Platform extends AndroidUpdatePlatform {
  _Platform({this.version, this.installError});
  final int? version;
  PlatformException? installError;
  int downloads = 0;
  int installs = 0;

  @override
  Future<int?> installedVersion() async => version;

  @override
  Future<UpdateDownload> status() async =>
      const UpdateDownload(phase: UpdateDownloadPhase.idle);

  @override
  Future<UpdateDownload> download(AppRelease release) async {
    downloads++;
    return UpdateDownload(
      phase: UpdateDownloadPhase.ready,
      versionCode: release.versionCode,
      versionName: release.versionName,
    );
  }

  @override
  Future<void> install() async {
    installs++;
    if (installError != null) throw installError!;
  }
}

void main() {
  group('release metadata', () {
    test('parses a valid HTTPS release', () {
      final release = parseAppRelease(validRelease());
      expect(release.versionCode, 4016);
      expect(release.downloadUrl.host, 'api.example.com');
      expect(release.releaseNotes, 'إصلاحات');
    });

    test('rejects unsafe or incomplete release metadata', () {
      final invalidReleases = [
        {...validRelease(), 'download_url': 'http://api.example.com/yalla.apk'},
        {
          ...validRelease(),
          'download_url': 'https://user@api.example.com/yalla.apk',
        },
        {
          ...validRelease(),
          'download_url': 'https://api.example.com/yalla.apk#part',
        },
        {...validRelease(), 'sha256': 'not-a-sha'},
        {...validRelease(), 'version_code': 0},
        {...validRelease(), 'file_size': 0},
      ];

      for (final value in invalidReleases) {
        expect(() => parseAppRelease(value), throwsFormatException);
      }
    });
  });

  group('latest update API', () {
    test('sends installed version and decodes UTF-8 notes', () async {
      final api = AppUpdateApi(
        baseUrl: () => 'https://api.example.com/api/v1',
        client: MockClient((request) async {
          expect(request.url.queryParameters['version_code'], '4015');
          return http.Response.bytes(
            utf8.encode(_latestJson('تحديث آمن')),
            200,
          );
        }),
      );

      final release = await api.latest(4015);
      expect(release!.releaseNotes, 'تحديث آمن');
      api.dispose();
    });

    test('returns null for no update and stale server releases', () async {
      final absent = AppUpdateApi(
        baseUrl: () => 'https://api.example.com/api/v1',
        client: MockClient((_) async => http.Response('{"update":null}', 200)),
      );
      expect(await absent.latest(4015), isNull);
      absent.dispose();
      final stale = AppUpdateApi(
        baseUrl: () => 'https://api.example.com/api/v1',
        client: MockClient(
          (_) async => http.Response(_latestJson('', code: 4015), 200),
        ),
      );
      expect(await stale.latest(4015), isNull);
      stale.dispose();
    });

    test('maps non-200 and malformed replies to typed exceptions', () async {
      final server = AppUpdateApi(
        baseUrl: () => 'https://api.example.com/api/v1',
        client: MockClient((_) async => http.Response('error', 503)),
      );
      expect(() => server.latest(1), throwsA(isA<Object>()));
      server.dispose();
      final malformed = AppUpdateApi(
        baseUrl: () => 'https://api.example.com/api/v1',
        client: MockClient((_) async => http.Response('{"wrong":true}', 200)),
      );
      expect(() => malformed.latest(1), throwsFormatException);
      malformed.dispose();
    });
  });

  test('repository maps API and platform results into ApiResult', () async {
    final platform = _Platform(version: 4015);
    final api = AppUpdateApi(
      baseUrl: () => 'https://api.example.com/api/v1',
      client: MockClient(
        (_) async => http.Response(_latestJson('', code: 4016), 200),
      ),
    );
    final repository = AppUpdateRepositoryImpl(api, platform);

    final checked = await repository.check();
    expect((checked as ApiSuccess<AppRelease?>).data!.versionCode, 4016);
    final downloaded = await repository.download(checked.data!);
    expect(downloaded, isA<ApiSuccess<UpdateDownload>>());
    expect(platform.downloads, 1);

    final failingRepository = AppUpdateRepositoryImpl(
      api,
      _Platform(
        version: 4015,
        installError: PlatformException(code: 'blocked'),
      ),
    );
    final install = await failingRepository.install();
    expect((install as ApiFailure<void>).reason, ApiFailureReason.server);
    api.dispose();
  });
}

String _latestJson(String notes, {int code = 4016}) => jsonEncode({
  'update': {...validRelease(code: code), 'release_notes': notes},
});
