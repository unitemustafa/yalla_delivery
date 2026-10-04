import '../../../core/texts/app_texts.dart';

class CourierAccount {
  const CourierAccount({
    required this.raw,
    required this.role,
    this.firstName,
    this.lastName,
    this.username,
    this.phone,
    this.email,
    this.avatarUrl,
    this.profile,
  });

  final Map<String, dynamic> raw;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final CourierProfile? profile;

  String get displayName {
    final name = [firstName, lastName]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
    if (name.isNotEmpty) return name;
    return username?.trim().isNotEmpty == true
        ? username!.trim()
        : BrandTexts.courierFallbackName;
  }

  String get secondaryLabel {
    final cleanUsername = username?.trim();
    if (cleanUsername != null && cleanUsername.isNotEmpty) {
      return '@$cleanUsername';
    }
    final cleanPhone = phone?.trim();
    if (cleanPhone != null && cleanPhone.isNotEmpty) return cleanPhone;
    final cleanEmail = email?.trim();
    if (cleanEmail != null && cleanEmail.isNotEmpty) return cleanEmail;
    return ProfileTexts.contactUnspecified;
  }

  factory CourierAccount.fromJson(Map<String, dynamic> json) {
    final profileJson = json['courier_profile'];
    return CourierAccount(
      raw: Map<String, dynamic>.from(json),
      role: _string(json['role']) ?? '',
      firstName: _string(json['first_name']),
      lastName: _string(json['last_name']),
      username: _string(json['username']),
      phone: _string(json['phone']),
      email: _string(json['email']),
      avatarUrl: _string(json['avatar_url']),
      profile: profileJson is Map<String, dynamic>
          ? CourierProfile.fromJson(profileJson)
          : null,
    );
  }
}

class CourierProfile {
  const CourierProfile({
    this.vehicleType,
    this.plateNumber,
    this.serviceCity,
    this.serviceCityName,
    this.maxActiveOrders,
    this.isAvailable,
    this.isShippingCompany = false,
  });

  final String? vehicleType;
  final String? plateNumber;
  final Object? serviceCity;
  final String? serviceCityName;
  final int? maxActiveOrders;
  final bool? isAvailable;
  final bool isShippingCompany;

  String get serviceCityLabel {
    if (isShippingCompany) return ProfileTexts.allCities;
    final value = serviceCityName?.trim();
    return value == null || value.isEmpty
        ? ProfileTexts.serviceCityUnspecified
        : value;
  }

  String get availabilityLabel {
    return switch (isAvailable) {
      true => ProfileTexts.available,
      false => ProfileTexts.unavailableNow,
      null => OrderStatusTexts.unknown,
    };
  }

  String get vehicleTypeLabel {
    final value = vehicleType?.trim();
    return value == null || value.isEmpty ? CommonTexts.unspecified : value;
  }

  String get plateNumberLabel {
    final value = plateNumber?.trim();
    return value == null || value.isEmpty ? CommonTexts.unspecified : value;
  }

  String get maxActiveOrdersLabel {
    final value = maxActiveOrders;
    return value == null ? ProfileTexts.unlimitedOrders : '$value';
  }

  factory CourierProfile.fromJson(Map<String, dynamic> json) {
    return CourierProfile(
      vehicleType: _string(json['vehicle_type']),
      plateNumber: _string(json['plate_number']),
      serviceCity: json['service_city'],
      serviceCityName: _string(json['service_city_name']),
      maxActiveOrders: _int(json['max_active_orders']),
      isShippingCompany: json['is_shipping_company'] == true,
      isAvailable: json['is_available'] is bool
          ? json['is_available'] as bool
          : null,
    );
  }
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
