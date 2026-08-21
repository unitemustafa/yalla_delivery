class AppAssets {
  AppAssets._();

  static const String _imagesPath = 'assets/images';
  static const String _logosPath = 'assets/logos';
  static const String _placeholdersPath = '$_imagesPath/placeholders';

  // Frontend-only fallbacks for images returned by the API.
  static const String defaultUserAvatar =
      '$_placeholdersPath/default_user_avatar.webp';
  static const String defaultProduct =
      '$_placeholdersPath/default_product.webp';
  static const String defaultCourier =
      '$_placeholdersPath/default_courier.webp';

  static const String logo = '$_logosPath/yallahome_logo.webp';
}
