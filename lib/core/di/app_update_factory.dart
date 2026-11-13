import 'package:get_it/get_it.dart';

import '../../features/app_updates/data/android_update_platform.dart';
import '../../features/app_updates/data/app_update_api.dart';
import '../../features/app_updates/data/app_update_repository_impl.dart';
import '../../features/app_updates/domain/app_update_repository.dart';
import '../../features/app_updates/domain/app_update_use_cases.dart';
import '../../features/app_updates/presentation/app_update_cubit.dart';

AppUpdateCubit createAppUpdateCubit() {
  final di = GetIt.instance;
  if (!di.isRegistered<AppUpdateRepository>()) {
    di.registerLazySingleton<AppUpdateApi>(
      () => AppUpdateApi(),
      dispose: (api) => api.dispose(),
    );
    di.registerLazySingleton<AndroidUpdatePlatform>(
      () => const AndroidUpdatePlatform(),
    );
    di.registerLazySingleton<AppUpdateRepository>(
      () => AppUpdateRepositoryImpl(di(), di()),
    );
    di.registerLazySingleton<CheckForAppUpdate>(() => CheckForAppUpdate(di()));
    di.registerLazySingleton<DownloadAppUpdate>(() => DownloadAppUpdate(di()));
    di.registerLazySingleton<ReadAppUpdateDownload>(
      () => ReadAppUpdateDownload(di()),
    );
    di.registerLazySingleton<InstallAppUpdate>(() => InstallAppUpdate(di()));
    di.registerFactory<AppUpdateCubit>(
      () => AppUpdateCubit(di(), di(), di(), di()),
    );
  }
  return di<AppUpdateCubit>();
}
