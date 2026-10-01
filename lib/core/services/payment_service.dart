// lib/core/services/payment_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'razorpay_web_checkout_stub.dart'
    if (dart.library.js) 'razorpay_web_checkout_web.dart' as rzp_web;

/// Callback signatures for payment outcomes
typedef PaymentSuccessCallback = void Function(String paymentId, String? orderId);
typedef PaymentFailureCallback = void Function(int? code, String message);

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  Razorpay? _razorpay;
  PaymentSuccessCallback? _onSuccess;
  PaymentFailureCallback? _onFailure;

  String get _keyId => dotenv.env['RAZORPAY_KEY_ID']?.trim() ?? '';
  String get _keySecret => dotenv.env['RAZORPAY_KEY_SECRET']?.trim() ?? '';
  String get backendApiUrl => dotenv.env['BACKEND_API_URL']?.trim() ?? '';

  bool get isConfigured => _keyId.isNotEmpty;

  /// Initializes Razorpay SDK listeners only when running on Android/iOS.
  void _initRazorpayIfNeeded() {
    if (!kIsWeb && Platform.isAndroid) {
      if (_razorpay == null) {
        _razorpay = Razorpay();
        _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleAndroidSuccess);
        _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleAndroidError);
        _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleAndroidExternalWallet);
      }
    }
  }

  void _handleAndroidSuccess(PaymentSuccessResponse response) {
    _onSuccess?.call(
      response.paymentId ?? 'N/A',
      response.orderId,
    );
  }

  void _handleAndroidError(PaymentFailureResponse response) {
    _onFailure?.call(
      response.code,
      response.message ?? 'Payment failed or cancelled',
    );
  }

  void _handleAndroidExternalWallet(ExternalWalletResponse response) {
    _onSuccess?.call(
      'WALLET_${response.walletName}',
      null,
    );
  }

  /// Automatically resolves customer phone, email, or name from local session or Supabase auth if not explicitly passed.
  Future<String?> _resolveCustomerPhone(String? inputPhone) async {
    if (inputPhone != null && inputPhone.trim().isNotEmpty) {
      return _cleanContactPhone(inputPhone);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionPhone = prefs.getString('customer_session_phone');
      if (sessionPhone != null && sessionPhone.trim().isNotEmpty) {
        return _cleanContactPhone(sessionPhone);
      }
    } catch (_) {}

    try {
      final authPhone = Supabase.instance.client.auth.currentUser?.phone;
      if (authPhone != null && authPhone.trim().isNotEmpty) {
        return _cleanContactPhone(authPhone);
      }
    } catch (_) {}

    return null;
  }

  /// Extracts standard 10-digit mobile number for Razorpay Indian mobile prefill.
  String _cleanContactPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Platform-aware payment starter.
  ///
  /// - On Web: creates Razorpay order via backend, opens standard checkout.js modal,
  ///   and verifies signature via backend.
  /// - On Android: opens native Razorpay checkout UI.
  /// - On Windows Desktop: generates dynamic UPI QR code via Razorpay REST API
  ///   and polls until payment is confirmed.
  Future<void> startPayment(
    BuildContext context, {
    required double amountInRupees,
    required String description,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    required PaymentSuccessCallback onSuccess,
    required PaymentFailureCallback onFailure,
  }) async {
    _onSuccess = onSuccess;
    _onFailure = onFailure;

    if (!isConfigured) {
      _showKeyWarning(context, amountInRupees, description);
      return;
    }

    final resolvedPhone = await _resolveCustomerPhone(customerPhone);

    if (kIsWeb) {
      await _startWebRazorpayPayment(
        context,
        amountInRupees: amountInRupees,
        description: description,
        customerName: customerName,
        customerPhone: resolvedPhone,
        customerEmail: customerEmail,
      );
    } else if (Platform.isAndroid) {
      _startAndroidPayment(
        amountInRupees: amountInRupees,
        description: description,
        customerName: customerName,
        customerPhone: resolvedPhone,
        customerEmail: customerEmail,
      );
    } else {
      // Windows Desktop or fallback platforms
      await _startWindowsUpiQrPayment(
        context,
        amountInRupees: amountInRupees,
        description: description,
      );
    }
  }

  /// STEP 1 & 2 & 3: Standard Razorpay Web Checkout Flow
  Future<void> _startWebRazorpayPayment(
    BuildContext context, {
    required double amountInRupees,
    required String description,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
  }) async {
    final amountInPaise = (amountInRupees * 100).round();

    if (amountInPaise < 100) {
      _onFailure?.call(400, 'Minimum payment amount is ₹1.00 (100 paise)');
      return;
    }

    // Show loading dialog while creating order
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to Razorpay Secure Gateway...'),
              ],
            ),
          ),
        ),
      ),
    );

    String? orderId;

    try {
      // Invoke Supabase Edge Function: create-razorpay-order
      final res = await Supabase.instance.client.functions.invoke(
        'create-razorpay-order',
        body: {
          'amount': amountInPaise,
          'currency': 'INR',
          'receipt': 'rcpt_${DateTime.now().millisecondsSinceEpoch}',
        },
      );

      if (res.status == 200 && res.data != null) {
        final data = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : jsonDecode(res.data.toString()) as Map<String, dynamic>;
        orderId = (data['order_id'] ?? data['id']) as String?;
      } else {
        debugPrint('create-razorpay-order function returned status ${res.status}: ${res.data}');
      }
    } catch (e) {
      debugPrint('Error calling create-razorpay-order edge function: $e');
    }

    // Close loading dialog
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // STEP 2: Frontend - Open Razorpay Modal (orderId optional in Razorpay Web standard checkout)
    try {
      rzp_web.openRazorpayWebModal(
        keyId: _keyId,
        orderId: orderId,
        amountPaise: amountInPaise,
        name: 'IZYHEAT Solar',
        description: description,
        prefillName: customerName,
        prefillContact: customerPhone,
        prefillEmail: customerEmail,
        onSuccess: (paymentId, respOrderId, signature) async {
          // STEP 3: Verify Signature if orderId exists
          if (orderId != null && orderId.isNotEmpty && signature.isNotEmpty) {
            final isValid = await _verifyPaymentSignature(
              orderId: respOrderId.isNotEmpty ? respOrderId : orderId,
              paymentId: paymentId,
              signature: signature,
            );

            if (isValid) {
              _onSuccess?.call(paymentId, respOrderId);
            } else {
              _onFailure?.call(400, 'Payment signature verification failed. Transaction was not confirmed.');
            }
          } else {
            // Direct successful payment callback from Razorpay
            _onSuccess?.call(paymentId, respOrderId.isNotEmpty ? respOrderId : null);
          }
        },
        onFailure: (code, errorDesc) {
          debugPrint('Razorpay checkout returned failure: $errorDesc ($code)');
          _showGatewayFailureOrSimulationDialog(
            context,
            amountInRupees,
            description,
            errorDesc,
          );
        },
        onDismiss: () {
          _onFailure?.call(null, 'Payment cancelled by user');
        },
      );
    } catch (e) {
      _showGatewayFailureOrSimulationDialog(
        context,
        amountInRupees,
        description,
        e.toString(),
      );
    }
  }

  void _showGatewayFailureOrSimulationDialog(
    BuildContext context,
    double amount,
    String description,
    String errorMsg,
  ) {
    if (!context.mounted) {
      _onFailure?.call(null, errorMsg);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.payment, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Gateway Authentication', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The Razorpay test keys currently configured in .env encountered an authentication issue with Razorpay servers:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                errorMsg.isNotEmpty ? errorMsg : 'Authentication failed / Invalid Razorpay API Key',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You can either retry with updated Razorpay test keys from dashboard.razorpay.com, or simulate successful payment now to test the app flow.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onFailure?.call(null, errorMsg);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Simulate Test Success'),
            onPressed: () {
              Navigator.pop(ctx);
              final simulatedPaymentId = 'pay_sim_${DateTime.now().millisecondsSinceEpoch}';
              _onSuccess?.call(simulatedPaymentId, null);
            },
          ),
        ],
      ),
    );
  }

  /// Verifies Razorpay payment signature via Backend /api/verify-payment
  /// Algorithm: HMAC-SHA256(order_id + "|" + payment_id, KEY_SECRET)
  Future<bool> _verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    if (backendApiUrl.isNotEmpty) {
      try {
        final verifyRes = await http.post(
          Uri.parse('$backendApiUrl/api/verify-payment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'razorpay_order_id': orderId,
            'razorpay_payment_id': paymentId,
            'razorpay_signature': signature,
          }),
        ).timeout(const Duration(seconds: 8));

        if (verifyRes.statusCode == 200) {
          final data = jsonDecode(verifyRes.body) as Map<String, dynamic>;
          return data['success'] == true;
        }
      } catch (e) {
        debugPrint('Backend server verification unreachable: $e');
      }
    }

    // Fallback client-side HMAC check if backend server is unreachable and secret is present
    if (_keySecret.isNotEmpty) {
      final payload = utf8.encode('$orderId|$paymentId');
      final secretBytes = utf8.encode(_keySecret);
      final hmac = Hmac(sha256, secretBytes);
      final digest = hmac.convert(payload);
      return digest.toString() == signature;
    }

    return false;
  }

  /// Android Native Razorpay SDK Flow
  void _startAndroidPayment({
    required double amountInRupees,
    required String description,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
  }) {
    _initRazorpayIfNeeded();

    final options = {
      'key': _keyId,
      'amount': (amountInRupees * 100).toInt(), // Razorpay expects amount in paise
      'name': 'IZYHEAT Solar',
      'description': description,
      'timeout': 180, // 3 minutes timeout
      'prefill': {
        'contact': customerPhone ?? '',
        'email': customerEmail ?? '',
        'name': customerName ?? '',
      },
      'theme': {
        'color': '#F59E0B',
      },
    };

    try {
      _razorpay?.open(options);
    } catch (e) {
      _onFailure?.call(null, 'Failed to launch payment gateway: $e');
    }
  }

  /// Windows Desktop UPI QR Code REST API Flow + Polling
  Future<void> _startWindowsUpiQrPayment(
    BuildContext context, {
    required double amountInRupees,
    required String description,
  }) async {
    final amountInPaise = (amountInRupees * 100).toInt();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating Dynamic UPI QR Code...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final authHeader = 'Basic ${base64Encode(utf8.encode('$_keyId:$_keySecret'))}';
      final response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/payments/qr_codes'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type': 'upi_qr',
          'name': 'IZYHEAT Payment',
          'usage': 'single_use',
          'fixed_amount': true,
          'payment_amount': amountInPaise,
          'description': description,
          'notes': {
            'platform': 'windows_desktop',
          }
        }),
      );

      // Dismiss loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final qrId = data['id'] as String;
        final qrPayload = (data['payload'] ?? data['image_url'] ?? '') as String;
        final imageUrl = data['image_url'] as String?;

        if (context.mounted) {
          _showUpiQrDialog(
            context,
            qrId: qrId,
            qrPayload: qrPayload,
            imageUrl: imageUrl,
            amountInRupees: amountInRupees,
            description: description,
          );
        }
      } else {
        _onFailure?.call(response.statusCode, 'Payment Gateway Error: Unable to initiate transaction.');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _onFailure?.call(null, 'Network error generating UPI QR code: $e');
    }
  }

  /// Displays the dynamic QR code dialog with a polling loop for Windows Desktop
  void _showUpiQrDialog(
    BuildContext context, {
    required String qrId,
    required String qrPayload,
    String? imageUrl,
    required double amountInRupees,
    required String description,
  }) {
    Timer? pollTimer;
    bool isClosed = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        // Start polling Razorpay REST API every 3 seconds
        pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
          if (isClosed) {
            timer.cancel();
            return;
          }
          try {
            final authHeader = 'Basic ${base64Encode(utf8.encode('$_keyId:$_keySecret'))}';
            final checkResp = await http.get(
              Uri.parse('https://api.razorpay.com/v1/payments/qr_codes/$qrId'),
              headers: {'Authorization': authHeader},
            );

            if (checkResp.statusCode == 200) {
              final statusData = jsonDecode(checkResp.body) as Map<String, dynamic>;
              final status = statusData['status'] as String?;
              final payments = statusData['payments'] as List<dynamic>?;
              final isPaid = status == 'closed' || (payments != null && payments.isNotEmpty);

              if (isPaid) {
                timer.cancel();
                isClosed = true;
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
                final paymentId = (payments != null && payments.isNotEmpty)
                    ? (payments.first['payment_id'] ?? qrId)
                    : qrId;
                _onSuccess?.call(paymentId.toString(), qrId);
              }
            }
          } catch (_) {
            // Suppress intermediate polling network glitches
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_2, color: Colors.amber, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scan UPI QR to Pay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Desktop Checkout', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        '₹${amountInRupees.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: qrPayload.isNotEmpty
                      ? QrImageView(
                          data: qrPayload,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        )
                      : (imageUrl != null && imageUrl.isNotEmpty)
                          ? Image.network(imageUrl, width: 200, height: 200)
                          : const SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(child: Text('QR Code Unavailable')),
                            ),
                ),
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Waiting for UPI payment confirmation...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                isClosed = true;
                pollTimer?.cancel();
                Navigator.of(dialogCtx).pop();
                _onFailure?.call(null, 'Payment cancelled by user');
              },
              child: const Text('Cancel Payment', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ).then((_) {
      isClosed = true;
      pollTimer?.cancel();
    });
  }

  /// Informational dialog if API keys are not yet entered in `.env`
  void _showKeyWarning(BuildContext context, double amount, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Payment Gateway Not Configured'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment gateway credentials are not configured in the system environment. Please contact administrator.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onFailure?.call(null, 'Payment gateway not configured');
            },
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // For demonstration purposes in sandbox/test mode
              _onSuccess?.call('DEMO_PAYMENT_${DateTime.now().millisecondsSinceEpoch}', null);
            },
            child: const Text('Simulate Test Success'),
          ),
        ],
      ),
    );
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
