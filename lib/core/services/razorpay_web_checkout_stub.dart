// lib/core/services/razorpay_web_checkout_stub.dart

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
  throw UnsupportedError('Razorpay Web Checkout is only supported on Web platforms.');
}
