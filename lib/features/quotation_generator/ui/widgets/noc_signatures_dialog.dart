// lib/features/quotation_generator/ui/widgets/noc_signatures_dialog.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../complaints/widgets/signature_pad_widget.dart';

class NocSignaturesResult {
  final String customerSignature; // public URL or base64 data URI
  final String customerSignatoryName;
  final String technicianSignature; // public URL or base64 data URI
  final String technicianName;

  const NocSignaturesResult({
    required this.customerSignature,
    required this.customerSignatoryName,
    required this.technicianSignature,
    required this.technicianName,
  });
}

class NocSignaturesDialog extends StatefulWidget {
  final String customerName;
  final String? initialSignatoryName;
  final String? initialCustomerSignature;
  final String? initialTechnicianName;
  final String? initialTechnicianSignature;

  const NocSignaturesDialog({
    super.key,
    required this.customerName,
    this.initialSignatoryName,
    this.initialCustomerSignature,
    this.initialTechnicianName,
    this.initialTechnicianSignature,
  });

  static Future<NocSignaturesResult?> show({
    required BuildContext context,
    required String customerName,
    String? initialSignatoryName,
    String? initialCustomerSignature,
    String? initialTechnicianName,
    String? initialTechnicianSignature,
  }) {
    return showDialog<NocSignaturesResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NocSignaturesDialog(
        customerName: customerName,
        initialSignatoryName: initialSignatoryName,
        initialCustomerSignature: initialCustomerSignature,
        initialTechnicianName: initialTechnicianName,
        initialTechnicianSignature: initialTechnicianSignature,
      ),
    );
  }

  @override
  State<NocSignaturesDialog> createState() => _NocSignaturesDialogState();
}

class _NocSignaturesDialogState extends State<NocSignaturesDialog> {
  late final TextEditingController _customerSignatoryCtrl;
  late final TextEditingController _technicianNameCtrl;

  String? _customerSignature;
  String? _technicianSignature;

  @override
  void initState() {
    super.initState();
    _customerSignatoryCtrl = TextEditingController(
      text: widget.initialSignatoryName?.trim().isNotEmpty == true
          ? widget.initialSignatoryName!.trim()
          : widget.customerName.trim(),
    );
    _technicianNameCtrl = TextEditingController(
      text: widget.initialTechnicianName?.trim() ?? '',
    );
    _customerSignature = widget.initialCustomerSignature;
    _technicianSignature = widget.initialTechnicianSignature;
  }

  @override
  void dispose() {
    _customerSignatoryCtrl.dispose();
    _technicianNameCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _customerSignature != null &&
      _customerSignature!.trim().isNotEmpty &&
      _technicianSignature != null &&
      _technicianSignature!.trim().isNotEmpty;

  Widget _buildImagePreview(String sigStr) {
    if (sigStr.startsWith('http://') || sigStr.startsWith('https://')) {
      return Image.network(
        sigStr,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 28),
        ),
      );
    }
    try {
      final base64Str = sigStr.contains('base64,') ? sigStr.split('base64,').last : sigStr;
      final Uint8List bytes = base64Decode(base64Str);
      return Image.memory(bytes, fit: BoxFit.contain);
    } catch (_) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.grey, size: 28),
      );
    }
  }

  Future<void> _openCustomerSignaturePad() async {
    final sig = await showDialog<String>(
      context: context,
      builder: (_) => const SignaturePadDialog(title: 'Customer Signature'),
    );
    if (sig != null && sig.isNotEmpty) {
      setState(() => _customerSignature = sig);
    }
  }

  Future<void> _openTechnicianSignaturePad() async {
    final sig = await showDialog<String>(
      context: context,
      builder: (_) => const SignaturePadDialog(title: 'Technician Signature'),
    );
    if (sig != null && sig.isNotEmpty) {
      setState(() => _technicianSignature = sig);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.draw_outlined, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NOC Verification & Signatures',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Both Customer and Technician signatures are required to finalize and print the official NOC certificate.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // ─── 1. Customer Verification ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business_outlined, size: 17, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        const Text(
                          'Customer Verification',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_customerSignature != null && _customerSignature!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Signed ✓',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Customer Signatory Name',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _customerSignatoryCtrl.text.isNotEmpty ? _customerSignatoryCtrl.text : widget.customerName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_customerSignature != null && _customerSignature!.isNotEmpty) ...[
                      Container(
                        height: 90,
                        width: double.infinity,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                        ),
                        child: _buildImagePreview(_customerSignature!),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: _openCustomerSignaturePad,
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Re-sign', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.red.shade600,
                            ),
                            onPressed: () => setState(() => _customerSignature = null),
                            icon: const Icon(Icons.close, size: 14),
                            label: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _openCustomerSignaturePad,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 72,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2, style: BorderStyle.solid),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.draw, color: Color(0xFF2563EB), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Tap to Draw Customer Signature *',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ─── 2. Technician Verification ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.handyman_outlined, size: 17, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 6),
                        const Text(
                          'Technician Verification',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_technicianSignature != null && _technicianSignature!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Signed ✓',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Technician Name (Assigned)',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _technicianNameCtrl.text.isNotEmpty
                                      ? _technicianNameCtrl.text
                                      : (widget.initialTechnicianName?.isNotEmpty == true
                                          ? widget.initialTechnicianName!
                                          : 'Authorized Technician'),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_technicianSignature != null && _technicianSignature!.isNotEmpty) ...[
                      Container(
                        height: 90,
                        width: double.infinity,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                        ),
                        child: _buildImagePreview(_technicianSignature!),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: _openTechnicianSignaturePad,
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Re-sign', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.red.shade600,
                            ),
                            onPressed: () => setState(() => _technicianSignature = null),
                            icon: const Icon(Icons.close, size: 14),
                            label: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _openTechnicianSignaturePad,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 72,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2, style: BorderStyle.solid),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.draw, color: Color(0xFF7C3AED), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Tap to Draw Technician Signature *',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isValid ? const Color(0xFF059669) : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text(
                      'Generate & Issue NOC',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _isValid
                        ? () {
                            Navigator.pop(
                              context,
                              NocSignaturesResult(
                                customerSignature: _customerSignature!.trim(),
                                customerSignatoryName: _customerSignatoryCtrl.text.trim().isNotEmpty
                                    ? _customerSignatoryCtrl.text.trim()
                                    : widget.customerName.trim(),
                                technicianSignature: _technicianSignature!.trim(),
                                technicianName: _technicianNameCtrl.text.trim(),
                              ),
                            );
                          }
                        : () {
                            String msg = 'Please draw both Customer and Technician signatures.';
                            if (_technicianNameCtrl.text.trim().isEmpty) {
                              msg = 'Please enter Technician Name and provide signatures.';
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg), backgroundColor: Colors.orange.shade800),
                            );
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
