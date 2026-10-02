import 'package:get_it/get_it.dart';
import '../../features/deliveries/data/courier_orders_api.dart';
import '../../features/deliveries/data/courier_orders_repository_impl.dart';
import '../../features/deliveries/domain/courier_orders_repository.dart';
import '../../features/deliveries/domain/courier_orders_use_cases.dart';
import '../../features/deliveries/presentation/controllers/courier_order_actions_cubit.dart';
import '../../features/deliveries/presentation/controllers/courier_orders_cubit.dart';

void configureCourierOrders() {
  final di = GetIt.instance;
  if (di.isRegistered<CourierOrdersRepository>()) return;
  di.registerLazySingleton<CourierOrdersApi>(() => const CourierOrdersApi());
  di.registerLazySingleton<CourierOrdersRepository>(
    () => CourierOrdersRepositoryImpl(di()),
  );
  di.registerLazySingleton<LoadActiveCourierOrders>(
    () => LoadActiveCourierOrders(di()),
  );
  di.registerLazySingleton<LoadCourierHistory>(() => LoadCourierHistory(di()));
  di.registerLazySingleton<LoadCourierOrder>(() => LoadCourierOrder(di()));
  di.registerLazySingleton<PickUpCourierOrder>(() => PickUpCourierOrder(di()));
  di.registerLazySingleton<PickUpCourierMarket>(
    () => PickUpCourierMarket(di()),
  );
  di.registerLazySingleton<DeliverCourierOrder>(
    () => DeliverCourierOrder(di()),
  );
  di.registerFactory<CourierOrderActionsCubit>(
    () => CourierOrderActionsCubit(di(), di(), di(), di()),
  );
  di.registerFactory<CourierOrdersCubit>(() => CourierOrdersCubit(di(), di()));
}

T courierDependency<T extends Object>() {
  configureCourierOrders();
  return GetIt.instance<T>();
}
