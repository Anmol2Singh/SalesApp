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
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp([OtpChannel channel = OtpChannel.sms]) async {
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
                          const SizedBox(height: 16),
                          // Terms acceptance with Checkbox
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
                                        color: AppColors.textSecondary,
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
                                                color: Color(0xFF00E5FF),
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
                                                color: Color(0xFF00E5FF),
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
                  GestureDetector(
                    onTap: () => _showTermsDialog(context),
                    child: Text(
                      'Terms & Conditions • Privacy Policy',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                      textAlign: TextAlign.center,
                    ),
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

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.gavel_rounded, color: Color(0xFF00E5FF), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Terms & Conditions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
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
                  'Standard Customer Application Terms of Service & Privacy Policy',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                _buildTermsSection(
                  title: '1. Acceptance of Terms',
                  content:
                      'By accessing and using the IZYHEAT customer portal, you agree to these Terms and Conditions and our Privacy Policy. If you do not agree, you cannot proceed with login.',
                ),
                _buildTermsSection(
                  title: '2. Phone & OTP Verification',
                  content:
                      'Access requires authentication via a One-Time Password (OTP) dispatched to your registered phone number. You are responsible for safeguarding your verification credentials.',
                ),
                _buildTermsSection(
                  title: '3. Service Requests & Warranty',
                  content:
                      'Service inquiries, equipment tickets, and warranty status tracked in this app are subject to terms outlined in your formal purchase agreement and technician inspection.',
                ),
                _buildTermsSection(
                  title: '4. Privacy & Data Handling',
                  content:
                      'Your personal details and site addresses are utilized solely to coordinate installations, dispatch field engineers, and provide product support. Data is kept strictly confidential.',
                ),
                _buildTermsSection(
                  title: '5. Support & Assistance',
                  content:
                      'For immediate support with heating and solar systems, please contact our helpline or submit a service request through the portal.',
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
