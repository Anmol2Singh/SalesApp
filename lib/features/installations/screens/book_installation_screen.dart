// lib/features/installations/screens/book_installation_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../providers/installations_provider.dart';
import '../data/models/installation_model.dart';
import '../../complaints/providers/complaints_provider.dart'
    show availableTechniciansProvider;
import '../../complaints/data/models/complaint_model.dart' show TechnicianInfo;
import '../../../features/customers/providers/customers_provider.dart';
import '../../../core/models/customer.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/searchable_dropdown.dart';

import '../../../core/models/pipeline.dart';

class BookInstallationScreen extends ConsumerStatefulWidget {
  const BookInstallationScreen({super.key});

  @override
  ConsumerState<BookInstallationScreen> createState() =>
      _BookInstallationScreenState();
}

class _BookInstallationScreenState
    extends ConsumerState<BookInstallationScreen> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  final _sealNumberBeforeController = TextEditingController();
  final _mobileController = TextEditingController();
  String _selectedPriority = 'High Priority';
  bool _isSubmitting = false;

  Customer? _selectedCustomer;
  TechnicianInfo? _selectedTechnician;
  String? _selectedProduct;
  List<Map<String, dynamic>> _customerCompletedDeals = [];
  Map<String, dynamic>? _selectedDeal;
  List<TechnicianInfo> _selectedSupporters = [];
  final List<String> _sitePhotosBase64 = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _sealNumberBeforeController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _onCustomerSelected(Customer customer) async {
    setState(() {
      _selectedCustomer = customer;
      _addressController.text = customer.address ?? '';
      _mobileController.text = customer.phone ?? '';
      _customerCompletedDeals = [];
      _selectedDeal = null;
      _selectedProduct = null;
    });

    final supabase = ref.read(supabaseClientProvider);
    try {
      final res = await supabase.from('sales_pipelines').select('''
        *,
        customers(*),
        products(id, name, category),
        profiles!sales_pipelines_created_by_fkey(id, full_name),
        quotations(id, status, line_items),
        sales_orders(id, status),
        boqs(id, status),
        factory_orders(id, status),
        purchase_orders(id, status)
      ''').eq('customer_id', customer.id);
      
      if (mounted) {
        final pipelines = (res as List).map((p) => SalesPipeline.fromJson(p as Map<String, dynamic>)).toList();
        final completedDeals = pipelines
            .where((p) => p.currentStep == PipelineStep.completed || p.status == PipelineStatus.completed)
            .map((p) {
              return {
                'id': p.id,
                'products': p.product != null ? {'name': p.product!.name, 'id': p.product!.id} : null,
                'quotations': p.quotation != null ? [{'items': p.quotation!.lineItems.map((i) => i.toJson()).toList()}] : [],
              };
            })
            .toList();

        setState(() {
          _customerCompletedDeals = completedDeals;
        });
      }
    } catch (e) {
      debugPrint('Error fetching completed deals: $e');
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Site Photo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: Color(0xFF0284C7)),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickSitePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF0284C7)),
              title: const Text('Choose Photos from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickSitePhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSitePhoto(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> photos =
            await _picker.pickMultiImage(imageQuality: 70);
        if (photos.isNotEmpty) {
          for (final photo in photos) {
            final bytes = await photo.readAsBytes();
            final base64Str = base64Encode(bytes);
            _sitePhotosBase64.add('data:image/jpeg;base64,$base64Str');
          }
          setState(() {});
        }
      } else {
        final XFile? photo =
            await _picker.pickImage(source: source, imageQuality: 70);
        if (photo != null) {
          final bytes = await photo.readAsBytes();
          final base64Str = base64Encode(bytes);
          setState(() {
            _sitePhotosBase64.add('data:image/jpeg;base64,$base64Str');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _submitInstallation() async {
    final profile = ref.read(currentProfileProvider);
    final isTech = profile?.primaryRole == UserRole.technician;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first')),
      );
      return;
    }

    if (_selectedDeal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a completed deal/product first')),
      );
      return;
    }

    if (isTech && profile != null) {
      _selectedTechnician = TechnicianInfo(
        id: profile.id,
        name: profile.fullName,
        avatarUrl: '',
        status: 'Available',
        distance: '0km',
        activeTasksCount: 0,
        rating: 4.9,
      );
    }

    if (_selectedTechnician == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please assign a technician before scheduling the installation.')),
      );
      return;
    }

    String title = 'Installation for ${_selectedCustomer!.companyName}';
    if (_selectedDeal != null) {
      final prodName = _selectedDeal!['products']?['name'] ?? 'System';
      title = 'Installation: $prodName';
      _selectedProduct = prodName;
    }

    String supportersStr = _selectedSupporters.isNotEmpty 
        ? 'Supporters: ${_selectedSupporters.map((s) => s.name).join(", ")}'
        : '';
    String finalNotes = supportersStr;
    if (_selectedDeal != null) {
      if (finalNotes.isNotEmpty) finalNotes += '\n';
      finalNotes += 'Deal ID: ${_selectedDeal!['id']}';
    }

    setState(() => _isSubmitting = true);

    List<String> finalUrls = [];
    try {
      final supabase = ref.read(supabaseClientProvider);
      finalUrls = await StorageService.uploadMultipleImages(
        supabase: supabase,
        base64OrPaths: _sitePhotosBase64,
        folder: 'installation_photos',
      );
    } catch (_) {}

    final ticketNum = await generateNextInstallationTicketNumber(ref);
    final updatedAddress = _addressController.text.trim().isEmpty
        ? (_selectedCustomer!.address ?? '')
        : _addressController.text.trim();

    final newInstallation = Installation(
      id: const Uuid().v4(),
      ticketNumber: ticketNum,
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.companyName,
      customerPhone: _selectedCustomer!.phone ?? '',
      customerAddress: updatedAddress,
      productName: _selectedProduct,
      priority: _selectedPriority,
      title: title,
      description: _descController.text.trim(),
      status: 'assigned',
      technicianId: _selectedTechnician!.id,
      technicianName: _selectedTechnician!.name,
      technicianAvatarUrl: _selectedTechnician!.avatarUrl,
      tatRemaining: '48h',
      beforeImageUrl: finalUrls.isNotEmpty ? finalUrls.join('|||') : null,
      sealNumberBefore: _sealNumberBeforeController.text.trim().isNotEmpty
          ? _sealNumberBeforeController.text.trim()
          : null,
      source: 'staff',
      notes: finalNotes.isNotEmpty ? finalNotes : null,
      createdAt: DateTime.now(),
    );

    try {
      await ref
          .read(installationsProvider.notifier)
          .addInstallation(newInstallation);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Installation $ticketNum created successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking installation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(serviceCustomersNotifierProvider);
    final techniciansAsync = ref.watch(availableTechniciansProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Schedule Installation',
          style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Selector Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                      ),
                    ),
                    const SizedBox(height: 12),
                    customersAsync.when(
                      data: (customers) {
                        return SearchableDropdown<Customer>(
                          label: 'Customer',
                          hint: 'Select Customer',
                          value: _selectedCustomer,
                          items: customers,
                          itemLabel: (c) => c.companyName,
                          onChanged: (c) {
                            if (c != null) _onCustomerSelected(c);
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading customers: $e'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Site Address',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            if (_selectedCustomer != null) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Installation Product',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_customerCompletedDeals.isEmpty)
                        const Text('No completed deals found for this customer.', style: TextStyle(color: Colors.grey))
                      else
                        DropdownButtonFormField<Map<String, dynamic>>(
                          decoration: const InputDecoration(
                            labelText: 'Select Deal / Product',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          value: _selectedDeal,
                          items: _customerCompletedDeals.map((deal) {
                            final productName = deal['products']?['name'] ?? 'Unknown Product';
                            return DropdownMenuItem(
                              value: deal,
                              child: Text(productName),
                            );
                          }).toList(),
                          onChanged: (deal) {
                            setState(() {
                              _selectedDeal = deal;
                            });
                          },
                        ),
                      if (_selectedDeal != null) ...[
                        const SizedBox(height: 16),
                        const Text('Quotation Items (from Deal)', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ...((_selectedDeal?['quotations'] as List?)?.isNotEmpty == true && (_selectedDeal?['quotations'][0]['items'] != null)
                            ? ((_selectedDeal!['quotations'][0]['items'] as List).map((item) {
                                final desc = item['description'] ?? 'Item';
                                final qty = item['qty']?.toString() ?? '1';
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(desc.toString(), style: const TextStyle(fontSize: 14)),
                                  trailing: Text('Qty: $qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                );
                              }).toList())
                            : [const Text('No items found in quotation.', style: TextStyle(color: Colors.grey, fontSize: 13))]),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Installation Details Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Installation Details',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Scope / Technical Notes',
                        hintText: 'e.g. Structure erection, panel wiring, inverter setup',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPriority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: ['High Priority', 'Medium Priority', 'Low Priority']
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedPriority = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _sealNumberBeforeController,
                            decoration: const InputDecoration(
                              labelText: 'Initial Seal # (Optional)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Technician Assignment Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assign Technician *',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    techniciansAsync.when(
                      data: (technicians) {
                        return DropdownButtonFormField<TechnicianInfo>(
                          value: _selectedTechnician,
                          hint: const Text('Select Installer / Technician'),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: technicians
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t.name),
                                  ))
                              .toList(),
                          onChanged: (t) => setState(() => _selectedTechnician = t),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading technicians: $e'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Supporter(s) (Optional)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    techniciansAsync.when(
                      data: (technicians) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedSupporters.map((t) {
                                  return Chip(
                                    label: Text(t.name),
                                    deleteIcon: const Icon(Icons.close, size: 16),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedSupporters.remove(t);
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14B8A6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return StatefulBuilder(
                                      builder: (context, setStateDialog) {
                                        return AlertDialog(
                                          title: const Text('Add Supporters'),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            child: ListView(
                                              shrinkWrap: true,
                                              children: technicians
                                                  .where((t) => t != _selectedTechnician)
                                                  .map((t) {
                                                final isSelected = _selectedSupporters.contains(t);
                                                return CheckboxListTile(
                                                  title: Text(t.name),
                                                  value: isSelected,
                                                  activeColor: const Color(0xFF14B8A6),
                                                  onChanged: (val) {
                                                    setStateDialog(() {
                                                      if (val == true) {
                                                        _selectedSupporters.add(t);
                                                      } else {
                                                        _selectedSupporters.remove(t);
                                                      }
                                                    });
                                                    setState(() {});
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Done', style: TextStyle(color: Color(0xFF14B8A6))),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Site Photos
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                          'Pre-installation Site Photos',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showPhotoSourceSheet,
                          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                          label: const Text('Add Photo'),
                        ),
                      ],
                    ),
                    if (_sitePhotosBase64.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _sitePhotosBase64.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final str = _sitePhotosBase64[idx];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(str.substring(str.indexOf(',') + 1)),
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _sitePhotosBase64.removeAt(idx));
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _submitInstallation,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Installation',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
