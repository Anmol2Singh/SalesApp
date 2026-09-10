// lib/features/complaints/screens/complaint_details_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../data/models/complaint_model.dart';
import '../data/models/complaint_part_order.dart';
import '../providers/complaints_provider.dart';
import '../providers/part_orders_provider.dart';
import '../services/complaint_pdf_service.dart';
import '../widgets/signature_pad_widget.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/admin/providers/inventory_provider.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/models/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/providers/supabase_provider.dart';

class ComplaintDetailsScreen extends ConsumerStatefulWidget {
  final String complaintId;

  const ComplaintDetailsScreen({super.key, required this.complaintId});

  @override
  ConsumerState<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends ConsumerState<ComplaintDetailsScreen> {
  final ImagePicker _picker = ImagePicker();

  Widget _buildImage(String url, {double? height, double? width, BoxFit fit = BoxFit.cover}) {
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
      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 40),
    );
  }

  Widget _buildPhotoList(String? urlsString, {bool canRemove = false, required Complaint complaint}) {
    if (urlsString == null || urlsString.isEmpty) return const SizedBox.shrink();
    final urls = urlsString.split('|||').where((e) => e.trim().isNotEmpty).toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        itemBuilder: (context, index) {
          final url = urls[index].trim();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _showImagePreviewDialog(context, url),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12, top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildImage(url, height: 112, width: 120, fit: BoxFit.cover),
                  ),
                ),
              ),
              if (canRemove)
                Positioned(
                  top: 0,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(complaintsProvider.notifier).removeAfterPhoto(complaint.id, index);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showImagePreviewDialog(BuildContext context, String imageStr) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 400),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  child: imageStr.startsWith('http')
                      ? _buildImage(imageStr, fit: BoxFit.contain)
                      : Image.memory(
                          base64Decode(imageStr.contains('base64,') ? imageStr.split('base64,').last : imageStr),
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _launchMaps(String address) async {
    final query = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps')),
        );
      }
    }
  }

  Future<void> _makeCall(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showAfterPhotoSourceSheet(Complaint complaint) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select After-Solve Photo Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF6D28D9)),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAfterPhoto(complaint, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF6D28D9)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAfterPhoto(complaint, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAfterPhoto(Complaint complaint, ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(source: source, imageQuality: 70);
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final base64Str = base64Encode(bytes);
        final dataUrl = 'data:image/jpeg;base64,$base64Str';
        
        final supabase = ref.read(supabaseClientProvider);
        final publicUrl = await StorageService.uploadImage(
          supabase: supabase,
          base64OrPath: dataUrl,
          folder: 'after_photos',
        );

        if (publicUrl != null) {
          await ref.read(complaintsProvider.notifier).updateAfterPhoto(complaint.id, publicUrl);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('After-solve photo uploaded successfully!'), backgroundColor: Color(0xFF10B981)),
            );
          }
        } else {
          throw Exception('Failed to upload image to storage');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  Future<void> _takeSignature(Complaint complaint) async {
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
          await ref.read(complaintsProvider.notifier).saveCustomerSignature(complaint.id, publicUrl);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Customer signature saved successfully!'), backgroundColor: Color(0xFF10B981)),
            );
          }
        } else {
          throw Exception('Failed to upload signature to storage');
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

  Future<void> _takeTechnicianSignature(Complaint complaint) async {
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
          await ref.read(complaintsProvider.notifier).saveTechnicianSignature(complaint.id, publicUrl);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Technician signature saved successfully!'), backgroundColor: Color(0xFF10B981)),
            );
          }
        } else {
          throw Exception('Failed to upload technician signature to storage');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving technician signature: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _confirmDeleteComplaint(BuildContext context, WidgetRef ref, Complaint complaint) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Complaint?'),
        content: Text('Are you sure you want to permanently delete ticket ${complaint.ticketNumber}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(complaintsProvider.notifier).deleteComplaint(complaint.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Complaint ${complaint.ticketNumber} deleted.'), backgroundColor: AppColors.error),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _showReassignModal(Complaint complaint, List<TechnicianInfo> technicians) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign Technician for ${complaint.ticketNumber}',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (technicians.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No technician staff profiles found.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: technicians.length,
                    itemBuilder: (context, idx) {
                      final tech = technicians[idx];
                      return ListTile(
                        leading: CircleAvatar(child: Text(tech.name.substring(0, 1).toUpperCase())),
                        title: Text(tech.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(tech.status),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
                          onPressed: () {
                            ref.read(complaintsProvider.notifier).assignTechnician(complaint.id, tech);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Assigned to ${tech.name}!'), backgroundColor: const Color(0xFF10B981)),
                            );
                          },
                          child: const Text('Assign', style: TextStyle(color: Colors.white)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatProductName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'IZYHEAT Solar System';
    }
    final trimmed = name.trim();
    if (trimmed.length > 25 && RegExp(r'^[0-9a-fA-F\-]+$').hasMatch(trimmed)) {
      return 'IZYHEAT Solar System';
    }
    return trimmed;
  }

  Future<DateTime> _getCustomerPurchaseDate(String customerId) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final wc = await supabase
          .from('warranty_cards')
          .select('start_date')
          .eq('customer_id', customerId)
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (wc != null && wc['start_date'] != null) {
        final parsed = DateTime.tryParse(wc['start_date']);
        if (parsed != null) return parsed;
      }
    } catch (_) {}

    try {
      final pipe = await supabase
          .from('sales_pipelines')
          .select('created_at')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (pipe != null && pipe['created_at'] != null) {
        final parsed = DateTime.tryParse(pipe['created_at']);
        if (parsed != null) return parsed;
      }
    } catch (_) {}

    return DateTime.now().subtract(const Duration(days: 60));
  }

  void _showAddDefectedPartsDialog(Complaint complaint) async {
    final inventoryItems = ref.read(inventoryProvider).valueOrNull ?? [];
    if (inventoryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory catalog is loading or empty.'), backgroundColor: Colors.orange),
      );
      return;
    }

    DateTime purchaseDate = await _getCustomerPurchaseDate(complaint.customerId);
    final profile = ref.read(currentProfileProvider);
    final String techName = profile?.fullName ?? 'Technician';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        InventoryItem? selectedItem = inventoryItems.isNotEmpty ? inventoryItems.first : null;
        int qty = 1;
        final reasonController = TextEditingController();
        List<Map<String, dynamic>> orderItems = [];
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            double calculateItemPrice(InventoryItem item) {
              final expiry = purchaseDate.add(Duration(days: item.warrantyMonths * 30));
              final inWarranty = DateTime.now().isBefore(expiry);
              return inWarranty ? 0.0 : item.price;
            }

            bool checkItemWarranty(InventoryItem item) {
              final expiry = purchaseDate.add(Duration(days: item.warrantyMonths * 30));
              return DateTime.now().isBefore(expiry);
            }

            final currentInWarranty = selectedItem != null ? checkItemWarranty(selectedItem!) : false;
            final currentItemPrice = selectedItem != null ? calculateItemPrice(selectedItem!) : 0.0;
            final grandTotal = orderItems.fold<double>(0.0, (sum, i) => sum + ((i['total_price'] as num?)?.toDouble() ?? 0.0));

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFF6D28D9).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.build_circle_outlined, color: Color(0xFF6D28D9), size: 24),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Defected Item & Replacement Order', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('Order genuine parts from company inventory', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Customer Purchase Date & Warranty Basis Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF475569)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Customer Purchase Date: ${DateFormat('dd MMM yyyy').format(purchaseDate)}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: purchaseDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setModalState(() => purchaseDate = picked);
                            }
                          },
                          child: const Text('Change', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Item Selection & Warranty Check Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Defected Item from Inventory', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<InventoryItem>(
                          isExpanded: true,
                          value: selectedItem,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: inventoryItems.map((item) {
                            return DropdownMenuItem<InventoryItem>(
                              value: item,
                              child: Text(item.itemName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (item) {
                            if (item != null) setModalState(() => selectedItem = item);
                          },
                        ),
                        const SizedBox(height: 10),

                        // Warranty indicator banner for selected item
                        if (selectedItem != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: currentInWarranty ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: currentInWarranty ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  currentInWarranty ? Icons.verified_user : Icons.warning_amber_rounded,
                                  color: currentInWarranty ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentInWarranty
                                            ? 'UNDER WARRANTY (Free Replacement - ₹0)'
                                            : 'OUT OF WARRANTY (Chargeable to Customer)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: currentInWarranty ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                      Text(
                                        'Warranty period: ${selectedItem!.warrantyMonths} months | Catalog price: ₹${selectedItem!.price.toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: reasonController,
                                decoration: InputDecoration(
                                  labelText: 'Defect Reason / Fault',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                                  onPressed: qty > 1 ? () => setModalState(() => qty--) : null,
                                ),
                                Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 22),
                                  onPressed: () => setModalState(() => qty++),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D28D9),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: selectedItem == null
                                  ? null
                                  : () {
                                      final itemPrice = currentItemPrice;
                                      final totalPrice = itemPrice * qty;
                                      setModalState(() {
                                        orderItems.add({
                                          'item_name': selectedItem!.itemName,
                                          'inventory_id': selectedItem!.id,
                                          'quantity': qty,
                                          'unit_price': itemPrice,
                                          'total_price': totalPrice,
                                          'is_warranty': currentInWarranty,
                                          'warranty_months': selectedItem!.warrantyMonths,
                                          'reason': reasonController.text.trim().isEmpty ? 'Defected part replaced' : reasonController.text.trim(),
                                        });
                                        qty = 1;
                                        reasonController.clear();
                                      });
                                    },
                              child: const Text('+ Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Added Items List
                  const Text('Items to Order:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: orderItems.isEmpty
                        ? Center(
                            child: Text('No defected items added yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          )
                        : ListView.separated(
                            itemCount: orderItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final item = orderItems[idx];
                              final inWar = item['is_warranty'] as bool;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('Qty: ${item['quantity']} | ${item['reason']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          const SizedBox(height: 2),
                                          Text(
                                            inWar ? 'FREE under Warranty' : '₹${(item['total_price'] as num).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: inWar ? const Color(0xFF059669) : const Color(0xFFB91C1C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => setModalState(() => orderItems.removeAt(idx)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Grand Total & Submit Order Button
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Cost to Customer:', style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                            Text(
                              grandTotal <= 0 ? '₹0.00 (Warranty Covered)' : '₹${grandTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: grandTotal <= 0 ? const Color(0xFF059669) : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D28D9),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          label: const Text('Place Order to Company', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: (orderItems.isEmpty || isSubmitting)
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    await ref.read(partOrdersServiceProvider).createPartOrder(
                                      complaintId: complaint.id,
                                      customerId: complaint.customerId.isNotEmpty ? complaint.customerId : null,
                                      customerName: complaint.customerName,
                                      items: orderItems,
                                      totalAmount: grandTotal,
                                      isWarranty: grandTotal <= 0,
                                      createdBy: techName,
                                    );
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(grandTotal <= 0
                                              ? 'Defected item order submitted! Covered under warranty.'
                                              : 'Defected item order submitted! Total: ₹${grandTotal.toStringAsFixed(2)} - Sent to customer for payment.'),
                                          backgroundColor: const Color(0xFF10B981),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  } finally {
                                    if (ctx.mounted) setModalState(() => isSubmitting = false);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPartOrdersSection(Complaint complaint, bool canOrder) {
    final partOrdersAsync = ref.watch(partOrdersForComplaintProvider(complaint.id));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: Color(0xFF6D28D9), size: 20),
                  SizedBox(width: 8),
                  Text('Defected Parts & Orders', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              if (canOrder)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Order Parts', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddDefectedPartsDialog(complaint),
                ),
            ],
          ),
          const Divider(height: 20),
          partOrdersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.grey.shade400, size: 18),
                      const SizedBox(width: 8),
                      Text('No replacement parts ordered for this ticket.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final ord = orders[idx];
                  Color statusColor = const Color(0xFFF59E0B);
                  String statusText = 'Payment Pending';
                  IconData statusIcon = Icons.pending_actions;

                  if (ord.paymentStatus == 'paid') {
                    statusColor = const Color(0xFF10B981);
                    statusText = 'Paid ✓ (Replaced)';
                    statusIcon = Icons.check_circle;
                  } else if (ord.paymentStatus == 'not_required' || ord.isWarranty) {
                    statusColor = const Color(0xFF059669);
                    statusText = 'Free Warranty Replacement ✓';
                    statusIcon = Icons.verified;
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${ord.id.substring(0, 8).toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, color: statusColor, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusText,
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...ord.items.map((item) {
                          final isWar = (item['is_warranty'] as bool?) ?? false;
                          final price = (item['total_price'] as num?)?.toDouble() ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '• ${item['item_name']} (x${item['quantity']}) - ${item['reason'] ?? ''}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  isWar ? '₹0 (Warranty)' : '₹${price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isWar ? const Color(0xFF059669) : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Placed: ${DateFormat('dd MMM, hh:mm a').format(ord.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            Text(
                              'Total: ₹${ord.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading part orders: $err', style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final complaints = ref.watch(complaintsProvider);
    final profile = ref.watch(currentProfileProvider);
    final techniciansAsync = ref.watch(availableTechniciansProvider);

    final complaint = complaints.firstWhere(
      (c) => c.id == widget.complaintId,
      orElse: () => Complaint(
        id: widget.complaintId,
        ticketNumber: '#CMP-000',
        customerId: '',
        customerName: 'Unknown Customer',
        customerPhone: '',
        customerAddress: '',
        priority: 'Medium Priority',
        title: 'Service Request',
        description: '',
        tatRemaining: '24h',
        createdAt: DateTime.now(),
      ),
    );

    final isAdminOrCoordinator = profile?.primaryRole == UserRole.admin || profile?.primaryRole == UserRole.serviceHead;
    final isTechnician = profile?.primaryRole == UserRole.technician;
    final isClosed = complaint.status == 'closed';
    final hasCustomerSignature = complaint.customerSignatureUrl != null && complaint.customerSignatureUrl!.isNotEmpty;
    final hasTechSignature = complaint.technicianSignatureUrl != null && complaint.technicianSignatureUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              complaint.ticketNumber,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              _formatProductName(complaint.productName),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6D28D9),
        elevation: 0,
        actions: [
          if (profile?.primaryRole == UserRole.admin || profile?.primaryRole == UserRole.manager)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Delete Complaint (Admin Only)',
              onPressed: () => _confirmDeleteComplaint(context, ref, complaint),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Priority Banner
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(complaint.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  backgroundColor: isClosed ? const Color(0xFF10B981) : const Color(0xFF6D28D9),
                ),
                Chip(
                  label: Text(complaint.priority, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                  backgroundColor: Colors.red.shade50,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF6D28D9)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          complaint.customerName,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (complaint.customerPhone.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.phone, color: Color(0xFF10B981)),
                          onPressed: () => _makeCall(complaint.customerPhone),
                        ),
                    ],
                  ),
                  const Divider(),
                  Text('Mobile: ${complaint.customerPhone}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Address: ${complaint.customerAddress}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4C1D95),
                        side: const BorderSide(color: Color(0xFF6D28D9)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Navigate in Google Maps', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _launchMaps(complaint.customerAddress),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Issue & Product Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Issue & Product Details', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _detailRow('Product Name', _formatProductName(complaint.productName)),
                  _detailRow('Issue Category', complaint.title),
                  _detailRow('Description', complaint.description.isNotEmpty ? complaint.description : 'No additional notes.'),
                  if (complaint.beforeImageUrl != null && complaint.beforeImageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Issue Photos (${complaint.beforeImageUrl!.split('|||').length}):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: complaint.beforeImageUrl!.split('|||').length,
                        itemBuilder: (context, idx) {
                          final photoStr = complaint.beforeImageUrl!.split('|||')[idx].trim();
                          Widget imgWidget;
                          if (photoStr.startsWith('http')) {
                            imgWidget = _buildImage(photoStr, fit: BoxFit.cover);
                          } else {
                            try {
                              final cleanBase64 = photoStr.contains('base64,') ? photoStr.split('base64,').last : photoStr;
                              imgWidget = Image.memory(base64Decode(cleanBase64), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40));
                            } catch (_) {
                              imgWidget = const Icon(Icons.image, size: 40);
                            }
                          }
                          return GestureDetector(
                            onTap: () => _showImagePreviewDialog(context, photoStr),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 110,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: imgWidget,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Technician Assignment Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Assigned Technician', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold)),
                      if (isAdminOrCoordinator && !isClosed)
                        TextButton.icon(
                          icon: const Icon(Icons.swap_horiz, size: 16),
                          label: Text(complaint.technicianName != null ? 'Reassign' : 'Assign Tech'),
                          onPressed: () {
                            techniciansAsync.whenData((list) => _showReassignModal(complaint, list));
                          },
                        ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF6D28D9).withOpacity(0.1),
                        child: const Icon(Icons.person, color: Color(0xFF6D28D9)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(complaint.technicianName ?? 'Unassigned', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(complaint.technicianId != null ? 'Assigned Field Staff' : 'Pending dispatch', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Defected Parts & Replacement Orders Section
            _buildPartOrdersSection(complaint, (!isClosed && (isTechnician || isAdminOrCoordinator))),
            const SizedBox(height: 20),

            // Admin / Coordinator Action Panel
            if (isAdminOrCoordinator && complaint.status == 'resolved') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Admin Actions', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('Approve & Close Complaint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ref.read(complaintsProvider.notifier).approveComplaint(complaint.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Complaint approved and closed.'), backgroundColor: Color(0xFF10B981)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Technician Action Panel (ONLY Visible to Technician role)
            if (!isClosed && isTechnician) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF6D28D9).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Service Resolution Actions', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      label: const Text(
                        'Upload After-Solve Photo(s)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showAfterPhotoSourceSheet(complaint),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasTechSignature ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(hasTechSignature ? Icons.check_circle : Icons.draw_outlined, color: Colors.white, size: 18),
                      label: Text(
                        hasTechSignature ? 'Technician Signature Captured ✓' : 'Take Technician Signature',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _takeTechnicianSignature(complaint),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasCustomerSignature ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(hasCustomerSignature ? Icons.check_circle : Icons.draw_outlined, color: Colors.white, size: 18),
                      label: Text(
                        hasCustomerSignature ? 'Customer Signature Captured ✓' : 'Take Customer Signature',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _takeSignature(complaint),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (hasCustomerSignature || hasTechSignature) ? const Color(0xFF10B981) : Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.task_alt, color: Colors.white),
                        label: const Text('Mark Resolution Submitted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        onPressed: (hasCustomerSignature || hasTechSignature)
                            ? () async {
                                await ref.read(complaintsProvider.notifier).completeComplaint(complaint.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Resolution submitted! Pending Service Head approval.'), backgroundColor: Color(0xFF10B981)),
                                  );
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (complaint.beforeImageUrl != null || complaint.afterImageUrl != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (complaint.beforeImageUrl != null && complaint.beforeImageUrl!.isNotEmpty) ...[
                      const Text('BEFORE ISSUE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                      const SizedBox(height: 4),
                      _buildPhotoList(complaint.beforeImageUrl, complaint: complaint),
                      const SizedBox(height: 16),
                    ],
                    if (complaint.afterImageUrl != null && complaint.afterImageUrl!.isNotEmpty) ...[
                      const Text('AFTER ISSUE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      const SizedBox(height: 4),
                      _buildPhotoList(complaint.afterImageUrl, canRemove: !isClosed && isTechnician, complaint: complaint),
                    ],
                  ],
                ),
              ),
            ],

            // Service Head / Admin Approval Panel (When complaint is marked done by Tech)
            if (complaint.status == 'pending_approval' && isAdminOrCoordinator) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.hourglass_top, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('Resolution Submitted by Technician', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Technician has resolved issue and captured customer signature. Click below to approve and close complaint.', style: TextStyle(fontSize: 12, color: Colors.black87)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('Approve & Mark Completed Permanently', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () async {
                          await ref.read(complaintsProvider.notifier).approveComplaint(complaint.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Complaint approved & permanently closed!'), backgroundColor: Color(0xFF10B981)),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Completion Report PDF Action Panel (When Closed)
            if (isClosed) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text('Service Completion Report', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Official report generated with customer signature confirmation.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                            label: const Text('View PDF', style: TextStyle(color: Colors.white)),
                            onPressed: () async {
                              final pdfBytes = await ComplaintPdfService.generateCompletionReportPdf(complaint);
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => PdfPreviewScreen(pdfBytes: pdfBytes, fileName: 'CompletionReport_${complaint.ticketNumber}.pdf'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                            icon: const Icon(Icons.share, color: Colors.white, size: 18),
                            label: const Text('Share PDF', style: TextStyle(color: Colors.white)),
                            onPressed: () => ComplaintPdfService.shareCompletionReport(complaint),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}
