class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.sha256,
    required this.fileSize,
    this.releaseNotes = '',
  });

  final int versionCode;
  final String versionName;
  final Uri downloadUrl;
  final String sha256;
  final int fileSize;
  final String releaseNotes;
}

enum UpdateDownloadPhase { idle, downloading, verifying, ready, failed }

class UpdateDownload {
  const UpdateDownload({
    required this.phase,
    this.versionCode = 0,
    this.versionName = '',
    this.downloaded = 0,
    this.total = 0,
    this.message = '',
  });

  final UpdateDownloadPhase phase;
  final int versionCode;
  final String versionName;
  final int downloaded;
  final int total;
  final String message;
  double? get progress => total > 0 ? (downloaded / total).clamp(0, 1) : null;
}
