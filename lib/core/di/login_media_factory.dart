import '../../features/auth/data/login_media_repository.dart';
import '../../features/auth/domain/load_delivery_media.dart';

// The legacy app has no global DI container. Keep this composition boundary
// explicit and give each login screen ownership of its HTTP client.
LoadDeliveryMedia createLoadDeliveryMedia() =>
    LoadDeliveryMedia(LoginMediaRepository());
