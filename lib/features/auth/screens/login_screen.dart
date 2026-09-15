import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../customer_app/core/theme/app_theme.dart' as cust_colors;
import '../../customer_app/shared/widgets/glass_card.dart';
import '../../customer_app/shared/widgets/gradient_button.dart';
import '../../customer_app/shared/widgets/toast_service.dart';
import '../../customer_app/data/providers/app_providers.dart' hide authStateProvider;
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

  // Customer Login state
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+91';

  // Office Login state
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCustomerLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final phone = '$_selectedCountryCode${_phoneController.text.trim()}';
      final rawPhone = _phoneController.text.trim();

      // Check if customer is registered in the system
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
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
          throw Exception('User not registered. Please contact your administrator to register your account.');
        }
      }

      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (mounted) {
        ToastService.show(context, 'OTP Sent successfully!', type: ToastType.success);
        context.push('/otp', extra: {'phone': phone});
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(context, e.toString().replaceAll('Exception: ', ''), type: ToastType.error);
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
        ToastService.show(context, 'Signed in successfully!', type: ToastType.success);
        
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
            msg = json['error_description'] ?? json['message'] ?? json['msg'] ?? msg;
          }
        } catch (_) {}
        ToastService.show(context, msg, type: ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '');
        try {
          if (msg.startsWith('{')) {
            final json = jsonDecode(msg);
            msg = json['error_description'] ?? json['message'] ?? json['msg'] ?? msg;
          }
        } catch (_) {}
        ToastService.show(
          context,
          msg,
          type: ToastType.error,
        );
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
    final scaffoldBg = isDark ? cust_colors.AppColors.bgPrimary : cust_colors.AppColors.bgPrimaryLight;
    final glassCardBg = isDark ? cust_colors.AppColors.bgGlass : cust_colors.AppColors.bgGlassLight;
    final textCol = isDark ? cust_colors.AppColors.textPrimary : cust_colors.AppColors.textPrimaryLight;
    final subtitleCol = isDark ? cust_colors.AppColors.textSecondary : cust_colors.AppColors.textSecondaryLight;

    final isSmallScreen = size.height < 700;
    final headerHeight = isSmallScreen ? 210.0 : (size.height * 0.32).clamp(220.0, 290.0);

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
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.whatshot_rounded,
                              size: isSmallScreen ? 42 : 52,
                              color: cust_colors.AppColors.accent,
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
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
                            ? _buildOfficeLoginForm(isDark, textCol, subtitleCol, glassCardBg) 
                            : _buildCustomerLoginForm(isDark, textCol, subtitleCol, glassCardBg),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleCol,
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
    final borderCol = isDark ? cust_colors.AppColors.borderColor : cust_colors.AppColors.borderColorLight;
    final inputBg = isDark ? cust_colors.AppColors.bgPrimary : Colors.grey.shade50;

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
                  dropdownColor: isDark ? cust_colors.AppColors.bgSecondary : Colors.white,
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
                  hintText: '99999 99999',
                  hintStyle: TextStyle(color: subtitleCol.withOpacity(0.6)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  fillColor: inputBg,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? cust_colors.AppColors.accent : cust_colors.AppColors.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: cust_colors.AppColors.danger),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: cust_colors.AppColors.danger, width: 1.5),
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
        const SizedBox(height: 24),
        GradientButton(
          label: 'Send OTP',
          isLoading: _isLoading,
          onTap: _handleCustomerLogin,
          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
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
            child: Text(
              'Office Staff? Login here',
              style: TextStyle(
                color: isDark ? cust_colors.AppColors.accent : cust_colors.AppColors.primary,
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
    final borderCol = isDark ? cust_colors.AppColors.borderColor : cust_colors.AppColors.borderColorLight;
    final inputBg = isDark ? cust_colors.AppColors.bgPrimary : Colors.grey.shade50;

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
            hintText: 'admin@insiya.com or admin@izyheat.com',
            hintStyle: TextStyle(color: subtitleCol.withOpacity(0.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            fillColor: inputBg,
            filled: true,
            prefixIcon: Icon(Icons.email_outlined, color: subtitleCol),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? cust_colors.AppColors.accent : cust_colors.AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cust_colors.AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cust_colors.AppColors.danger, width: 1.5),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            fillColor: inputBg,
            filled: true,
            prefixIcon: Icon(Icons.lock_outline, color: subtitleCol),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: subtitleCol,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? cust_colors.AppColors.accent : cust_colors.AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cust_colors.AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cust_colors.AppColors.danger, width: 1.5),
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
        const SizedBox(height: 12),
        // Remember me
        Row(
          children: [
            Transform.scale(
              scale: 0.9,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (val) => setState(() => _rememberMe = val ?? false),
                activeColor: cust_colors.AppColors.primary,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              'Remember me',
              style: TextStyle(
                fontSize: 14,
                color: subtitleCol,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: 'Sign In',
          isLoading: _isLoading,
          onTap: _handleOfficeLogin,
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
            child: Text(
              'Customer? Login here',
              style: TextStyle(
                color: isDark ? cust_colors.AppColors.accent : cust_colors.AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
