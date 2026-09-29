import 'dart:typed_data';

import '../../../core/auth/auth_session.dart';

enum CourierOrderStatus {
  pending,
  confirmed,
  assigned,
  pickedUp,
  delivered,
  failedDelivery,
  cancelled,
  unknown,
}

extension CourierOrderStatusRules on CourierOrderStatus {
  bool get isTerminal {
    return switch (this) {
      CourierOrderStatus.delivered ||
      CourierOrderStatus.failedDelivery ||
      CourierOrderStatus.cancelled => true,
      _ => false,
    };
  }

  bool get isActiveCourierOrder {
    return this == CourierOrderStatus.assigned ||
        this == CourierOrderStatus.pickedUp;
  }

  bool get requiresPickup => this == CourierOrderStatus.assigned;

  bool get canMarkPickedUp => this == CourierOrderStatus.assigned;

  bool get canMarkDelivered => this == CourierOrderStatus.pickedUp;

  bool get isDelivered => this == CourierOrderStatus.delivered;
}

CourierOrderStatus courierOrderStatusFromRaw(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'pending' => CourierOrderStatus.pending,
    'confirmed' => CourierOrderStatus.confirmed,
    'assigned' => CourierOrderStatus.assigned,
    'under_preparation' || 'preparing' => CourierOrderStatus.confirmed,
    'ready' => CourierOrderStatus.assigned,
    'picked_up' => CourierOrderStatus.pickedUp,
    'on_the_way' => CourierOrderStatus.pickedUp,
    'delivered' || 'completed' => CourierOrderStatus.delivered,
    'failed_delivery' => CourierOrderStatus.failedDelivery,
    'cancelled' || 'canceled' || 'rejected' => CourierOrderStatus.cancelled,
    _ => CourierOrderStatus.unknown,
  };
}

class DeliveryProof {
  const DeliveryProof({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class OrderLocation {
  const OrderLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class CourierOrderItem {
  const CourierOrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.subtotal,
    this.description,
    this.imageUrl,
    this.sku,
    this.marketName,
    this.marketId,
    this.sectionId,
  });

  final String name;
  final int quantity;
  final double price;
  final double? subtotal;
  final String? description;
  final String? imageUrl;
  final String? sku;
  final String? marketName;
  final int? marketId;
  final int? sectionId;

  double get total => subtotal ?? price * quantity;
}

class CourierMarketSection {
  const CourierMarketSection({
    required this.id,
    required this.marketId,
    required this.marketName,
    required this.pickupStatus,
  });

  final int id;
  final int? marketId;
  final String marketName;
  final String pickupStatus;

  bool get isPickedUp => pickupStatus == 'picked_up';
}

class CourierMarketProductGroup {
  const CourierMarketProductGroup({
    required this.marketName,
    required this.marketId,
    required this.sectionId,
    required this.isPickedUp,
    required this.items,
  });

  final String marketName;
  final int? marketId;
  final int? sectionId;
  final bool isPickedUp;
  final List<CourierOrderItem> items;
}

class CourierOrderOffer {
  const CourierOrderOffer({
    required this.title,
    this.description,
    this.imageUrl,
    this.discount,
  });

  final String title;
  final String? description;
  final String? imageUrl;
  final double? discount;
}

class CourierOrder {
  const CourierOrder({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.area,
    required this.total,
    required this.deliveryPrice,
    required this.status,
    required this.rawStatus,
    required this.createdAt,
    required this.expectedDeliveryAt,
    required this.items,
    required this.itemsCount,
    required this.marketName,
    required this.marketBranch,
    required this.marketCount,
    required this.marketSummary,
    this.marketSections = const [],
    this.offers = const [],
    this.addressLabel,
    this.addressInstructions,
    this.serviceCityName,
    this.deliveryAreaName,
    this.customerAvatarUrl,
    this.mapQuery,
    this.customerLocation,
    this.customerNotes,
    this.orderImageUrl,
    this.paymentMethod,
    this.subtotal,
    this.discount,
    this.multiMarketFee,
    this.fulfillmentType,
    this.deliveryType,
    this.shippingCompanyName,
    this.etaMinMinutes,
    this.etaMaxMinutes,
    this.assignedAt,
    this.updatedAt,
    this.deliveredAt,
    this.deliveryNote,
    this.deliveryProof,
    this.deliveryProofUrl,
  });

  final String id;
  final String customerName;
  final String phone;
  final String address;
  final String area;
  final double total;
  final double? deliveryPrice;
  final CourierOrderStatus status;
  final String rawStatus;
  final DateTime createdAt;
  final DateTime expectedDeliveryAt;
  final List<CourierOrderItem> items;
  final int itemsCount;
  final String marketName;
  final String marketBranch;
  final int marketCount;
  final String marketSummary;
  final List<CourierMarketSection> marketSections;
  final List<CourierOrderOffer> offers;
  final String? addressLabel;
  final String? addressInstructions;
  final String? serviceCityName;
  final String? deliveryAreaName;
  final String? customerAvatarUrl;
  final String? mapQuery;
  final OrderLocation? customerLocation;
  final String? customerNotes;
  final String? orderImageUrl;
  final String? paymentMethod;
  final double? subtotal;
  final double? discount;
  final double? multiMarketFee;
  final String? fulfillmentType;
  final String? deliveryType;
  final String? shippingCompanyName;
  final int? etaMinMinutes;
  final int? etaMaxMinutes;
  final DateTime? assignedAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;
  final String? deliveryNote;
  final DeliveryProof? deliveryProof;
  final String? deliveryProofUrl;

  factory CourierOrder.fromJson(Map<String, dynamic> json) {
    final customer = _map(json['customer']);
    final address = _map(json['delivery_address']);
    final market = _map(json['market']);
    final serviceCity = _map(json['service_city']);
    final deliveryArea = _map(json['delivery_area']);
    final addressServiceCity = _map(address?['service_city']);
    final addressDeliveryArea = _map(address?['delivery_area']);
    final itemsJson = _list(json['items']);
    final offersJson = _list(json['offers']);
    final sectionsJson = _list(json['market_sections']);
    final rawStatus = json['status']?.toString() ?? '';
    final status = courierOrderStatusFromRaw(rawStatus);
    final createdAt = _parseDate(json['created_at']);
    final assignedAt = _parseDate(json['assigned_at'], fallback: createdAt);
    final deliveredAt =
        _parseOptionalDate(json['delivered_at']) ??
        _deliveredAtFromHistory(json['history']);
    final label = _clean(address?['name']);
    final details = _clean(address?['details']);
    final formattedAddress = _clean(address?['formatted_address']);
    final street = _clean(address?['street']);
    final buildingName = _clean(address?['building_name']);
    final apartmentNumber = _clean(address?['apartment_number']);
    final floor = _clean(address?['floor']);
    final manualArea = _clean(address?['manual_area']);
    final manualCity = _clean(address?['manual_city']);
    final areaName =
        _clean(addressDeliveryArea?['name']) ?? _clean(deliveryArea?['name']);
    final cityName =
        _clean(addressServiceCity?['name']) ?? _clean(serviceCity?['name']);
    final displayAddress = _joinUnique([
      formattedAddress,
      street,
      buildingName,
      apartmentNumber,
      floor,
      details,
      manualArea,
      manualCity,
      areaName,
      cityName,
    ]);
    final latitude = _optionalNumber(address?['latitude']);
    final longitude = _optionalNumber(address?['longitude']);
    final hasCustomerLocation =
        latitude != null &&
        longitude != null &&
        latitude != 0 &&
        longitude != 0;
    final marketName = _clean(market?['name']) ?? '';
    final marketBranch = _clean(market?['branch']) ?? '';
    final marketCount = _int(json['market_count']);
    final marketNamesSummary = _clean(json['market_names_summary']);
    final items = itemsJson
        .map(
          (item) => _itemFromJson(
            item,
            fallbackMarketName: marketCount <= 1 ? marketName : null,
          ),
        )
        .toList();
    final shippingCompany = _map(json['shipping_company']);
    final recipientName = _clean(address?['recipient_name']);
    final recipientPhone = _clean(address?['recipient_phone']);

    return CourierOrder(
      id: json['id'].toString(),
      customerName:
          recipientName ??
          _clean(customer?['name']) ??
          _joinUnique([
            _clean(customer?['first_name']),
            _clean(customer?['last_name']),
          ]) ??
          'عميل',
      phone: recipientPhone ?? _clean(customer?['phone']) ?? '',
      address:
          displayAddress ?? label ?? areaName ?? cityName ?? 'العنوان غير محدد',
      addressLabel: label,
      addressInstructions: _clean(address?['additional_instructions']),
      area: areaName ?? manualArea ?? cityName ?? manualCity ?? 'غير محدد',
      total: _number(json['total_price']),
      deliveryPrice: _optionalNumber(json['delivery_price']),
      status: status,
      rawStatus: rawStatus,
      createdAt: createdAt,
      expectedDeliveryAt: assignedAt.add(const Duration(hours: 1)),
      items: items,
      offers: offersJson.map(_offerFromJson).toList(),
      itemsCount: _int(
        json['items_count'],
        fallback: _sumItemQuantities(items),
      ),
      marketName: marketName,
      marketBranch: marketBranch,
      marketCount: marketCount,
      marketSummary: _marketSummary(
        marketName: marketName,
        branch: marketBranch,
        count: marketCount,
        namesSummary: marketNamesSummary,
      ),
      marketSections: sectionsJson.map(_marketSectionFromJson).toList(),
      serviceCityName: cityName,
      deliveryAreaName: areaName,
      customerAvatarUrl: AuthSession.instance.absoluteUrl(
        customer?['avatar_url'],
      ),
      mapQuery: _joinUnique([displayAddress, label, areaName, cityName]),
      customerLocation: hasCustomerLocation
          ? OrderLocation(latitude: latitude, longitude: longitude)
          : null,
      customerNotes: _clean(json['description']),
      orderImageUrl: AuthSession.instance.absoluteUrl(json['image']),
      paymentMethod: _clean(json['payment_method']),
      subtotal: _optionalNumber(json['subtotal_price']),
      discount: _optionalNumber(json['discount']),
      multiMarketFee: _optionalNumber(json['multi_market_fee']),
      fulfillmentType: _clean(json['fulfillment_type']),
      deliveryType: _clean(json['delivery_type']),
      shippingCompanyName: _clean(shippingCompany?['name']),
      etaMinMinutes: _optionalInt(json['eta_min_minutes']),
      etaMaxMinutes: _optionalInt(json['eta_max_minutes']),
      assignedAt: _parseOptionalDate(json['assigned_at']),
      updatedAt: _parseOptionalDate(json['updated_at']),
      deliveredAt: deliveredAt,
      deliveryNote: _clean(json['delivery_note']),
      deliveryProofUrl: AuthSession.instance.absoluteUrl(
        json['delivery_proof'],
      ),
    );
  }

  int get itemCount => itemsCount;

  bool get hasPerMarketPickup => marketSections.length > 1;

  bool get canCompletePickup =>
      !hasPerMarketPickup ||
      marketSections.every((section) => section.isPickedUp);

  int get totalMarketCount => marketSections.isNotEmpty
      ? marketSections.length
      : marketCount > productGroups.length
      ? marketCount
      : productGroups.length;

  int get pickedUpMarketCount =>
      status == CourierOrderStatus.pickedUp || isDelivered
      ? totalMarketCount
      : marketSections.where((section) => section.isPickedUp).length;

  List<CourierMarketProductGroup> get productGroups {
    final remaining = List<CourierOrderItem>.of(items);
    final groups = <CourierMarketProductGroup>[];
    final pickupCompleted =
        status == CourierOrderStatus.pickedUp || isDelivered;

    for (final section in marketSections) {
      final sectionItems = remaining
          .where(
            (item) =>
                item.sectionId == section.id ||
                (item.sectionId == null &&
                    item.marketId != null &&
                    item.marketId == section.marketId),
          )
          .toList();
      remaining.removeWhere(sectionItems.contains);
      groups.add(
        CourierMarketProductGroup(
          marketName: section.marketName,
          marketId: section.marketId,
          sectionId: section.id,
          isPickedUp: pickupCompleted || section.isPickedUp,
          items: sectionItems,
        ),
      );
    }

    final unsectioned = <String, List<CourierOrderItem>>{};
    for (final item in remaining) {
      final key = item.marketId != null
          ? 'market:${item.marketId}'
          : 'name:${item.marketName ?? marketName}';
      unsectioned.putIfAbsent(key, () => []).add(item);
    }
    for (final groupItems in unsectioned.values) {
      final first = groupItems.first;
      groups.add(
        CourierMarketProductGroup(
          marketName:
              first.marketName ??
              (marketCount <= 1 && marketName.isNotEmpty ? marketName : null) ??
              'المحل غير محدد',
          marketId: first.marketId,
          sectionId: null,
          isPickedUp: pickupCompleted,
          items: groupItems,
        ),
      );
    }
    return groups;
  }

  bool get isActiveCourierOrder => status.isActiveCourierOrder;

  bool get isDelivered => status.isDelivered;

  bool get isTerminal => status.isTerminal;

  bool get requiresPickup => status.requiresPickup;

  bool get canMarkPickedUp => status.canMarkPickedUp;

  bool get canMarkDelivered => status.canMarkDelivered;

  CourierOrder copyWith({
    CourierOrderStatus? status,
    String? rawStatus,
    DateTime? deliveredAt,
    String? deliveryNote,
    DeliveryProof? deliveryProof,
    String? deliveryProofUrl,
  }) {
    return CourierOrder(
      id: id,
      customerName: customerName,
      phone: phone,
      address: address,
      area: area,
      total: total,
      deliveryPrice: deliveryPrice,
      status: status ?? this.status,
      rawStatus: rawStatus ?? this.rawStatus,
      createdAt: createdAt,
      expectedDeliveryAt: expectedDeliveryAt,
      items: items,
      itemsCount: itemsCount,
      marketName: marketName,
      marketBranch: marketBranch,
      marketCount: marketCount,
      marketSummary: marketSummary,
      marketSections: marketSections,
      offers: offers,
      addressLabel: addressLabel,
      addressInstructions: addressInstructions,
      serviceCityName: serviceCityName,
      deliveryAreaName: deliveryAreaName,
      customerAvatarUrl: customerAvatarUrl,
      mapQuery: mapQuery,
      customerLocation: customerLocation,
      customerNotes: customerNotes,
      orderImageUrl: orderImageUrl,
      paymentMethod: paymentMethod,
      subtotal: subtotal,
      discount: discount,
      multiMarketFee: multiMarketFee,
      fulfillmentType: fulfillmentType,
      deliveryType: deliveryType,
      shippingCompanyName: shippingCompanyName,
      etaMinMinutes: etaMinMinutes,
      etaMaxMinutes: etaMaxMinutes,
      assignedAt: assignedAt,
      updatedAt: updatedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      deliveryProof: deliveryProof ?? this.deliveryProof,
      deliveryProofUrl: deliveryProofUrl ?? this.deliveryProofUrl,
    );
  }

  static CourierOrderItem _itemFromJson(
    Map<String, dynamic> item, {
    String? fallbackMarketName,
  }) {
    final product = _map(item['product']);
    final variant = _map(item['variant']);
    return CourierOrderItem(
      name:
          _clean(item['display_name']) ??
          _clean(item['product_name']) ??
          _clean(product?['name']) ??
          _clean(variant?['name']) ??
          'منتج',
      quantity: _int(item['quantity']),
      price: _number(item['unit_price']),
      subtotal:
          _optionalNumber(item['item_subtotal']) ??
          _optionalNumber(item['subtotal']),
      description: _clean(product?['description']),
      imageUrl: AuthSession.instance.absoluteUrl(product?['image']),
      sku: _clean(variant?['sku']),
      marketName: _clean(item['market_name']) ?? fallbackMarketName,
      marketId: _optionalInt(item['market_id']),
      sectionId: _optionalInt(item['section_id']),
    );
  }

  static CourierMarketSection _marketSectionFromJson(Map<String, dynamic> row) {
    final market = _map(row['market']);
    return CourierMarketSection(
      id: _int(row['id']),
      marketId: _optionalInt(row['market_id']) ?? _optionalInt(market?['id']),
      marketName: _clean(market?['name']) ?? 'المحل غير محدد',
      pickupStatus: _clean(row['pickup_status']) ?? 'pending',
    );
  }

  static CourierOrderOffer _offerFromJson(Map<String, dynamic> row) {
    final offer = _map(row['offer']) ?? row;
    return CourierOrderOffer(
      title: _clean(offer['title']) ?? '\u0639\u0631\u0636',
      description: _clean(offer['description']),
      imageUrl: AuthSession.instance.absoluteUrl(offer['image']),
      discount: _optionalNumber(offer['discount']),
    );
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const [];
    return value
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  static DateTime _parseDate(Object? value, {DateTime? fallback}) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
        fallback ??
        DateTime.now();
  }

  static DateTime? _parseOptionalDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  }

  static DateTime? _deliveredAtFromHistory(Object? value) {
    DateTime? latestDeliveredAt;
    for (final event in _list(value)) {
      final toStatus = event['to_status']?.toString().trim().toLowerCase();
      if (toStatus != 'delivered') continue;

      final createdAt = _parseOptionalDate(event['created_at']);
      if (createdAt == null) continue;
      if (latestDeliveredAt == null || createdAt.isAfter(latestDeliveredAt)) {
        latestDeliveredAt = createdAt;
      }
    }
    return latestDeliveredAt;
  }

  static double _number(Object? value) => _optionalNumber(value) ?? 0;

  static double? _optionalNumber(Object? value) {
    return double.tryParse(value?.toString() ?? '');
  }

  static int _int(Object? value, {int fallback = 0}) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _optionalInt(Object? value) {
    return int.tryParse(value?.toString() ?? '');
  }

  static int _sumItemQuantities(List<CourierOrderItem> items) {
    return items.fold<int>(0, (total, item) => total + item.quantity);
  }

  static String? _clean(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _joinUnique(Iterable<String?> values) {
    final parts = <String>[];
    for (final value in values) {
      final text = _clean(value);
      if (text == null) continue;
      if (!parts.contains(text)) parts.add(text);
    }
    return parts.isEmpty ? null : parts.join('، ');
  }

  static String _marketSummary({
    required String marketName,
    required String branch,
    required int count,
    required String? namesSummary,
  }) {
    if (count > 1) {
      return namesSummary?.isNotEmpty == true ? namesSummary! : '$count محلات';
    }
    return _joinUnique([marketName, branch]) ?? 'المحل غير محدد';
  }
}
