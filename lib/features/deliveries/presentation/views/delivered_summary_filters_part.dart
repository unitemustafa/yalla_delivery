part of 'delivered_summary_view.dart';

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedFilter,
    required this.customRange,
    required this.onChanged,
  });

  final DeliveredSummaryFilter selectedFilter;
  final DateTimeRange? customRange;
  final ValueChanged<DeliveredSummaryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in DeliveredSummaryFilter.values) ...[
            ChoiceChip(
              label: Text(_labelFor(filter)),
              selected: selectedFilter == filter,
              onSelected: (_) => onChanged(filter),
              showCheckmark: false,
              selectedColor: AppColors.primary.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                color: selectedFilter == filter
                    ? AppColors.primary
                    : isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w900,
              ),
              side: BorderSide(
                color: selectedFilter == filter
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _labelFor(DeliveredSummaryFilter filter) {
    if (filter != DeliveredSummaryFilter.custom || customRange == null) {
      return filter.label;
    }

    return _formatRange(
      customRange!.start,
      customRange!.end.subtract(const Duration(days: 1)),
    );
  }

  String _formatDay(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}';
  }

  String _formatRange(DateTime start, DateTime end) {
    return '\u2066${_formatDay(start)} - ${_formatDay(end)}\u2069';
  }
}

const double _sheetControlRadius = 18;
const double _sheetActionHeight = 54;
const double _wheelItemExtent = 44;
const double _wheelPickerHeight = 220;

class _CustomRangeSheet extends StatefulWidget {
  const _CustomRangeSheet({
    required this.firstDate,
    required this.lastDate,
    required this.initialRange,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange initialRange;

  @override
  State<_CustomRangeSheet> createState() => _CustomRangeSheetState();
}

class _CustomRangeSheetState extends State<_CustomRangeSheet> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = _dateOnly(widget.initialRange.start);
    _endDate = _dateOnly(
      widget.initialRange.end.subtract(const Duration(days: 1)),
    );
  }

  int get _selectedDays => _endDate.difference(_startDate).inDays + 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkSurface : Colors.white;
    final outlineColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: outlineColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.10),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedColor.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(44, 44),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_sheetControlRadius),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateSelectionCard(
                      label: 'من',
                      value: _formatDate(_startDate),
                      onTap: () => _pickDate(isStart: true),
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _DateSelectionCard(
                      label: 'إلى',
                      value: _formatDate(_endDate),
                      onTap: () => _pickDate(isStart: false),
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SelectedDaysSummary(days: _selectedDays),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetToDefault,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(_sheetActionHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _sheetControlRadius,
                          ),
                        ),
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Text('إعادة الضبط'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _applySelection,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(_sheetActionHeight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _sheetControlRadius,
                          ),
                        ),
                      ),
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final currentDate = isStart ? _startDate : _endDate;
    final pickedDate = await showDialog<DateTime>(
      context: context,
      builder: (_) => _WheelDatePickerDialog(
        initialDate: currentDate,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
      ),
    );

    if (pickedDate == null) return;

    setState(() {
      final normalizedDate = _dateOnly(pickedDate);

      if (isStart) {
        _startDate = normalizedDate;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = normalizedDate;
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate;
        }
      }
    });
  }

  void _resetToDefault() {
    _setRange(
      widget.lastDate.subtract(const Duration(days: 6)),
      widget.lastDate,
    );
  }

  void _setRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = _clampDate(_dateOnly(start));
      _endDate = _clampDate(_dateOnly(end));

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  void _applySelection() {
    Navigator.pop(
      context,
      DateTimeRange(
        start: _startDate,
        end: _endDate.add(const Duration(days: 1)),
      ),
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _clampDate(DateTime value) {
    final firstDate = _dateOnly(widget.firstDate);
    final lastDate = _dateOnly(widget.lastDate);

    if (value.isBefore(firstDate)) return firstDate;
    if (value.isAfter(lastDate)) return lastDate;
    return value;
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }
}

class _DateSelectionCard extends StatelessWidget {
  const _DateSelectionCard({
    required this.label,
    required this.value,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardOutlineColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.10);
    final cardColor = isDark ? AppColors.darkCardColor : AppColors.lightSurface;
    final labelStyle =
        (compact ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)
            ?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 12.0 : null,
            );
    final valueStyle =
        (compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 13.0 : null,
            );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_sheetControlRadius),
      child: Ink(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(_sheetControlRadius),
          border: Border.all(color: cardOutlineColor),
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 42 : 48,
              height: compact ? 34 : 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.18 : 0.09,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            SizedBox(width: compact ? 6 : 8),
            Expanded(
              child: compact
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                        style: valueStyle,
                      ),
                    )
                  : Text(
                      value,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle,
                    ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.18 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  AppIcons.calendar,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedDaysSummary extends StatelessWidget {
  const _SelectedDaysSummary({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(_sheetControlRadius),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.24 : 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.calendar, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'عدد الأيام المحددة',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$days يوم',
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelColumnLabel extends StatelessWidget {
  const _WheelColumnLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: mutedColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WheelDivider extends StatelessWidget {
  const _WheelDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: color);
  }
}

class _WheelSelectionFrame extends StatelessWidget {
  const _WheelSelectionFrame({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: _wheelItemExtent + 8,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
        ),
      ),
    );
  }
}
