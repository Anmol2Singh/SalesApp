// lib/features/customer_app/features/auth/screens/otp_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salesapp/core/services/auth_service.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/shared/widgets/otp_input_row.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';

class OTPScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OTPScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen> {
  // 90-second resend countdown as required
  static const int _initialCountdown = 90;
  int _countdown = _initialCountdown;
  Timer? _timer;
  bool _isLoading = false;
  bool _hasError = false;

  // Brute force lockout timer
  Timer? _lockoutTimer;
  int _remainingLockout = 0;

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
    _startTimer();
  }

  void _checkLockoutStatus() {
    if (AuthService().isLocked) {
      _remainingLockout = AuthService().remainingLockoutSeconds;
      _startLockoutCountdown();
    }
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingLockout > 0) {
        setState(() => _remainingLockout--);
      } else {
        timer.cancel();
        setState(() => _remainingLockout = 0);
      }
    });
  }

  void _startTimer() {
    _countdown = _initialCountdown;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyOtp(String code) async {
    if (_remainingLockout > 0) {
      ToastService.show(
        context,
        'Account locked. Try again in ${(_remainingLockout / 60).ceil()} minute(s).',
        type: ToastType.error,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final success = await ref.read(authRepositoryProvider).verifyOtp(code);
      if (success && mounted) {
        ref.invalidate(productsProvider);
        ref.invalidate(serviceRequestsProvider);
        ref.invalidate(userProfileProvider);
        ToastService.show(context, 'Verification successful!', type: ToastType.success);
        context.go('/customer/dashboard');
      } else if (mounted) {
        setState(() => _hasError = true);
        ToastService.show(context, 'Invalid OTP. Please check the code.', type: ToastType.error);
      }
    } catch (e) {
      setState(() => _hasError = true);
      _checkLockoutStatus();
      if (mounted) {
        ToastService.show(context, e.toString().replaceAll('Exception: ', ''), type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp(OtpChannel channel) async {
    if (_countdown > 0 || _remainingLockout > 0) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authRepositoryProvider).sendOtp(widget.phoneNumber, channel);
      if (mounted) {
        final channelName = channel == OtpChannel.sms ? 'SMS' : 'WhatsApp';
        ToastService.show(context, 'OTP resent via $channelName!', type: ToastType.success);
        _startTimer();
      }
    } catch (e) {
      _checkLockoutStatus();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final isCurrentlyLocked = _remainingLockout > 0 || AuthService().isLocked;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Verification',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
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
                  // Security Lockout Banner (if 3 failed attempts triggered)
                  if (isCurrentlyLocked)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_clock, color: Colors.red, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Too Many Attempts',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _remainingLockout > 60
                                      ? 'Please wait ${(_remainingLockout / 60).ceil()} minutes before trying again.'
                                      : 'Please wait ${_remainingLockout}s before trying again.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Verify Number',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We sent a 6-digit code to: ${widget.phoneNumber}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: subtitleColor,
                              ),
                        ),
                        const SizedBox(height: 28),

                        // Disable OTP input if locked
                        Opacity(
                          opacity: isCurrentlyLocked ? 0.4 : 1.0,
                          child: IgnorePointer(
                            ignoring: isCurrentlyLocked,
                            child: OTPInputRow(
                              length: 6,
                              hasError: _hasError,
                              onCompleted: _verifyOtp,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                            ),
                          )
                        else
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _countdown > 0
                                        ? 'Resend OTP in ${_countdown}s'
                                        : 'Didn\'t receive OTP? ',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: subtitleColor,
                                        ),
                                  ),
                                ],
                              ),
                              if (_countdown == 0 && !isCurrentlyLocked) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _resendOtp(OtpChannel.sms),
                                      icon: const Icon(Icons.sms_outlined, size: 16),
                                      label: const Text('Resend SMS'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _resendOtp(OtpChannel.whatsapp),
                                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                      label: const Text('Send WhatsApp'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
