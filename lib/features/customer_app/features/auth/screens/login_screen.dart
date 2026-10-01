import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/shared/widgets/gradient_button.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';
import 'package:salesapp/core/services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _selectedCountryCode = '+91';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp([OtpChannel channel = OtpChannel.sms]) async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final phone = '$_selectedCountryCode${_phoneController.text.trim()}';
      await ref.read(authRepositoryProvider).sendOtp(phone, channel);
      if (mounted) {
        final channelName = channel == OtpChannel.sms ? 'SMS' : 'WhatsApp';
        ToastService.show(context, 'OTP sent via $channelName!', type: ToastType.success);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 66,
                          height: 66,
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
                              size: 34,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'IZYHEAT',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                fontSize: 28,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Premium Heating & HVAC Solutions',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  Form(
                    key: _formKey,
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Login',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your registered mobile number to request or check services.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              // Country Code picker
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.bgPrimary,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCountryCode,
                                    dropdownColor: AppColors.bgSecondary,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
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
                              const SizedBox(width: 10),
                              // Phone Number Input
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '99999 99999',
                                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    fillColor: AppColors.bgPrimary,
                                    filled: true,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppColors.borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppColors.danger),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
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
                                  onFieldSubmitted: (_) => _sendOtp(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          GradientButton(
                            label: 'Get OTP via SMS',
                            isLoading: _isLoading,
                            onTap: () => _sendOtp(OtpChannel.sms),
                            gradientColors: const [
                              Color(0xFF7C3AED),
                              Color(0xFF06B6D4),
                            ],
                            icon: const Icon(Icons.sms_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : () => _sendOtp(OtpChannel.whatsapp),
                              icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 20),
                              label: const Text(
                                'Get OTP via WhatsApp',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF25D366),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
