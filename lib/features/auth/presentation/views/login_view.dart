import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/app_action_button.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/notifications/courier_push_service.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    _removeWhitespaceFromControllers();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await AuthSession.instance.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
        remember: _rememberMe,
      );
      await CourierPushService.instance.registerAuthenticatedDevice();
      if (!mounted) return;
      _goToDashboard();
    } on ApiException catch (error) {
      if (!mounted) return;
      CustomSnackBar.showError(context: context, title: error.message);
    } catch (_) {
      if (!mounted) return;
      CustomSnackBar.showError(
        context: context,
        title: 'تعذر الاتصال بالخادم. حاول مرة أخرى.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeWhitespaceFromControllers() {
    _removeWhitespace(_identifierController);
    _removeWhitespace(_passwordController);
  }

  void _removeWhitespace(TextEditingController controller) {
    final cleanText = controller.text.replaceAll(RegExp(r'\s+'), '');
    if (cleanText == controller.text) return;
    controller.value = TextEditingValue(
      text: cleanText,
      selection: TextSelection.collapsed(offset: cleanText.length),
    );
  }

  void _goToDashboard() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.dashboard,
      (route) => false,
    );
  }

  Future<void> _openTechnicalSupport() async {
    final uri = Uri.https('wa.me', '/201016487371');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      CustomSnackBar.showError(
        context: context,
        title: 'تعذر فتح واتساب على هذا الجهاز.',
      );
    }
  }

  String? _validateIdentifier(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'اكتب رقم الموبايل أو الإيميل';
    final looksLikeEmail = text.contains('@') && text.contains('.');
    final looksLikePhone = RegExp(r'^\+?\d{10,15}$').hasMatch(text);
    final looksLikeUsername = RegExp(r'^[\w.@+-]+$').hasMatch(text);
    if (!looksLikeEmail && !looksLikePhone && !looksLikeUsername) {
      return 'اكتب إيميل صحيح أو رقم موبايل صحيح';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'اكتب كلمة المرور';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1A1B20) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: surfaceColor,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: surfaceColor,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 500
                  ? 32.0
                  : 20.0;
              const bannerHeight = 250.0;
              const overlap = 22.0;
              final sheetMinHeight =
                  (constraints.maxHeight - (bannerHeight - overlap)).clamp(
                    300.0,
                    double.infinity,
                  );

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // 1. Top Banner area with 3D courier illustration
                    SizedBox(
                      height: bannerHeight,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              AppAssets.authCourierHeader,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              cacheHeight: 480,
                            ),
                          ),
                          // Soft ambient overlay for dark mode & contrast
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(
                                      alpha: isDark ? 0.35 : 0.05,
                                    ),
                                    Colors.transparent,
                                    Colors.black.withValues(
                                      alpha: isDark ? 0.40 : 0.08,
                                    ),
                                  ],
                                  stops: const [0.0, 0.45, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Curved bottom sheet with centered floating logo on the curve
                    Transform.translate(
                      offset: const Offset(0, -overlap),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          // Curved form container
                          Container(
                            width: double.infinity,
                            constraints: BoxConstraints(
                              minHeight: sheetMinHeight,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(22),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.35 : 0.07,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              48, // Room directly below floating logo badge
                              horizontalPadding,
                              24,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 430,
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'أهلاً يا كابتن',
                                        textAlign: TextAlign.start,
                                        style: theme.textTheme.headlineLarge
                                            ?.copyWith(
                                              fontSize: 20,
                                              height: 1.15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 20),
                                      _LoginTextField(
                                        controller: _identifierController,
                                        keyboardType: TextInputType.text,
                                        validator: _validateIdentifier,
                                        textInputAction: TextInputAction.next,
                                        labelText:
                                            'موبايل / إيميل / اسم مستخدم',
                                        prefixIcon: AppIcons.direct_right,
                                      ),
                                      _LoginTextField(
                                        controller: _passwordController,
                                        validator: _validatePassword,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _signIn(),
                                        labelText: 'كلمة المرور',
                                        prefixIcon: AppIcons.password_check,
                                        suffixIcon: _obscurePassword
                                            ? AppIcons.eye_slash
                                            : AppIcons.eye,
                                        suffixTooltip: _obscurePassword
                                            ? 'إظهار كلمة المرور'
                                            : 'إخفاء كلمة المرور',
                                        onSuffixIconPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                      ),
                                      _buildRememberAndSupportRow(
                                        theme,
                                        isDark,
                                      ),
                                      const SizedBox(height: 26),
                                      AppActionButton(
                                        label: 'تسجيل الدخول',
                                        isLoading: _isLoading,
                                        onPressed: _isLoading ? null : _signIn,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Centered floating logo badge positioned on the curve
                          Positioned(
                            top: -37,
                            child: Container(
                              width: 74,
                              height: 74,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D3B75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: surfaceColor,
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0D3B75,
                                    ).withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.asset(
                                  AppAssets.logo,
                                  fit: BoxFit.cover,
                                  cacheWidth: 160,
                                  cacheHeight: 160,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRememberAndSupportRow(ThemeData theme, bool isDark) {
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.black.withValues(alpha: 0.78);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _rememberMe = !_rememberMe;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: _LoginCheckbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'تذكرني',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: _openTechnicalSupport,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'الدعم الفني',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _LoginCheckbox extends StatelessWidget {
  const _LoginCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      onChanged: onChanged,
      checkColor: Colors.white,
      side: BorderSide(
        color: value ? AppColors.primary : AppColors.warning,
        width: 1.8,
      ),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }

        return AppColors.warning.withValues(alpha: 0.16);
      }),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.suffixIcon,
    this.suffixTooltip,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onSuffixIconPressed,
  });

  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final String? suffixTooltip;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onSuffixIconPressed;

  static final _noWhitespaceFormatter = FilteringTextInputFormatter.deny(
    RegExp(r'\s'),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? const Color(0xFF222326)
        : const Color(0xFFF5F6FA);
    final borderColor = isDark
        ? const Color(0xFF3A3B41)
        : const Color(0xFFE4E7F0);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.64)
        : Colors.black.withValues(alpha: 0.48);
    final textColor = isDark ? Colors.white : const Color(0xFF17181C);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: [_noWhitespaceFormatter],
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        cursorColor: theme.colorScheme.primary,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          labelStyle: TextStyle(
            color: iconColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(prefixIcon, size: 21, color: iconColor),
          suffixIcon: suffixIcon == null
              ? null
              : IconButton(
                  tooltip: suffixTooltip,
                  onPressed: onSuffixIconPressed,
                  icon: Icon(suffixIcon, size: 21, color: iconColor),
                ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.4,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 1.4),
          ),
        ),
      ),
    );
  }
}
