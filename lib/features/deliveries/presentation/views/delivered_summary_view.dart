import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/formatters/app_currency.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../domain/courier_order.dart';
import '../widgets/order_card.dart';
import 'order_details_view.dart';

part 'delivered_summary_filters_part.dart';
part 'delivered_summary_date_picker_part.dart';
part 'delivered_summary_content_part.dart';

enum DeliveredSummaryFilter { today, yesterday, week, month, custom }

extension DeliveredSummaryFilterLabel on DeliveredSummaryFilter {
  String get label {
    return switch (this) {
      DeliveredSummaryFilter.today => 'انهارده',
      DeliveredSummaryFilter.yesterday => 'امبارح',
      DeliveredSummaryFilter.week => 'الأسبوع ده',
      DeliveredSummaryFilter.month => 'الشهر ده',
      DeliveredSummaryFilter.custom => 'مخصص',
    };
  }
}

class DeliveredSummaryView extends StatefulWidget {
  const DeliveredSummaryView({super.key, required this.orders});

  final List<CourierOrder> orders;

  @override
  State<DeliveredSummaryView> createState() => _DeliveredSummaryViewState();
}

class _DeliveredSummaryViewState extends State<DeliveredSummaryView> {
  DeliveredSummaryFilter _selectedFilter = DeliveredSummaryFilter.today;
  DateTimeRange? _customRange;

  List<CourierOrder> get _filteredOrders {
    final range = _activeRange;
    return widget.orders.where((order) {
      final deliveredAt = order.deliveredAt;
      if (deliveredAt == null) return false;
      return !deliveredAt.isBefore(range.start) &&
          deliveredAt.isBefore(range.end);
    }).toList();
  }

  DateTimeRange get _activeRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (_selectedFilter) {
      DeliveredSummaryFilter.today => DateTimeRange(
        start: today,
        end: today.add(const Duration(days: 1)),
      ),
      DeliveredSummaryFilter.yesterday => DateTimeRange(
        start: today.subtract(const Duration(days: 1)),
        end: today,
      ),
      DeliveredSummaryFilter.week => DateTimeRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today.add(const Duration(days: 1)),
      ),
      DeliveredSummaryFilter.month => DateTimeRange(
        start: DateTime(now.year, now.month),
        end: today.add(const Duration(days: 1)),
      ),
      DeliveredSummaryFilter.custom =>
        _customRange ??
            DateTimeRange(
              start: today,
              end: today.add(const Duration(days: 1)),
            ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;
    final totalValue = orders.fold<double>(
      0,
      (total, order) => total + order.total,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: orders.isEmpty ? 4 : orders.length + 3,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const PageTopBar(
                title: 'إجمالي التسليم',
                subtitle: 'ملخص الطلبات المسلّمة حسب الفترة',
                showBackButton: true,
              );
            }

            if (index == 1) {
              return _FilterBar(
                selectedFilter: _selectedFilter,
                customRange: _customRange,
                onChanged: _changeFilter,
              );
            }

            if (index == 2) {
              return _SummaryTotals(count: orders.length, total: totalValue);
            }

            if (orders.isEmpty) {
              return const _EmptySummaryState();
            }

            final order = orders[index - 3];
            return OrderCard(
              order: order,
              showDeliveredMeta: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => OrderDetailsView(order: order),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _changeFilter(DeliveredSummaryFilter filter) async {
    if (filter == DeliveredSummaryFilter.custom) {
      final pickedRange = await _pickCustomRange();

      if (pickedRange == null) return;
      setState(() {
        _selectedFilter = filter;
        _customRange = pickedRange;
      });
      return;
    }

    setState(() => _selectedFilter = filter);
  }

  Future<DateTimeRange?> _pickCustomRange() {
    final today = _dateOnly(DateTime.now());

    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomRangeSheet(
        firstDate: today.subtract(const Duration(days: 365)),
        lastDate: today,
        initialRange:
            _customRange ??
            DateTimeRange(
              start: today.subtract(const Duration(days: 6)),
              end: today.add(const Duration(days: 1)),
            ),
      ),
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
