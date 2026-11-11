import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../customer_app/core/theme/app_theme.dart' as cust_colors;
import '../../customer_app/shared/widgets/glass_card.dart';
import '../../customer_app/shared/widgets/gradient_button.dart';
import '../../customer_app/shared/widgets/toast_service.dart';
import '../../customer_app/data/providers/app_providers.dart'
    hide authStateProvider;
import '../providers/auth_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/user_role.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Common state
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isOfficeLogin = false;
  bool _acceptedTerms = false;

  // Customer Login state
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+91';

  // Office Login state
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkEvictedStatus();
  }

  Future<void> _checkEvictedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kicked = prefs.getBool('user_account_deleted_kicked') ?? false;
      if (kicked) {
        await prefs.remove('user_account_deleted_kicked');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showUserNotFoundDialog(
            message:
                'Your account has been deleted or deactivated. You have been logged out.',
          );
        });
      }
    } catch (_) {}
  }

  void _showUserNotFoundDialog({String? message}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline,
                color: cust_colors.AppColors.danger, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'User Not Found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message ??
              'User not found. This account does not exist or has been deleted. Please contact your administrator.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cust_colors.AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCustomerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      ToastService.show(
        context,
        'Please accept the Terms & Conditions and Privacy Policy to proceed.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final phone = '$_selectedCountryCode${_phoneController.text.trim()}';
      final rawPhone = _phoneController.text.trim();

      // Check if customer is registered in the system
      const supabaseUrl = AppConfig.supabaseUrl;
      final isDemoMode = supabaseUrl.contains('your-project-ref');

      if (!isDemoMode) {
        final supabase = ref.read(supabaseClientProvider);
        // Search for the phone in both formats (with and without country code)
        final result = await supabase
            .from('customers')
            .select('id, phone')
            .or('phone.eq.$phone,phone.eq.$rawPhone,phone.ilike.%$rawPhone')
            .limit(1);

        if ((result as List).isEmpty) {
          throw Exception(
              'User not registered. Please contact your administrator to register your account.');
        }
      }

      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (mounted) {
        ToastService.show(context, 'OTP Sent successfully!',
            type: ToastType.success);
        context.push('/otp', extra: {'phone': phone});
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(context, e.toString().replaceAll('Exception: ', ''),
            type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleOfficeLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) {
        ToastService.show(context, 'Signed in successfully!',
            type: ToastType.success);

        // Invalidate authStateProvider so the router knows about the new session.
        ref.invalidate(authStateProvider);

        // Explicitly navigate immediately using resolved session role
        final prefs = await SharedPreferences.getInstance();
        final staffRole = prefs.getString('staff_session_role');
        if (staffRole != null && mounted) {
          final role = UserRole.fromString(staffRole);
          context.go(getRoleHome(role));
          return;
        }

        final current = ref.read(currentProfileProvider);
        if (current != null && mounted) {
          context.go(getRoleHome(current.primaryRole));
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String msg = e.message;
        try {
          if (msg.startsWith('{')) {
            final json = jsonDecode(msg);
            msg = json['error_description'] ??
                json['message'] ??
                json['msg'] ??
                msg;
          }
        } catch (_) {}
        if (msg.toLowerCase().contains('user not found') ||
            msg.toLowerCase().contains('invalid login credentials') ||
            msg.toLowerCase().contains('invalid_grant')) {
          _showUserNotFoundDialog();
        } else if (msg.toLowerCase().contains('deactivated')) {
          _showUserNotFoundDialog(
              message:
                  'Your account has been deactivated. Please contact your administrator.');
        } else {
          ToastService.show(context, msg, type: ToastType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '');
        try {
          if (msg.startsWith('{')) {
            final json = jsonDecode(msg);
            msg = json['error_description'] ??
                json['message'] ??
                json['msg'] ??
                msg;
          }
        } catch (_) {}
        if (msg.toLowerCase().contains('user not found') ||
            msg.toLowerCase().contains('invalid login credentials') ||
            msg.toLowerCase().contains('invalid_grant')) {
          _showUserNotFoundDialog();
        } else if (msg.toLowerCase().contains('deactivated')) {
          _showUserNotFoundDialog(
              message:
                  'Your account has been deactivated. Please contact your administrator.');
        } else {
          ToastService.show(
            context,
            msg,
            type: ToastType.error,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? cust_colors.AppColors.bgPrimary
        : cust_colors.AppColors.bgPrimaryLight;
    final glassCardBg = isDark
        ? cust_colors.AppColors.bgGlass
        : cust_colors.AppColors.bgGlassLight;
    final textCol = isDark
        ? cust_colors.AppColors.textPrimary
        : cust_colors.AppColors.textPrimaryLight;
    final subtitleCol = isDark
        ? cust_colors.AppColors.textSecondary
        : cust_colors.AppColors.textSecondaryLight;

    final isSmallScreen = size.height < 700;
    final headerHeight =
        isSmallScreen ? 180.0 : (size.height * 0.26).clamp(190.0, 240.0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // Top area: Brand header
            Container(
              height: headerHeight,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E1B4B),
                          Color(0xFF4C1D95),
                          Color(0xFF6D28D9),
                        ],
                      ),
                    ),
                  ),
                  // Radial glow top-right
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            cust_colors.AppColors.primary.withOpacity(0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Radial glow bottom-left
                  Positioned(
                    bottom: -20,
                    left: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF06B6D4).withOpacity(0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: isSmallScreen ? 62 : 72,
                            height: isSmallScreen ? 62 : 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.1),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.whatshot_rounded,
                                size: 38,
                                color: Color(0xFF00E5FF),
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 14),
                          Text(
                            'IZYHEAT',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 26 : 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Premium Heating & HVAC Solutions',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Form
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Form(
                        key: _formKey,
                        child: GlassCard(
                          padding: const EdgeInsets.all(24),
                          borderRadius: 24,
                          child: _isOfficeLogin
                              ? _buildOfficeLoginForm(
                                  isDark, textCol, subtitleCol, glassCardBg)
                              : _buildCustomerLoginForm(
                                  isDark, textCol, subtitleCol, glassCardBg),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _showTermsDialog(context),
                    child: Text(
                      'Terms & Conditions • Privacy Policy',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleCol,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerLoginForm(
    bool isDark,
    Color textCol,
    Color subtitleCol,
    Color glassCardBg,
  ) {
    final borderCol = isDark
        ? cust_colors.AppColors.borderColor
        : cust_colors.AppColors.borderColorLight;
    final inputBg =
        isDark ? cust_colors.AppColors.bgPrimary : Colors.grey.shade50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Login',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textCol,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your registered mobile number to request or check services.',
          style: TextStyle(
            color: subtitleCol,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country Code picker
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              height: 56,
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  dropdownColor:
                      isDark ? cust_colors.AppColors.bgSecondary : Colors.white,
                  style: TextStyle(
                    color: textCol,
                    fontWeight: FontWeight.bold,
                  ),
                  items: const [
                    DropdownMenuItem(value: '+91', child: Text('+91 (IN)')),
                    DropdownMenuItem(value: '+44', child: Text('+44 (UK)')),
                    DropdownMenuItem(value: '+1', child: Text('+1 (US)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCountryCode = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Phone Number Input
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  color: textCol,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter Phone No.',
                  hintStyle: TextStyle(color: subtitleCol.withOpacity(0.6)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  fillColor: inputBg,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? cust_colors.AppColors.accent
                            : cust_colors.AppColors.primary,
                        width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: cust_colors.AppColors.danger),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: cust_colors.AppColors.danger, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (val.trim().length < 8) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _handleCustomerLogin(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Terms & Conditions acceptance with Checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _acceptedTerms,
                onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                activeColor: const Color(0xFF7C3AED),
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12.5,
                      color: subtitleCol,
                      fontFamily: 'Inter',
                      height: 1.35,
                    ),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => _showTermsDialog(context),
                          child: const Text(
                            'Terms & Conditions',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF7C3AED),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => _showTermsDialog(context),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF7C3AED),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: 'Send OTP',
          isLoading: _isLoading,
          onTap: _handleCustomerLogin,
          gradientColors: const [
            Color(0xFF7C3AED),
            Color(0xFF06B6D4),
          ],
          icon: const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _isOfficeLogin = true;
                _formKey.currentState?.reset();
              });
            },
            child: const Text(
              'Office Staff? Login here',
              style: TextStyle(
                color: Color(0xFF7C3AED),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfficeLoginForm(
    bool isDark,
    Color textCol,
    Color subtitleCol,
    Color glassCardBg,
  ) {
    final borderCol = isDark
        ? cust_colors.AppColors.borderColor
        : cust_colors.AppColors.borderColorLight;
    final inputBg =
        isDark ? cust_colors.AppColors.bgPrimary : Colors.grey.shade50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Office Login',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textCol,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in with your corporate email credentials.',
          style: TextStyle(
            color: subtitleCol,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        // Email field
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: TextStyle(color: textCol),
          decoration: InputDecoration(
            labelText: 'Email Address',
            labelStyle: TextStyle(color: subtitleCol),
            hintText: 'Enter Email ID',
            hintStyle: TextStyle(color: subtitleCol.withOpacity(0.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            fillColor: inputBg,
            filled: true,
            prefixIcon: Icon(Icons.email_outlined, color: subtitleCol),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark
                      ? cust_colors.AppColors.accent
                      : cust_colors.AppColors.primary,
                  width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cust_colors.AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: cust_colors.AppColors.danger, width: 1.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email or username is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Password field
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: TextStyle(color: textCol),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: TextStyle(color: subtitleCol),
            hintText: '••••••••',
            hintStyle: TextStyle(color: subtitleCol.withOpacity(0.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            fillColor: inputBg,
            filled: true,
            prefixIcon: Icon(Icons.lock_outline, color: subtitleCol),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: subtitleCol,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark
                      ? cust_colors.AppColors.accent
                      : cust_colors.AppColors.primary,
                  width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cust_colors.AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: cust_colors.AppColors.danger, width: 1.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            return null;
          },
          onFieldSubmitted: (_) => _handleOfficeLogin(),
        ),
        const SizedBox(height: 16),
        // Terms & Conditions mention (No checkbox for office login)
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                color: subtitleCol,
                fontFamily: 'Inter',
                height: 1.35,
              ),
              children: [
                const TextSpan(text: 'By signing in, you agree to our '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => _showTermsDialog(context),
                    child: const Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' & '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => _showTermsDialog(context),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        GradientButton(
          label: 'Sign In',
          isLoading: _isLoading,
          onTap: _handleOfficeLogin,
          gradientColors: const [
            Color(0xFF7C3AED),
            Color(0xFF06B6D4),
          ],
          icon: const Icon(Icons.login_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _isOfficeLogin = false;
                _formKey.currentState?.reset();
              });
            },
            child: const Text(
              'Customer? Login here',
              style: TextStyle(
                color: Color(0xFF7C3AED),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.gavel_rounded, color: Color(0xFF7C3AED), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Terms & Conditions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Standard Business Application Terms of Service & Privacy Policy',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                _buildTermsSection(
                  title: '1. Acceptance of Terms',
                  content:
                      'By accessing and using the IZYHEAT application, you agree to be bound by these Terms of Service, applicable commercial agreements, and privacy standards. If you do not agree to these terms, you must not log in or use the application.',
                ),
                _buildTermsSection(
                  title: '2. User Accounts & Verification',
                  content:
                      'Customer access is authenticated via One-Time Password (OTP) dispatched to your registered mobile number. Corporate and office staff accounts are authenticated via corporate credentials and role-based permissions. You agree to safeguard your credentials and prevent unauthorized access.',
                ),
                _buildTermsSection(
                  title: '3. Scope of Service & Commercial Proposals',
                  content:
                      'All generated quotations, price estimates, delivery challans, and service tickets are subject to inventory verification, formal review, and written confirmation. Quoted rates, taxes, and delivery timelines are governed by final authorized order documentation.',
                ),
                _buildTermsSection(
                  title: '4. Data Privacy & Confidentiality',
                  content:
                      'Customer details, site survey notes, financial estimates, and transaction logs are stored securely and used solely to fulfill orders, schedule site maintenance, and process billing. Your confidential information is never shared or sold to third-party entities.',
                ),
                _buildTermsSection(
                  title: '5. Authorized Usage & Security',
                  content:
                      'Users agree not to disrupt app services, attempt unauthorized privilege escalation across sales pipelines or administrative modules, or tamper with digital records. Violations may result in immediate access revocation.',
                ),
                _buildTermsSection(
                  title: '6. Support & Contact',
                  content:
                      'For service requests, warranty claims, or billing queries, please contact your designated IZYHEAT sales or customer support representative.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1B4B)),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
