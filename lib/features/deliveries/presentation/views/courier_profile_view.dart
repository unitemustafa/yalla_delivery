import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/network_image_or_placeholder.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../../../core/theme/app_theme_controller.dart';
import '../../domain/courier_account.dart';
import '../controllers/courier_profile_controller.dart';

part 'courier_profile_content_part.dart';
part 'courier_profile_settings_part.dart';

class CourierProfileView extends StatefulWidget {
  const CourierProfileView({
    super.key,
    required this.activeOrders,
    required this.deliveredOrders,
    required this.onActiveOrdersTap,
    required this.onDeliveredSummaryTap,
    required this.onLogout,
    this.controller,
  });

  final int activeOrders;
  final int deliveredOrders;
  final VoidCallback onActiveOrdersTap;
  final VoidCallback onDeliveredSummaryTap;
  final VoidCallback onLogout;
  final CourierProfileController? controller;

  @override
  State<CourierProfileView> createState() => _CourierProfileViewState();
}

class _CourierProfileViewState extends State<CourierProfileView> {
  late CourierProfileController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? CourierProfileController();
    _ownsController = widget.controller == null;
    _controller.loadAccountIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CourierProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    if (_ownsController) _controller.dispose();
    _controller = widget.controller ?? CourierProfileController();
    _ownsController = widget.controller == null;
    _controller.loadAccountIfNeeded();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightSurface;

    return ColoredBox(
      color: backgroundColor,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _controller.refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth >= 760
                    ? 680.0
                    : constraints.maxWidth;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: _ProfileBody(
                          activeOrders: widget.activeOrders,
                          deliveredOrders: widget.deliveredOrders,
                          onActiveOrdersTap: widget.onActiveOrdersTap,
                          onDeliveredSummaryTap: widget.onDeliveredSummaryTap,
                          onLogout: widget.onLogout,
                          controller: _controller,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.activeOrders,
    required this.deliveredOrders,
    required this.onActiveOrdersTap,
    required this.onDeliveredSummaryTap,
    required this.onLogout,
    required this.controller,
    required this.isDark,
  });

  final int activeOrders;
  final int deliveredOrders;
  final VoidCallback onActiveOrdersTap;
  final VoidCallback onDeliveredSummaryTap;
  final VoidCallback onLogout;
  final CourierProfileController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final account = controller.account;
    final errorMessage = controller.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTopBar(
          title: 'حساب المندوب',
          subtitle: 'بيانات التشغيل والحساب',
        ),
        const SizedBox(height: 18),
        if (controller.isLoading && !controller.hasLoaded)
          const _ProfileLoading()
        else if (errorMessage != null && account == null)
          _ProfileError(message: errorMessage, onRetry: controller.loadAccount)
        else ...[
          _CourierHero(account: account),
          if (account?.profile == null) ...[
            const SizedBox(height: 12),
            const _IncompleteProfileNotice(),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CourierStat(
                  icon: AppIcons.receipt_text,
                  value: '$activeOrders',
                  label: 'طلبات نشطة',
                  color: AppColors.primary,
                  onTap: onActiveOrdersTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CourierStat(
                  icon: AppIcons.tick_circle,
                  value: '$deliveredOrders',
                  label: 'طلبات مسلّمة',
                  color: AppColors.success,
                  onTap: onDeliveredSummaryTap,
                ),
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            _InlineProfileError(
              message: errorMessage,
              onRetry: controller.loadAccount,
            ),
          ],
          const SizedBox(height: 22),
          _SettingsSection(
            title: 'بيانات تشغيل المندوب',
            isDark: isDark,
            children: [
              _SettingsInfoTile(
                icon: AppIcons.location,
                title: 'مدينة الخدمة',
                subtitle:
                    account?.profile?.serviceCityLabel ??
                    'مدينة الخدمة غير محددة',
                accentColor: AppColors.info,
              ),
              _SettingsDivider(isDark: isDark),
              _SettingsInfoTile(
                icon: AppIcons.tick_circle,
                title: 'حالة استقبال الطلبات',
                subtitle:
                    account?.profile?.availabilityLabel ?? 'الحالة غير معروفة',
                accentColor: _availabilityColor(account?.profile?.isAvailable),
              ),
              _SettingsDivider(isDark: isDark),
              _SettingsInfoTile(
                icon: AppIcons.truck_fast,
                title: 'نوع المركبة',
                subtitle: account?.profile?.vehicleTypeLabel ?? 'غير محدد',
                accentColor: AppColors.primary,
              ),
              _SettingsDivider(isDark: isDark),
              _SettingsInfoTile(
                icon: AppIcons.info_circle,
                title: 'رقم اللوحة',
                subtitle: account?.profile?.plateNumberLabel ?? 'غير محدد',
                accentColor: AppColors.warning,
              ),
              _SettingsDivider(isDark: isDark),
              _SettingsInfoTile(
                icon: AppIcons.receipt_text,
                title: 'الحد الأقصى للطلبات النشطة',
                subtitle: account?.profile?.maxActiveOrdersLabel ?? 'غير محدد',
                accentColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'إعدادات التطبيق',
            isDark: isDark,
            children: const [_ThemeModeTile()],
          ),
          const SizedBox(height: 18),
          _LogoutButton(onPressed: () => _showLogoutDialog(context, onLogout)),
        ],
      ],
    );
  }

  Color _availabilityColor(bool? isAvailable) {
    return switch (isAvailable) {
      true => AppColors.success,
      false => AppColors.error,
      null => AppColors.warning,
    };
  }

  void _showLogoutDialog(BuildContext context, VoidCallback onLogout) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('تسجيل الخروج', textAlign: TextAlign.center),
          content: const Text(
            'متأكد إنك عايز تسجل خروج؟',
            textAlign: TextAlign.center,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      onLogout();
                    },
                    child: const Text('تأكيد'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
