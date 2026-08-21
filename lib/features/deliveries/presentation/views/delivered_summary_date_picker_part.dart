part of 'delivered_summary_view.dart';

class _WheelDatePickerDialog extends StatefulWidget {
  const _WheelDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_WheelDatePickerDialog> createState() => _WheelDatePickerDialogState();
}

class _WheelDatePickerDialogState extends State<_WheelDatePickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  DateTime get _selectedDate =>
      DateTime(_selectedYear, _selectedMonth, _selectedDay);

  List<int> get _years => [
    for (int year = widget.firstDate.year; year <= widget.lastDate.year; year++)
      year,
  ];

  List<int> get _months {
    final startMonth = _selectedYear == widget.firstDate.year
        ? widget.firstDate.month
        : 1;
    final endMonth = _selectedYear == widget.lastDate.year
        ? widget.lastDate.month
        : 12;

    return [for (int month = startMonth; month <= endMonth; month++) month];
  }

  List<int> get _days {
    final monthDays = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final startDay =
        _selectedYear == widget.firstDate.year &&
            _selectedMonth == widget.firstDate.month
        ? widget.firstDate.day
        : 1;
    final endDay =
        _selectedYear == widget.lastDate.year &&
            _selectedMonth == widget.lastDate.month
        ? widget.lastDate.day
        : monthDays;

    return [for (int day = startDay; day <= endDay; day++) day];
  }

  @override
  void initState() {
    super.initState();
    final initialDate = _normalize(widget.initialDate);
    _selectedYear = initialDate.year;
    _selectedMonth = initialDate.month;
    _selectedDay = initialDate.day;
    _dayController = FixedExtentScrollController(
      initialItem: _days.indexOf(_selectedDay),
    );
    _monthController = FixedExtentScrollController(
      initialItem: _months.indexOf(_selectedMonth),
    );
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_selectedYear),
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkSurface : Colors.white;
    final outlineColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : AppColors.lightSurface;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: outlineColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(
                          alpha: isDark ? 0.22 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        AppIcons.calendar,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 58),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'اختيار التاريخ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatPreviewDate(_selectedDate),
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        fixedSize: const Size(44, 44),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: _wheelPickerHeight,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: outlineColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        const Expanded(child: _WheelColumnLabel('اليوم')),
                        _WheelDivider(color: outlineColor),
                        const Expanded(child: _WheelColumnLabel('الشهر')),
                        _WheelDivider(color: outlineColor),
                        const Expanded(child: _WheelColumnLabel('السنة')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _WheelPickerColumn(
                                values: _days,
                                controller: _dayController,
                                onSelectedItemChanged: _updateDay,
                                formatter: _formatTwoDigits,
                              ),
                            ),
                            _WheelDivider(color: outlineColor),
                            Expanded(
                              child: _WheelPickerColumn(
                                values: _months,
                                controller: _monthController,
                                onSelectedItemChanged: _updateMonth,
                                formatter: _formatTwoDigits,
                              ),
                            ),
                            _WheelDivider(color: outlineColor),
                            Expanded(
                              child: _WheelPickerColumn(
                                values: _years,
                                controller: _yearController,
                                onSelectedItemChanged: _updateYear,
                                formatter: (value) => '$value',
                              ),
                            ),
                          ],
                        ),
                        _WheelSelectionFrame(isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(_sheetActionHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _sheetControlRadius,
                        ),
                      ),
                      side: BorderSide(color: outlineColor),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selectedDate),
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
                    child: const Text('تأكيد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateYear(int index) {
    setState(() {
      _selectedYear = _years[index];
      _selectedMonth = _clampValue(_selectedMonth, _months);
      _selectedDay = _clampValue(_selectedDay, _days);
    });
    _syncController(_monthController, _months.indexOf(_selectedMonth));
    _syncController(_dayController, _days.indexOf(_selectedDay));
  }

  void _updateMonth(int index) {
    setState(() {
      _selectedMonth = _months[index];
      _selectedDay = _clampValue(_selectedDay, _days);
    });
    _syncController(_dayController, _days.indexOf(_selectedDay));
  }

  void _updateDay(int index) {
    setState(() => _selectedDay = _days[index]);
  }

  int _clampValue(int value, List<int> values) {
    if (value < values.first) return values.first;
    if (value > values.last) return values.last;
    return value;
  }

  void _syncController(FixedExtentScrollController controller, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients || index < 0) return;
      controller.jumpToItem(index);
    });
  }

  DateTime _normalize(DateTime value) {
    final dateOnly = DateTime(value.year, value.month, value.day);
    final firstDate = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final lastDate = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );

    if (dateOnly.isBefore(firstDate)) return firstDate;
    if (dateOnly.isAfter(lastDate)) return lastDate;
    return dateOnly;
  }

  String _formatPreviewDate(DateTime value) {
    return '${_formatTwoDigits(value.day)}/${_formatTwoDigits(value.month)}/${value.year}';
  }

  String _formatTwoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class _WheelPickerColumn extends StatelessWidget {
  const _WheelPickerColumn({
    required this.values,
    required this.controller,
    required this.onSelectedItemChanged,
    required this.formatter,
  });

  final List<int> values;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onSelectedItemChanged;
  final String Function(int value) formatter;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _wheelItemExtent,
      diameterRatio: 1.8,
      perspective: 0.002,
      squeeze: 0.96,
      useMagnifier: true,
      magnification: 1.08,
      overAndUnderCenterOpacity: 0.42,
      physics: const FixedExtentScrollPhysics(parent: BouncingScrollPhysics()),
      onSelectedItemChanged: onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: values.length,
        builder: (context, index) {
          return Center(
            child: Text(
              formatter(values[index]),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          );
        },
      ),
    );
  }
}
