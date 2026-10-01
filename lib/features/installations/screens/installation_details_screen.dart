// lib/features/installations/screens/installation_details_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/installation_model.dart';
import '../providers/installations_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../complaints/widgets/signature_pad_widget.dart';
import '../services/installation_pdf_service.dart';

class InstallationDetailsScreen extends ConsumerStatefulWidget {
  final String installationId;

  const InstallationDetailsScreen({super.key, required this.installationId});

  @override
  ConsumerState<InstallationDetailsScreen> createState() =>
      _InstallationDetailsScreenState();
}

class _InstallationDetailsScreenState
    extends ConsumerState<InstallationDetailsScreen> {
  final ImagePicker _picker = ImagePicker();

  Widget _buildImage(String url,
      {double? height, double? width, BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width,
      fit: fit,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) =>
          const Icon(Icons.broken_image, size: 40),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImage(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteInstallation(Installation installation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Installation'),
        content: Text(
            'Are you sure you want to delete installation ${installation.ticketNumber}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(installationsProvider.notifier)
                  .deleteInstallation(installation.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Installation deleted successfully'),
                    backgroundColor: AppColors.error,
                  ),
                );
                context.pop();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(
      Installation installation, bool isAfterPhoto) async {
    try {
      final XFile? photo =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final supabase = ref.read(supabaseClientProvider);
      final uploadedUrl = await StorageService.uploadImage(
        supabase: supabase,
        base64OrPath: base64Str,
        folder: 'installation_photos',
      );

      if (uploadedUrl != null) {
        if (isAfterPhoto) {
          await ref
              .read(installationsProvider.notifier)
              .updateAfterPhoto(installation.id, uploadedUrl);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo uploaded successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e')),
        );
      }
    }
  }

  Future<void> _takeTechnicianSignature(Installation installation) async {
    final signatureData = await showDialog<String>(
      context: context,
      builder: (ctx) => const SignaturePadDialog(title: 'Technician Digital Signature'),
    );

    if (signatureData != null && signatureData.isNotEmpty) {
      try {
        final supabase = ref.read(supabaseClientProvider);
        final publicUrl = await StorageService.uploadImage(
          supabase: supabase,
          base64OrPath: signatureData,
          folder: 'signatures',
        );

        if (publicUrl != null) {
          await ref.read(installationsProvider.notifier).saveTechnicianSignature(installation.id, publicUrl);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Technician signature saved successfully!'), backgroundColor: Color(0xFF10B981)),
            );
          }
        } else {
          throw Exception('Failed to upload technician signature');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving signature: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _takeCustomerSignature(Installation installation) async {
    final signatureData = await showDialog<String>(
      context: context,
      builder: (ctx) => const SignaturePadDialog(title: 'Customer Digital Signature'),
    );

    if (signatureData != null && signatureData.isNotEmpty) {
      try {
        final supabase = ref.read(supabaseClientProvider);
        final publicUrl = await StorageService.uploadImage(
          supabase: supabase,
          base64OrPath: signatureData,
          folder: 'signatures',
        );

        if (publicUrl != null) {
          await ref.read(installationsProvider.notifier).saveCustomerSignature(installation.id, publicUrl);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Customer signature saved successfully!'), backgroundColor: Color(0xFF10B981)),
            );
          }
        } else {
          throw Exception('Failed to upload customer signature');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving signature: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editSealNumberAfter(Installation installation) async {
    final controller = TextEditingController(text: installation.sealNumberAfter ?? '');
    final seal = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post-Installation Seal Number', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the new seal number placed after installation completion:',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Seal Number (After)',
                hintText: 'e.g. SL-984210',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.security_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            child: const Text('Save Seal', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (seal != null && seal.isNotEmpty) {
      await ref.read(installationsProvider.notifier).updateSealNumberAfter(installation.id, seal);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post-installation seal number saved!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    }
  }

  void _markAsCompleted(Installation installation) async {
    final List<String> missing = [];
    if (installation.technicianSignatureUrl == null || installation.technicianSignatureUrl!.isEmpty) {
      missing.add('Technician Signature');
    }
    if (installation.customerSignatureUrl == null || installation.customerSignatureUrl!.isEmpty) {
      missing.add('Customer Signature');
    }
    if (installation.afterImageUrl == null || installation.afterImageUrl!.isEmpty) {
      missing.add('After-Installation Photo');
    }
    if (installation.sealNumberAfter == null || installation.sealNumberAfter!.trim().isEmpty) {
      missing.add('Seal Number (After)');
    }

    if (missing.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text('Required Steps Missing',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please complete the following mandatory items before confirming installation completion:',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              ...missing.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Color(0xFFEF4444), size: 14),
                      ),
                      const SizedBox(width: 10),
                      Text(item,
                          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Use the action buttons below on this screen to take signatures, upload photos, and record the seal number.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Installation Completion', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: const Text(
            'All verification requirements (Technician signature, Customer signature, After photo, Seal number) have been verified.\n\nAre you sure you want to confirm and mark this installation as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Confirm & Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(installationsProvider.notifier)
          .completeInstallation(installation.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Installation marked as completed!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final installations = ref.watch(installationsProvider);
    final installation = installations.firstWhere(
      (c) => c.id == widget.installationId,
      orElse: () => Installation(
        id: '',
        ticketNumber: '',
        customerId: '',
        customerName: 'Not Found',
        customerPhone: '',
        customerAddress: '',
        priority: 'Low',
        title: 'Installation Not Found',
        description: '',
        tatRemaining: '',
        createdAt: DateTime.now(),
      ),
    );

    if (installation.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Installation ticket not found.')),
      );
    }

    final profile = ref.watch(currentProfileProvider);
    final isAdminOrCoordinator = profile?.primaryRole == UserRole.admin ||
        profile?.primaryRole == UserRole.manager ||
        profile?.primaryRole == UserRole.serviceHead ||
        profile?.roles.contains(UserRole.admin) == true;
    final isClosed =
        installation.status == 'closed' || installation.status == 'resolved';

    Color statusColor;
    String statusText;
    switch (installation.status) {
      case 'pending':
        statusColor = const Color(0xFFEF4444);
        statusText = 'PENDING';
        break;
      case 'assigned':
      case 'in_progress':
        statusColor = const Color(0xFF3B82F6);
        statusText = 'IN PROGRESS';
        break;
      case 'closed':
      case 'resolved':
        statusColor = const Color(0xFF10B981);
        statusText = 'COMPLETED';
        break;
      default:
        statusColor = Colors.grey;
        statusText = installation.status.toUpperCase();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          installation.ticketNumber,
          style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (isAdminOrCoordinator)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Delete Installation',
              onPressed: () => _confirmDeleteInstallation(installation),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Priority Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STATUS',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('PRIORITY',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        installation.priority,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Customer Details Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Information',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.business_outlined,
                            size: 18, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            installation.customerName,
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    if (installation.customerPhone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 18, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Text(installation.customerPhone,
                              style: const TextStyle(fontSize: 13)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.call,
                                color: Color(0xFF10B981), size: 20),
                            onPressed: () => launchUrl(
                                Uri.parse('tel:${installation.customerPhone}')),
                          ),
                        ],
                      ),
                    ],
                    if (installation.customerAddress.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 18, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              installation.customerAddress,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Installation Work Scope Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Work Scope & Technical Details',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      installation.title,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    if (installation.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        installation.description,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4),
                      ),
                    ],
                    if (installation.sealNumberBefore != null &&
                        installation.sealNumberBefore!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.security_outlined,
                              size: 16, color: Color(0xFF0284C7)),
                          const SizedBox(width: 6),
                          Text(
                            'Seal #: ${installation.sealNumberBefore}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Technician Assigned Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Assigned Installer',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (isAdminOrCoordinator && !isClosed)
                          TextButton(
                            onPressed: () => context.push('/installations/assign'),
                            child: const Text('Reassign'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              const Color(0xFF0284C7).withValues(alpha: 0.15),
                          child: const Icon(Icons.engineering,
                              color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              installation.technicianName ?? 'Unassigned',
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            Text(
                              'TAT Remaining: ${installation.tatRemaining}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Photos Section (Before & After)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Site Photos & Proof of Work',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (!isClosed)
                          IconButton(
                            icon: const Icon(Icons.add_a_photo_outlined,
                                color: Color(0xFF0284C7)),
                            tooltip: 'Add Completion Photo',
                            onPressed: () =>
                                _pickAndUploadPhoto(installation, true),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (installation.beforeImageUrl != null &&
                        installation.beforeImageUrl!.isNotEmpty) ...[
                      const Text('Pre-Installation Photos:',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      _buildPhotoRow(installation.beforeImageUrl!),
                      const SizedBox(height: 14),
                    ],
                    if (installation.afterImageUrl != null &&
                        installation.afterImageUrl!.isNotEmpty) ...[
                      const Text('Post-Installation Photos:',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      _buildPhotoRow(installation.afterImageUrl!),
                    ] else ...[
                      Text(
                        'No completion photos uploaded yet.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Sign-off & Post-Installation Verification Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isClosed
                      ? Colors.grey.shade200
                      : const Color(0xFF0284C7).withValues(alpha: 0.35),
                  width: isClosed ? 1 : 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.verified_user_outlined,
                                  size: 18, color: Color(0xFF0284C7)),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Sign-off & Verification',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        if (!isClosed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'REQUIRED FOR CLOSURE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 1. Post-Installation Seal Number
                    _buildVerificationRow(
                      icon: Icons.security_outlined,
                      title: 'Seal Number (After)',
                      subtitle: (installation.sealNumberAfter != null &&
                              installation.sealNumberAfter!.trim().isNotEmpty)
                          ? 'Seal #: ${installation.sealNumberAfter}'
                          : 'Not recorded yet',
                      isCompleted: installation.sealNumberAfter != null &&
                          installation.sealNumberAfter!.trim().isNotEmpty,
                      actionLabel: (installation.sealNumberAfter != null &&
                              installation.sealNumberAfter!.trim().isNotEmpty)
                          ? 'Edit Seal #'
                          : 'Enter Seal # (After)',
                      onAction: !isClosed
                          ? () => _editSealNumberAfter(installation)
                          : null,
                    ),
                    const Divider(height: 18),

                    // 2. Post-Installation Photos
                    _buildVerificationRow(
                      icon: Icons.add_a_photo_outlined,
                      title: 'After-Installation Photo',
                      subtitle: (installation.afterImageUrl != null &&
                              installation.afterImageUrl!.isNotEmpty)
                          ? '${installation.afterImageUrl!.split('|||').where((u) => u.trim().isNotEmpty).length} photo(s) attached'
                          : 'Mandatory proof of completed site work',
                      isCompleted: installation.afterImageUrl != null &&
                          installation.afterImageUrl!.isNotEmpty,
                      actionLabel: (installation.afterImageUrl != null &&
                              installation.afterImageUrl!.isNotEmpty)
                          ? 'Upload More'
                          : 'Upload After Photo',
                      onAction: !isClosed
                          ? () => _pickAndUploadPhoto(installation, true)
                          : null,
                    ),
                    const Divider(height: 18),

                    // 3. Technician Signature
                    _buildSignatureVerificationRow(
                      context: context,
                      title: 'Technician Signature',
                      signatureUrl: installation.technicianSignatureUrl,
                      isClosed: isClosed,
                      onTakeSignature: () =>
                          _takeTechnicianSignature(installation),
                    ),
                    const Divider(height: 18),

                    // 4. Customer Signature
                    _buildSignatureVerificationRow(
                      context: context,
                      title: 'Customer Signature',
                      signatureUrl: installation.customerSignatureUrl,
                      isClosed: isClosed,
                      onTakeSignature: () =>
                          _takeCustomerSignature(installation),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Installation Completion Report PDF Section
            if (isClosed ||
                installation.status == 'resolved' ||
                (installation.customerSignatureUrl != null &&
                    installation.technicianSignatureUrl != null)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text(
                          'Installation Completion Report',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Official report generated with technician and customer verification signatures.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.picture_as_pdf,
                                color: Colors.white, size: 18),
                            label: const Text('View PDF',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final pdfBytes =
                                  await InstallationPdfService.generateCompletionReportPdf(
                                      installation);
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => PdfPreviewScreen(
                                      pdfBytes: pdfBytes,
                                      fileName:
                                          'InstallationReport_${installation.ticketNumber.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_')}.pdf',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.share,
                                color: Colors.white, size: 18),
                            label: const Text('Share PDF',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            onPressed: () =>
                                InstallationPdfService.shareCompletionReport(
                                    installation),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Complete Action Button
            if (!isClosed)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    'Mark Installation Completed',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () => _markAsCompleted(installation),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required String actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0284C7)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isCompleted)
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981))
                  else
                    const Icon(Icons.error_outline, size: 14, color: Color(0xFFF59E0B)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isCompleted ? Colors.grey.shade700 : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
        if (onAction != null)
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 32),
              side: BorderSide(
                color: isCompleted ? Colors.grey.shade400 : const Color(0xFF0284C7),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              actionLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isCompleted ? const Color(0xFF0F172A) : const Color(0xFF0284C7),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSignatureVerificationRow({
    required BuildContext context,
    required String title,
    required String? signatureUrl,
    required bool isClosed,
    required VoidCallback onTakeSignature,
  }) {
    final hasSignature = signatureUrl != null && signatureUrl.isNotEmpty;
    return Row(
      children: [
        const Icon(Icons.draw_outlined, size: 20, color: Color(0xFF0284C7)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (hasSignature)
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981))
                  else
                    const Icon(Icons.error_outline, size: 14, color: Color(0xFFF59E0B)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                hasSignature ? 'Digital signature captured' : 'Missing signature',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: hasSignature ? Colors.grey.shade700 : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
        if (hasSignature) ...[
          GestureDetector(
            onTap: () => _showImagePreview(context, signatureUrl),
            child: Container(
              width: 50,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: _buildImage(signatureUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (!isClosed)
          OutlinedButton(
            onPressed: onTakeSignature,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 32),
              side: BorderSide(
                color: hasSignature ? Colors.grey.shade400 : const Color(0xFF0284C7),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              hasSignature ? 'Re-sign' : 'Take Signature',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasSignature ? const Color(0xFF0F172A) : const Color(0xFF0284C7),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoRow(String urlsStr) {
    final urls = urlsStr.split('|||').where((u) => u.trim().isNotEmpty).toList();
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final url = urls[idx];
          return GestureDetector(
            onTap: () => _showImagePreview(context, url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImage(url, width: 90, height: 90),
            ),
          );
        },
      ),
    );
  }
}
