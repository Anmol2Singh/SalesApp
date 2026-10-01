// lib/core/services/razorpay_web_checkout_web.dart

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _window;

@JS('Razorpay')
extension type RazorpayJs._(JSObject _) implements JSObject {
  external RazorpayJs(JSObject options);
  external void open();
  external void on(JSString event, JSFunction handler);
}

/// Opens Razorpay Standard Web Checkout Modal via https://checkout.razorpay.com/v1/checkout.js
void openRazorpayWebModal({
  required String keyId,
  String? orderId,
  required int amountPaise,
  required String name,
  required String description,
  String? prefillName,
  String? prefillContact,
  String? prefillEmail,
  required Function(String paymentId, String orderId, String signature) onSuccess,
  required Function(String code, String description) onFailure,
  required Function() onDismiss,
}) {
  if (!_window.hasProperty('Razorpay'.toJS).toDart) {
    onFailure('SDK_NOT_LOADED', 'Razorpay checkout script is not loaded in web page.');
    return;
  }

  final options = {
    'key': keyId,
    'amount': amountPaise,
    'currency': 'INR',
    'name': name,
    'description': description,
    if (orderId != null && orderId.isNotEmpty) 'order_id': orderId,
    'prefill': {
      'name': prefillName ?? '',
      'contact': prefillContact ?? '',
      'email': prefillEmail ?? '',
    },
    'theme': {
      'color': '#F59E0B',
    },
    'modal': {
      'ondismiss': (() {
        onDismiss();
      }).toJS,
    },
    'handler': ((JSObject response) {
      final paymentId = (response.getProperty('razorpay_payment_id'.toJS) as JSString?)?.toDart ?? '';
      final respOrderId = (response.getProperty('razorpay_order_id'.toJS) as JSString?)?.toDart ?? (orderId ?? '');
      final signature = (response.getProperty('razorpay_signature'.toJS) as JSString?)?.toDart ?? '';
      onSuccess(paymentId, respOrderId, signature);
    }).toJS,
  }.jsify() as JSObject;

  try {
    final rzp = RazorpayJs(options);

    rzp.on(
      'payment.failed'.toJS,
      ((JSObject failResp) {
        try {
          final errorObj = failResp.getProperty('error'.toJS) as JSObject?;
          final code = (errorObj?.getProperty('code'.toJS) as JSString?)?.toDart ?? 'PAYMENT_FAILED';
          final desc = (errorObj?.getProperty('description'.toJS) as JSString?)?.toDart ??
              'Payment was cancelled or rejected by gateway.';
          onFailure(code, desc);
        } catch (_) {
          onFailure('PAYMENT_FAILED', 'Payment failed or was declined.');
        }
      }).toJS,
    );

    rzp.open();
  } catch (e) {
    onFailure('OPEN_ERROR', 'Failed to launch Razorpay Web Checkout: $e');
  }
}
