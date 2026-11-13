import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../domain/app_release.dart';
import 'app_update_cubit.dart';

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AppUpdateCubit, AppUpdateState>(
        builder: (context, state) => AlertDialog(
          icon: const Icon(
            Icons.system_update_rounded,
            color: AppColors.primary,
            size: 40,
          ),
          title: const Text('تحديث يلا دليفيري', textAlign: TextAlign.center),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(child: AppUpdatePanel(state: state)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                state is AppUpdateAvailable
                    ? 'لاحقًا'
                    : 'متابعة استخدام التطبيق',
              ),
            ),
          ],
        ),
      );
}

class AppUpdatePanel extends StatelessWidget {
  const AppUpdatePanel({
    super.key,
    required this.state,
    this.compact = false,
    this.onDismiss,
  });
  final AppUpdateState state;
  final bool compact;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AppUpdateCubit>();
    final (title, description, action, onPressed) = switch (state) {
      AppUpdateAvailable(:final release) => (
        'تحديث جديد متاح · ${release.versionName}',
        '${(release.fileSize / 1000000).toStringAsFixed(1)} MB • التحميل هيكمل في الخلفية',
        'تحميل الآن',
        () => cubit.download(),
      ),
      AppUpdateProgress(:final download) => (
        download.phase == UpdateDownloadPhase.verifying
            ? 'جارٍ تجهيز التحديث…'
            : 'جارٍ تحميل التحديث…',
        download.phase == UpdateDownloadPhase.verifying
            ? 'بنتأكد من سلامة الملف قبل التثبيت'
            : download.progress == null
            ? 'بانتظار الاتصال بالإنترنت'
            : '${(download.progress! * 100).toInt()}٪ • يمكنك متابعة استخدام التطبيق',
        '',
        null,
      ),
      AppUpdateReady(:final installing) => (
        'التحديث جاهز للتثبيت',
        'اضغط «تثبيت الآن» ووافق على شاشة تثبيت أندرويد',
        installing ? 'جارٍ فتح التثبيت…' : 'تثبيت الآن',
        installing ? null : () => cubit.install(),
      ),
      AppUpdateError(:final message) => (
        'تعذّر إكمال التحديث',
        message,
        'إعادة المحاولة',
        () => cubit.check(manual: true),
      ),
      AppUpdateChecking() => ('جارٍ فحص التحديثات…', '', '', null),
      AppUpdateCurrent() => (
        'تطبيقك محدّث',
        'أنت تستخدم أحدث إصدار متاح',
        '',
        null,
      ),
      AppUpdateIdle() => ('', '', '', null),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (compact) ...[
              const Icon(Icons.system_update_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'إغلاق',
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 20),
              ),
          ],
        ),
        if (state case AppUpdateProgress(:final download)) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: download.phase == UpdateDownloadPhase.verifying
                ? null
                : download.progress,
          ),
        ],
        if (state is AppUpdateChecking) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (state case AppUpdateAvailable(:final release) when !compact) ...[
          if (release.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'الجديد في التحديث',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(release.releaseNotes),
          ],
          const SizedBox(height: 12),
          const Text(
            'بعد اكتمال التحميل هيظهر إشعار للتثبيت. قد يطلب أندرويد السماح بالتثبيت من يلا دليفيري.',
          ),
        ],
        if (action.isNotEmpty) ...[
          const SizedBox(height: 10),
          FilledButton(onPressed: onPressed, child: Text(action)),
        ],
      ],
    );
  }
}

class AppUpdateCheckTile extends StatelessWidget {
  const AppUpdateCheckTile({super.key});
  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: const Icon(
        Icons.system_update_rounded,
        color: AppColors.primary,
      ),
      title: const Text('تحديث التطبيق'),
      subtitle: const Text('فحص وجود إصدار جديد من يلا دليفيري'),
      onTap: () => context.read<AppUpdateCubit>().check(manual: true),
    );
  }
}
