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
import 'package:printing/printing.dart';
import '../../quotation_generator/models/qg_noc_builder_state.dart';
import '../../quotation_generator/models/qg_noc_document.dart';
import '../../quotation_generator/data/qg_noc_repository.dart';
import '../../quotation_generator/services/pdf_noc_builder.dart';
import '../../quotation_generator/ui/widgets/noc_signatures_dialog.dart';

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
  Map<String, dynamic>? _associatedDeal;
  QgNocDocument? _nocDoc;
  bool _loadingNoc = true;
  bool _isPdfActionBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAssociatedDealAndNoc();
    });
  }

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
    final isManagerOnly = (profile?.roles.contains(UserRole.manager) ?? false) &&
        !(profile?.roles.contains(UserRole.admin) ?? false);
    final isAdminOrCoordinator = !isManagerOnly &&
        (profile?.primaryRole == UserRole.admin ||
            profile?.primaryRole == UserRole.serviceHead ||
            (profile?.roles.contains(UserRole.admin) == true));
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

            // Installed Items Card (from Delivery Challan)
            Builder(builder: (context) {
              final items = _resolveInstalledItems(installation);
              if (items.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
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
                            Row(
                              children: const [
                                Icon(Icons.local_shipping_outlined, size: 18, color: Color(0xFF0284C7)),
                                SizedBox(width: 8),
                                Text(
                                  'Installed Items (Delivery Challan)',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${items.length} items',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...items.map((it) {
                          final desc = (it['description'] ?? it['name'] ?? 'Item').toString();
                          final rawQty = it['qty'];
                          final qtyStr = (rawQty is num && rawQty % 1 == 0)
                              ? rawQty.toInt().toString()
                              : (rawQty?.toString() ?? '1');
                          final uom = (it['uom'] ?? 'NOS').toString();
                          final remark = it['remark']?.toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        desc,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                                      ),
                                      if (remark != null && remark.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Remark / S/N: $remark',
                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text(
                                    'Qty: $qtyStr $uom',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            }),

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
                      onAction: (!isClosed && !isManagerOnly)
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
                      onAction: (!isClosed && !isManagerOnly)
                          ? () => _pickAndUploadPhoto(installation, true)
                          : null,
                    ),
                    const Divider(height: 18),

                    // 3. Technician Signature
                    _buildSignatureVerificationRow(
                      context: context,
                      title: 'Technician Signature',
                      signatureUrl: installation.technicianSignatureUrl,
                      isClosed: isClosed || isManagerOnly,
                      onTakeSignature: () =>
                          _takeTechnicianSignature(installation),
                    ),
                    const Divider(height: 18),

                    // 4. Customer Signature
                    _buildSignatureVerificationRow(
                      context: context,
                      title: 'Customer Signature',
                      signatureUrl: installation.customerSignatureUrl,
                      isClosed: isClosed || isManagerOnly,
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
                            onPressed: _isPdfActionBusy
                                ? null
                                : () => _viewInstallationPdf(installation),
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
                            onPressed: _isPdfActionBusy
                                ? null
                                : () => _shareInstallationPdf(installation),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ─── NO OBJECTION CERTIFICATE (NOC) ───────────────────────────
            _buildNocSection(installation),
            const SizedBox(height: 20),

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

  List<Map<String, dynamic>> _resolveInstalledItems(Installation inst) {
    final notes = inst.notes ?? '';
    if (notes.isEmpty) return [];
    final match = RegExp(r'\[INSTALLED_ITEMS:\s*(\[.*?\])\s*\]').firstMatch(notes);
    if (match != null) {
      try {
        final list = jsonDecode(match.group(1)!) as List<dynamic>;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    final textMatch = RegExp(r'Installed Items:\s*([^\n]+)').firstMatch(notes);
    if (textMatch != null) {
      final raw = textMatch.group(1)!;
      final parts = raw.split(',');
      final List<Map<String, dynamic>> items = [];
      for (final p in parts) {
        final itemStr = p.trim();
        if (itemStr.isEmpty) continue;
        final qtyMatch = RegExp(r'^(.*?)\s*\(Qty:\s*(\d+(?:\.\d+)?)\s*([a-zA-Z]*)\)').firstMatch(itemStr);
        if (qtyMatch != null) {
          items.add({
            'description': qtyMatch.group(1)?.trim() ?? itemStr,
            'qty': qtyMatch.group(2)!,
            'uom': qtyMatch.group(3)?.trim().isNotEmpty == true ? qtyMatch.group(3)!.trim() : 'NOS',
          });
        } else {
          items.add({'description': itemStr, 'qty': 1, 'uom': 'NOS'});
        }
      }
      return items;
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // NOC Handling & Signatures
  // ---------------------------------------------------------------------------

  Future<void> _loadAssociatedDealAndNoc([Installation? currentInst]) async {
    final supabase = ref.read(supabaseClientProvider);
    Installation? inst = currentInst;
    if (inst == null) {
      final list = ref.read(installationsProvider);
      try {
        inst = list.firstWhere((c) => c.id == widget.installationId);
      } catch (_) {
        final res = await supabase.from('installations').select().eq('id', widget.installationId).maybeSingle();
        if (res != null) {
          inst = Installation.fromJson(Map<String, dynamic>.from(res));
        }
      }
    }
    if (inst == null) {
      if (mounted) setState(() => _loadingNoc = false);
      return;
    }

    final deal = await _resolveDealForInstallation(inst);
    QgNocDocument? noc;
    if (deal != null && deal['id'] != null) {
      final dealId = deal['id'].toString();
      final docs = await QgNocRepository.instance.getDocumentsForPipeline(dealId);
      if (docs.isNotEmpty) {
        noc = docs.first;
      }
    }

    if (mounted) {
      setState(() {
        _associatedDeal = deal;
        _nocDoc = noc;
        _loadingNoc = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _resolveDealForInstallation(Installation installation) async {
    final supabase = ref.read(supabaseClientProvider);
    final notes = installation.notes ?? '';

    // Check notes for explicit Deal ID (e.g. DEAL-26-27-0028 or UUID)
    final matchBoth = RegExp(r'Deal ID:\s*([^\s\(\)\n]+)(?:\s*\(([0-9a-fA-F-]{36})\))?').firstMatch(notes);
    String? dealNum;
    String? dealUuid;
    if (matchBoth != null) {
      final g1 = matchBoth.group(1)?.trim();
      final g2 = matchBoth.group(2)?.trim();
      if (g2 != null && g2.isNotEmpty) {
        dealNum = g1;
        dealUuid = g2;
      } else if (g1 != null && g1.isNotEmpty) {
        if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(g1)) {
          dealUuid = g1;
        } else {
          dealNum = g1;
        }
      }
    }

    if (dealUuid != null && dealUuid.isNotEmpty) {
      try {
        final res = await supabase
            .from('sales_pipelines')
            .select('*, customers(*), products(*), quotations(*)')
            .eq('id', dealUuid)
            .maybeSingle();
        if (res != null) return Map<String, dynamic>.from(res);
      } catch (_) {}
    }

    if (dealNum != null && dealNum.isNotEmpty) {
      try {
        final res = await supabase
            .from('sales_pipelines')
            .select('*, customers(*), products(*), quotations(*)')
            .eq('deal_id', dealNum)
            .maybeSingle();
        if (res != null) return Map<String, dynamic>.from(res);
      } catch (_) {}
    }

    if (installation.customerId.isNotEmpty) {
      try {
        final res = await supabase
            .from('sales_pipelines')
            .select('*, customers(*), products(*), quotations(*)')
            .eq('customer_id', installation.customerId)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false);
        final list = List<Map<String, dynamic>>.from(res as List? ?? []);
        if (list.length == 1) return list.first;
        if (list.length > 1) {
          if (installation.productName != null && installation.productName!.isNotEmpty) {
            final pClean = installation.productName!.toLowerCase().trim();
            for (final d in list) {
              final prodMap = d['products'] as Map?;
              final pName = (prodMap?['name'] ?? '').toString().toLowerCase();
              if (pName.isNotEmpty && (pName.contains(pClean) || pClean.contains(pName))) {
                return d;
              }
            }
          }
          return list.first;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _takeNocSignatures(Installation installation) async {
    if (_isPdfActionBusy) return;
    setState(() => _isPdfActionBusy = true);
    try {
      final deal = _associatedDeal ?? await _resolveDealForInstallation(installation);
      if (deal == null || deal['id'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not link this installation to a sales deal. Ensure the customer has a valid deal.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

    final initialCustName = _nocDoc?.customerSignatoryName?.isNotEmpty == true
        ? _nocDoc!.customerSignatoryName!
        : installation.customerName;
    final initialTechName = _nocDoc?.technicianName?.isNotEmpty == true
        ? _nocDoc!.technicianName!
        : (installation.technicianName?.isNotEmpty == true
            ? installation.technicianName!
            : (ref.read(currentProfileProvider)?.fullName ?? ''));

    // Fresh new signatures required for NOC - do not prefill signatures from Installation
    if (!mounted) return;
    final sigResult = await NocSignaturesDialog.show(
      context: context,
      customerName: installation.customerName,
      initialSignatoryName: initialCustName,
      initialTechnicianName: initialTechName,
    );

    if (sigResult == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Issuing & Signing NOC Certificate...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

      final supabase = ref.read(supabaseClientProvider);
      final dealId = deal['id'].toString();

      Map<String, dynamic>? qData;
      if (deal['quotations'] is Map) {
        qData = Map<String, dynamic>.from(deal['quotations'] as Map);
      } else if (deal['quotations'] is List && (deal['quotations'] as List).isNotEmpty) {
        qData = Map<String, dynamic>.from((deal['quotations'] as List).first as Map);
      }
      if (qData == null) {
        try {
          final qRes = await supabase
              .from('quotations')
              .select()
              .eq('pipeline_id', dealId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (qRes != null) qData = Map<String, dynamic>.from(qRes);
        } catch (_) {}
      }

      final custMap = deal['customers'] is Map ? Map<String, dynamic>.from(deal['customers'] as Map) : null;
      final customerName = (custMap?['company_name'] as String? ?? custMap?['customer_name'] as String? ?? installation.customerName).trim();
      final siteAddress = (custMap?['address'] as String? ?? installation.customerAddress).trim();

      final prodMap = deal['products'] is Map ? Map<String, dynamic>.from(deal['products'] as Map) : null;
      final productName = (prodMap?['name'] as String? ?? installation.productName ?? 'Heat Pump / Equipment').trim();

      final equipmentLines = <NocEquipmentLine>[];
      if (qData != null && qData['line_items'] is List) {
        for (final item in (qData['line_items'] as List)) {
          if (item is Map) {
            final desc = item['description']?.toString() ?? item['name']?.toString() ?? '';
            final qty = (item['quantity'] ?? item['qty'] ?? 1) as num;
            final uom = item['uom']?.toString() ?? 'Nos';
            if (desc.isNotEmpty) {
              equipmentLines.add(NocEquipmentLine(
                product: productName,
                model: desc,
                quantity: qty.toInt(),
                uom: uom,
              ));
            }
          }
        }
      }
      if (equipmentLines.isEmpty) {
        equipmentLines.add(NocEquipmentLine(
          product: productName,
          model: productName,
          quantity: 1,
          uom: 'Nos',
        ));
      }

      final compConfig = await QgNocRepository.fetchCompanyDetailsFromTemplate(
        supabase,
        productId: deal['product_id']?.toString(),
        productName: productName,
      );
      final profile = await QgNocRepository.instance.getProfileForProduct(productName);
      final profileConfirmations = profile.confirmationLines
          .map((l) => l.replaceAll('{Product}', productName))
          .toList();
      final profileClosing = profile.closingSentence?.replaceAll('{Product}', productName) ??
          'This NOC is issued upon request for installation and operation of the $productName System.';

      final payload = QgNocPayload(
        companyName: compConfig['company_name'] ?? 'INSIYA TRADING CORPORATION',
        companyAddress: compConfig['company_address'] ?? 'Pune, Maharashtra',
        companyEmail: compConfig['company_email'] ?? 'info@insiyacorp.com',
        companyPhone: compConfig['company_phone'] ?? '+91 9292922992',
        companyWebsite: compConfig['company_website'] ?? 'www.insiyacorp.com',
        customerName: customerName,
        address: siteAddress,
        productName: productName,
        subject: 'No Objection Certificate for Installation & Commissioning of $productName.',
        date: DateTime.now(),
        equipmentLabel: profile.equipmentLabel.isNotEmpty ? profile.equipmentLabel : productName,
        equipmentLines: equipmentLines,
        workType: profile.workTypeText.replaceAll('{Product}', productName),
        wiring: 'Done',
        testing: 'Done',
        remark: 'All Installation & Commissioning work Completed as per work order',
        confirmations: profileConfirmations,
        closingSentence: profileClosing,
        customerSignatureUrl: sigResult.customerSignature,
        customerSignatoryName: sigResult.customerSignatoryName,
        technicianSignatureUrl: sigResult.technicianSignature,
        technicianName: sigResult.technicianName,
        wordingMode: NocWordingMode.templateExact,
        quotationNumber: qData?['quotation_number']?.toString(),
      );

      final pdfBytes = await PdfNocBuilder.buildNocPdf(payload);

      final issuedDoc = await QgNocRepository.finalizeAndIssueNoc(
        dealId: dealId,
        quotationId: qData?['id']?.toString(),
        customerName: customerName,
        siteAddress: siteAddress,
        productName: productName,
        wordingMode: NocWordingMode.templateExact,
        equipmentLines: equipmentLines,
        pdfBytes: pdfBytes,
        companySnapshot: compConfig,
        confirmations: profileConfirmations,
        closingSentence: profileClosing,
        customerSignatureUrl: sigResult.customerSignature,
        customerSignatoryName: sigResult.customerSignatoryName,
        technicianSignatureUrl: sigResult.technicianSignature,
        technicianName: sigResult.technicianName,
        overrideReason: 'Completed deal installation & commissioning verified for $productName',
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _associatedDeal = deal;
          _nocDoc = issuedDoc;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ NOC Certificate issued & verified successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: '${issuedDoc.nocNumber.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating NOC: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPdfActionBusy = false);
      } else {
        _isPdfActionBusy = false;
      }
    }
  }

  void _showPdfLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            elevation: 8,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
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

  Future<void> _viewInstallationPdf(Installation installation) async {
    if (_isPdfActionBusy) return;
    setState(() => _isPdfActionBusy = true);

    _showPdfLoadingDialog('Generating Installation Report...');

    try {
      final pdfBytes =
          await InstallationPdfService.generateCompletionReportPdf(installation);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await Navigator.push(
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
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPdfActionBusy = false);
      } else {
        _isPdfActionBusy = false;
      }
    }
  }

  Future<void> _shareInstallationPdf(Installation installation) async {
    if (_isPdfActionBusy) return;
    setState(() => _isPdfActionBusy = true);

    _showPdfLoadingDialog('Preparing PDF for sharing...');

    try {
      final pdfBytes =
          await InstallationPdfService.generateCompletionReportPdf(installation);
      final safeTicket =
          installation.ticketNumber.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_');
      final filename = 'InstallationReport_$safeTicket.pdf';
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await InstallationPdfService.sharePdfBytes(
        pdfBytes,
        filename,
        'Installation Report for ${installation.ticketNumber}',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPdfActionBusy = false);
      } else {
        _isPdfActionBusy = false;
      }
    }
  }

  Future<void> _previewNoc(QgNocDocument doc) async {
    if (_isPdfActionBusy) return;
    setState(() => _isPdfActionBusy = true);

    _showPdfLoadingDialog('Opening NOC Certificate...');

    try {
      final bytes = await PdfNocBuilder.buildNocPdf(doc.toPayload());
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: bytes,
              fileName: '${doc.nocNumber.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open NOC: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPdfActionBusy = false);
      } else {
        _isPdfActionBusy = false;
      }
    }
  }

  Future<void> _shareNoc(QgNocDocument doc) async {
    if (_isPdfActionBusy) return;
    setState(() => _isPdfActionBusy = true);

    _showPdfLoadingDialog('Preparing NOC for sharing...');

    try {
      final bytes = await PdfNocBuilder.buildNocPdf(doc.toPayload());
      final safeName = '${doc.nocNumber.replaceAll('/', '_')}.pdf';
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await Printing.sharePdf(bytes: bytes, filename: safeName);
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share NOC: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPdfActionBusy = false);
      } else {
        _isPdfActionBusy = false;
      }
    }
  }

  Widget _buildNocSection(Installation installation) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _nocDoc != null ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _nocDoc != null ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _nocDoc != null ? Icons.verified : Icons.assignment_outlined,
                    color: _nocDoc != null ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'No Objection Certificate (NOC)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (_loadingNoc)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_nocDoc != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Unlocked & Issued',
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _nocDoc != null
                ? 'Certificate No: ${_nocDoc!.nocNumber} • Both Customer & Technician signatures verified and printed on certificate.'
                : 'Capture customer & technician signatures to generate the official NOC for this deal.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          if (_nocDoc != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_pin_circle_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Signatory: ${_nocDoc!.customerSignatoryName?.isNotEmpty == true ? _nocDoc!.customerSignatoryName! : _nocDoc!.customerName}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.engineering_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Tech: ${_nocDoc!.technicianName?.isNotEmpty == true ? _nocDoc!.technicianName! : (installation.technicianName ?? 'Technician')}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (_nocDoc != null)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                    label: const Text('Preview NOC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _isPdfActionBusy ? null : () => _previewNoc(_nocDoc!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.share, color: Colors.white, size: 18),
                    label: const Text('Share NOC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _isPdfActionBusy ? null : () => _shareNoc(_nocDoc!),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  onPressed: _isPdfActionBusy ? null : () => _takeNocSignatures(installation),
                  child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.draw_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Take NOC Signatures & Generate',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: _isPdfActionBusy ? null : () => _takeNocSignatures(installation),
              ),
            ),
        ],
      ),
    );
  }
}
