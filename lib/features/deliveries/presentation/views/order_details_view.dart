import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/formatters/app_currency.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/notifications/courier_push_service.dart';
import '../../../../core/presentation/widgets/app_action_button.dart';
import '../../../../core/presentation/widgets/authenticated_network_image.dart';
import '../../../../core/presentation/widgets/network_image_or_placeholder.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../data/courier_orders_api.dart';
import '../../domain/courier_order.dart';
import '../extensions/courier_order_status_presentation.dart';
import '../widgets/delivery_confirmation_sheet.dart';

part 'order_details_sections_part.dart';
part 'order_details_summary_part.dart';
part 'order_contact_options_part.dart';

typedef OrderPickedUpHandler = Future<CourierOrder> Function(String orderId);
typedef OrderDeliveredHandler =
    Future<CourierOrder> Function(
      String orderId,
      DeliveryConfirmationResult result,
    );

enum _SubmittingOrderAction { pickup, delivery }

class OrderDetailsView extends StatefulWidget {
  const OrderDetailsView({
    super.key,
    required this.order,
    this.onPickedUp,
    this.onDelivered,
  });

  final CourierOrder order;
  final OrderPickedUpHandler? onPickedUp;
  final OrderDeliveredHandler? onDelivered;

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState extends State<OrderDetailsView> {
  final _api = const CourierOrdersApi();
  late CourierOrder _order = widget.order;
  bool _loading = true;
  String? _error;
  _SubmittingOrderAction? _submittingAction;
  StreamSubscription<CourierPushEvent>? _pushSubscription;

  @override
  void initState() {
    super.initState();
    _pushSubscription = CourierPushService.instance.events.listen(
      _handlePushEvent,
    );
    _loadDetails();
  }

  void _handlePushEvent(CourierPushEvent event) {
    if (!mounted || event.data['order_id']?.toString() != widget.order.id) {
      return;
    }
    if (event.event != 'courier_order_unassigned' &&
        event.event != 'courier_order_cancelled') {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          event.event == 'courier_order_unassigned'
              ? 'لم يعد هذا الطلب معينًا لك.'
              : 'تم إلغاء هذا الطلب.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await _api.loadOrder(widget.order.id);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openWhatsAppChat(BuildContext context) async {
    final phone = _order.phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.https('wa.me', '/$phone');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      if (!context.mounted) return;
      _showMessage('تعذر فتح واتساب على هذا الجهاز.');
    }
  }

  Future<void> _callCustomer(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: _order.phone);
    if (!await canLaunchUrl(uri)) {
      if (!context.mounted) return;
      _showMessage('المكالمات غير مدعومة على هذا الجهاز.');
      return;
    }
    await launchUrl(uri);
  }

  Future<void> _openCustomerMap(BuildContext context) async {
    final location = _order.customerLocation;
    final query = location == null
        ? _order.mapQuery?.trim()
        : '${location.latitude},${location.longitude}';
    if (query == null || query.isEmpty) return;

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': query,
      'travelmode': 'driving',
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showMessage('تعذر فتح الخريطة على هذا الجهاز.');
    }
  }

  bool get _hasMapDestination {
    return _order.customerLocation != null ||
        (_order.mapQuery?.trim().isNotEmpty ?? false);
  }

  void _showContactOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ContactOptionsSheet(
          onWhatsApp: () {
            Navigator.pop(sheetContext);
            _openWhatsAppChat(context);
          },
          onPhoneCall: () {
            Navigator.pop(sheetContext);
            _callCustomer(context);
          },
        );
      },
    );
  }

  Future<void> _markPickedUp() async {
    if (_submittingAction != null || !_order.canMarkPickedUp) return;

    setState(() => _submittingAction = _SubmittingOrderAction.pickup);
    try {
      final handler = widget.onPickedUp ?? _api.markPickedUp;
      final updated = await handler(_order.id);
      if (!mounted) return;
      setState(() => _order = updated);
      _showMessage('تم تسجيل الاستلام بنجاح.');
    } catch (error) {
      if (!mounted) return;
      CustomSnackBar.showError(context: context, title: error.toString());
    } finally {
      if (mounted) setState(() => _submittingAction = null);
    }
  }

  Future<void> _confirmDelivery() async {
    if (_submittingAction != null || !_order.canMarkDelivered) return;

    final result = await showModalBottomSheet<DeliveryConfirmationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeliveryConfirmationSheet(orderId: _order.id),
    );

    if (!mounted || result == null) return;
    setState(() => _submittingAction = _SubmittingOrderAction.delivery);
    try {
      final handler =
          widget.onDelivered ??
          (String orderId, DeliveryConfirmationResult result) {
            return _api.markDelivered(
              orderId,
              note: result.note,
              proofBytes: result.proofBytes,
              proofName: result.proofName,
            );
          };
      final updated = await handler(_order.id, result);
      if (!mounted) return;
      setState(() => _order = updated);
    } catch (error) {
      if (!mounted) return;
      CustomSnackBar.showError(context: context, title: error.toString());
      return;
    } finally {
      if (mounted) setState(() => _submittingAction = null);
    }
    if (!mounted) return;
    _showMessage('تم تسجيل التسليم بنجاح.');
    Navigator.pop(context);
  }

  void _showMessage(String message) {
    CustomSnackBar.showInfo(context: context, title: message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order = _order;
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.58);

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _DetailRetryState(error: _error!, onRetry: _loadDetails)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  PageTopBar(
                    title: 'تفاصيل الطلب',
                    subtitle: order.id,
                    showBackButton: true,
                  ),
                  const SizedBox(height: 14),
                  _OrderHeader(order: order, mutedColor: mutedColor),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'بيانات العميل',
                    children: [
                      _CustomerSummaryTile(
                        order: order,
                        mutedColor: mutedColor,
                      ),
                      if (order.addressLabel != null)
                        _DetailRow(
                          icon: AppIcons.location,
                          label: 'اسم العنوان',
                          value: order.addressLabel!,
                          mutedColor: mutedColor,
                        ),
                      _DetailRow(
                        icon: AppIcons.location,
                        label: 'العنوان',
                        value: order.address,
                        mutedColor: mutedColor,
                        copyable: true,
                      ),
                      if (order.deliveryAreaName != null)
                        _DetailRow(
                          icon: AppIcons.location,
                          label: 'المنطقة',
                          value: order.deliveryAreaName!,
                          mutedColor: mutedColor,
                        ),
                      if (order.serviceCityName != null)
                        _DetailRow(
                          icon: AppIcons.location,
                          label: 'المدينة',
                          value: order.serviceCityName!,
                          mutedColor: mutedColor,
                        ),
                      _DetailRow(
                        icon: AppIcons.shopping_bag,
                        label: 'المحل',
                        value: order.marketSummary,
                        mutedColor: mutedColor,
                      ),
                      if (order.marketCount > 1)
                        _DetailRow(
                          icon: AppIcons.box,
                          label: 'عدد المحلات',
                          value: '${order.marketCount}',
                          mutedColor: mutedColor,
                        ),
                      if (order.customerNotes != null)
                        _DetailRow(
                          icon: AppIcons.document_text,
                          label: 'ملاحظة العميل',
                          value: order.customerNotes!,
                          mutedColor: mutedColor,
                          copyable: true,
                        ),
                      if (order.addressInstructions != null)
                        _DetailRow(
                          icon: AppIcons.info_circle,
                          label: 'تعليمات العنوان',
                          value: order.addressInstructions!,
                          mutedColor: mutedColor,
                          copyable: true,
                        ),
                    ],
                  ),
                  if (order.orderImageUrl != null) ...[
                    const SizedBox(height: 12),
                    _OrderRequestImageCard(
                      order: order,
                      mutedColor: mutedColor,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'المنتجات',
                    children: order.items.isEmpty
                        ? [
                            Text(
                              'لا توجد منتجات في هذا الطلب.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: mutedColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ]
                        : [
                            for (final item in order.items)
                              _ProductRow(item: item),
                          ],
                  ),
                  if (order.offers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'العروض المضافة',
                      children: [
                        for (final offer in order.offers)
                          _OfferRow(offer: offer),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _OrderSummaryCard(order: order, mutedColor: mutedColor),
                  if (order.isDelivered) ...[
                    const SizedBox(height: 12),
                    _DeliveryProofCard(order: order, mutedColor: mutedColor),
                  ],
                  const SizedBox(height: 16),
                  if (order.phone.isNotEmpty || _hasMapDestination)
                    Row(
                      children: [
                        if (order.phone.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showContactOptions(context),
                              icon: const Icon(AppIcons.call, size: 18),
                              label: const Text('تواصل'),
                            ),
                          ),
                        if (order.phone.isNotEmpty && _hasMapDestination)
                          const SizedBox(width: 10),
                        if (_hasMapDestination)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openCustomerMap(context),
                              icon: const Icon(AppIcons.routing, size: 18),
                              label: const Text('الخريطة'),
                            ),
                          ),
                      ],
                    ),
                  if (order.canMarkPickedUp || order.canMarkDelivered) ...[
                    const SizedBox(height: 12),
                    _LifecycleActions(
                      order: order,
                      submittingAction: _submittingAction,
                      onPickupPressed: _markPickedUp,
                      onDeliveryPressed: _confirmDelivery,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
