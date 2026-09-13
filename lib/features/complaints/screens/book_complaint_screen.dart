import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../providers/complaints_provider.dart';
import '../data/models/complaint_model.dart';
import '../../../features/customers/providers/customers_provider.dart';
import '../../../core/models/customer.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/searchable_dropdown.dart';

class BookComplaintScreen extends ConsumerStatefulWidget {
  const BookComplaintScreen({super.key});

  @override
  ConsumerState<BookComplaintScreen> createState() => _BookComplaintScreenState();
}

class _BookComplaintScreenState extends ConsumerState<BookComplaintScreen> {
  int _currentStep = 0;
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  final _sealNumberBeforeController = TextEditingController();
  String _selectedPriority = 'High Priority';
  String? _selectedReplacementReason;
  String? _selectedErrorCode;
  String? _selectedErrorDesc;
  final List<String> _replacementReasons = [
    'Voltage issue',
    'System Warranty over',
    'Other person serviced the system',
  ];
  bool _isSubmitting = false;

  Customer? _selectedCustomer;
  TechnicianInfo? _selectedTechnician;
  final List<String> _selectedProducts = [];
  final List<String> _issuePhotosBase64 = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _sealNumberBeforeController.dispose();
    super.dispose();
  }

  void _onCustomerSelected(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _addressController.text = customer.address ?? '';
    });
  }

  void _showImagePreviewDialog(String imageStr) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageStr.startsWith('http')
                    ? Image.network(imageStr, fit: BoxFit.contain)
                    : Image.memory(
                        base64Decode(imageStr.substring(imageStr.indexOf(',') + 1)),
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
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
            const Text('Add Issue Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF6D28D9)),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickIssuePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF6D28D9)),
              title: const Text('Choose Photos from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickIssuePhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickIssuePhoto(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> photos = await _picker.pickMultiImage(imageQuality: 70);
        if (photos.isNotEmpty) {
          for (final photo in photos) {
            final bytes = await photo.readAsBytes();
            final base64Str = base64Encode(bytes);
            _issuePhotosBase64.add('data:image/jpeg;base64,$base64Str');
          }
          setState(() {});
        }
      } else {
        final XFile? photo = await _picker.pickImage(source: source, imageQuality: 70);
        if (photo != null) {
          final bytes = await photo.readAsBytes();
          final base64Str = base64Encode(bytes);
          setState(() {
            _issuePhotosBase64.add('data:image/jpeg;base64,$base64Str');
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

  void _submitComplaint() async {
    final profile = ref.read(currentProfileProvider);
    final isTech = profile?.primaryRole == UserRole.technician;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first')),
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
        const SnackBar(content: Text('Please assign a technician before booking the complaint.')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Complaint Title (Compulsory)')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    List<String> finalUrls = [];
    try {
      final supabase = ref.read(supabaseClientProvider);
      finalUrls = await StorageService.uploadMultipleImages(
        supabase: supabase,
        base64OrPaths: _issuePhotosBase64,
        folder: 'issue_photos',
      );
    } catch (_) {}

    final ticketNum = await generateNextTicketNumber(ref);
    final chosenProduct = _selectedProducts.isNotEmpty ? _selectedProducts.first : null;
    final fullTitle = chosenProduct != null
        ? '$chosenProduct - ${_titleController.text.trim()}'
        : _titleController.text.trim();

    final baseDesc = _descController.text.trim();
    final fullDescription = _selectedReplacementReason != null
        ? 'Reason for part replacement: $_selectedReplacementReason\n\n$baseDesc'
        : baseDesc;

    final updatedAddress = _addressController.text.trim().isEmpty
        ? (_selectedCustomer!.address ?? '')
        : _addressController.text.trim();

    // Cross-sync address to customers table if changed
    try {
      if (updatedAddress.isNotEmpty && updatedAddress != _selectedCustomer!.address) {
        final supabase = ref.read(supabaseClientProvider);
        await supabase.from('customers').update({
          'address': updatedAddress,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _selectedCustomer!.id);
        ref.invalidate(customersNotifierProvider);
      }
    } catch (_) {}

    final newComplaint = Complaint(
      id: Uuid().v4(),
      ticketNumber: ticketNum,
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.companyName,
      customerPhone: _selectedCustomer!.phone ?? '',
      customerAddress: updatedAddress,
      productName: chosenProduct,
      hasActiveAmc: true,
      amcExpiry: 'Active Contract',
      priority: _selectedPriority,
      title: fullTitle,
      description: fullDescription,
      status: 'assigned',
      source: (profile?.primaryRole == UserRole.customer) ? 'customer' : 'staff',
      technicianId: _selectedTechnician!.id,
      technicianName: _selectedTechnician!.name,
      tatRemaining: '24h TAT',
      beforeImageUrl: finalUrls.isNotEmpty ? finalUrls.join('|||') : null,
      errorCode: _selectedErrorCode,
      errorDescription: _selectedErrorDesc,
      sealNumberBefore: _sealNumberBeforeController.text.trim().isEmpty
          ? null
          : _sealNumberBeforeController.text.trim(),
      createdAt: DateTime.now(),
    );

    await ref.read(complaintsProvider.notifier).addComplaint(newComplaint);

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complaint ${newComplaint.ticketNumber} booked successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Book New Complaint',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6D28D9),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Stepper Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              color: const Color(0xFF6D28D9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStepCircle(0, 'Customer'),
                  _buildStepLine(0),
                  _buildStepCircle(1, 'Issue Details'),
                  _buildStepLine(1),
                  _buildStepCircle(2, 'Submit'),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildCurrentStepContent(customersAsync),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_currentStep > 0)
              OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                child: const Text('Back'),
              ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_currentStep == 0 && _selectedCustomer == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a customer from the list')),
                        );
                        return;
                      }
                      if (_currentStep == 1 && _titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Complaint Title is required')),
                        );
                        return;
                      }
                      if (_currentStep < 2) {
                        setState(() => _currentStep++);
                      } else {
                        _submitComplaint();
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _currentStep == 2 ? 'Confirm & Book Ticket' : 'Next Step',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isDone = _currentStep > step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isCurrent ? Colors.white : (isDone ? const Color(0xFF10B981) : Colors.white30),
          child: isDone
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '${step + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? const Color(0xFF6D28D9) : Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: isCurrent ? Colors.white : Colors.white70,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: _currentStep > step ? const Color(0xFF10B981) : Colors.white30,
      ),
    );
  }

  Widget _buildCurrentStepContent(AsyncValue<List<Customer>> customersAsync) {
    if (_currentStep == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Customer from Customers List',
            style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search customer companyName or phone...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          customersAsync.when(
            data: (customers) {
              final query = _searchController.text.toLowerCase();
              final filtered = customers.where((c) {
                return c.companyName.toLowerCase().contains(query) || (c.phone?.contains(query) ?? false);
              }).toList();

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text('No matching customers found in Customers section.'),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final customer = filtered[index];
                  final isSelected = _selectedCustomer?.id == customer.id;

                  return GestureDetector(
                    onTap: () => _onCustomerSelected(customer),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6D28D9) : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isSelected ? const Color(0xFF6D28D9) : Colors.grey.shade200,
                            child: Text(
                              customer.companyName.substring(0, 1).toUpperCase(),
                              style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customer.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                if (customer.phone != null) Text(customer.phone!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                if (customer.address != null) Text(customer.address!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF6D28D9)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9))),
            error: (e, _) => Text('Failed to load customers: $e'),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      final productsAsync = ref.watch(productsListProvider);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Issue Details', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Products List from Products Table
          const Text('Select Purchased Product with Issue:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          productsAsync.when(
            data: (productsList) {
              if (productsList.isEmpty) {
                return const Text('No products available in database.', style: TextStyle(color: Colors.grey, fontSize: 12));
              }
              return Wrap(
                spacing: 8,
                children: productsList.map((p) {
                  final isSelected = _selectedProducts.contains(p);
                  return FilterChip(
                    label: Text(p),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6D28D9),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedProducts.clear();
                          _selectedProducts.add(p);
                        } else {
                          _selectedProducts.remove(p);
                        }
                      });
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9))),
            error: (e, _) => Text('Error loading products: $e'),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Complaint Title / Category *',
              hintText: 'e.g. Heating failure, Pressure Leak, Inverter Error',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          // Searchable Error Code Dropdown
          Builder(
            builder: (context) {
              final errorCodes = ref.watch(errorCodesProvider);
              return SearchableDropdown<ErrorCodeItem>(
                label: 'Error Code (Optional)',
                value: _selectedErrorCode != null
                    ? errorCodes.cast<ErrorCodeItem?>().firstWhere((e) => e?.code == _selectedErrorCode, orElse: () => null)
                    : null,
                items: errorCodes,
                itemLabel: (e) => '${e.code} - ${e.description}',
                onChanged: (item) {
                  setState(() {
                    _selectedErrorCode = item?.code;
                    _selectedErrorDesc = item?.description;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Error Code (Optional)',
                  hintText: 'Search or select error code (e.g. E01)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.code_rounded, color: Color(0xFF6D28D9)),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Seal Number (Before Service)
          TextField(
            controller: _sealNumberBeforeController,
            decoration: InputDecoration(
              labelText: 'Seal Number (Before Service) - Optional',
              hintText: 'e.g. SL-9042',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6D28D9)),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedReplacementReason,
            decoration: InputDecoration(
              labelText: 'Reason for Part Replacement',
              hintText: 'Select reason if replacement required',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.build_circle_outlined, color: Color(0xFF6D28D9)),
            ),
            items: _replacementReasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (val) {
              setState(() => _selectedReplacementReason = val);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Detailed Problem Description',
              hintText: 'Describe error codes, symptoms or customer notes...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Issue Photos Picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Issue Photos (${_issuePhotosBase64.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_issuePhotosBase64.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                  label: const Text('Add More'),
                  onPressed: _showPhotoSourceSheet,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_issuePhotosBase64.isEmpty) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6D28D9),
                side: const BorderSide(color: Color(0xFF6D28D9)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_a_photo_outlined, size: 20),
              label: const Text('Add Issue Photos (Camera / Gallery)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _showPhotoSourceSheet,
            ),
          ] else ...[
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _issuePhotosBase64.length + 1,
                itemBuilder: (context, idx) {
                  if (idx == _issuePhotosBase64.length) {
                    return InkWell(
                      onTap: _showPhotoSourceSheet,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF6D28D9).withOpacity(0.3)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: Color(0xFF6D28D9), size: 24),
                            SizedBox(height: 4),
                            Text('Add More', style: TextStyle(color: Color(0xFF6D28D9), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  }

                  final photoStr = _issuePhotosBase64[idx];
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _showImagePreviewDialog(photoStr),
                        child: Container(
                          width: 100,
                          height: 100,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: photoStr.startsWith('http')
                                ? Image.network(photoStr, fit: BoxFit.cover)
                                : Image.memory(
                                    base64Decode(photoStr.substring(photoStr.indexOf(',') + 1)),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => setState(() => _issuePhotosBase64.removeAt(idx)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),

          const Text('Priority Level', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['High Priority', 'Medium Priority', 'Low Priority'].map((p) {
              final isSelected = _selectedPriority == p;
              return ChoiceChip(
                label: Text(p),
                selected: isSelected,
                selectedColor: const Color(0xFF6D28D9),
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                onSelected: (val) {
                  if (val) setState(() => _selectedPriority = p);
                },
              );
            }).toList(),
          ),
        ],
      );
    } else {
      final profile = ref.watch(currentProfileProvider);
      final isTech = profile?.primaryRole == UserRole.technician;

      if (isTech && profile != null && _selectedTechnician == null) {
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

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Address & Service Location', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Auto-fetched from customer profile. Edit below if service is at a different address:',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Service Location Address',
              hintText: 'Enter address...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          if (isTech) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF6D28D9).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6D28D9).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFF6D28D9)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Technician Direct Booking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6D28D9))),
                        Text('Assigned automatically to you (${profile?.fullName ?? "Technician"}).', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text('Assign Technician (Required) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ref.watch(availableTechniciansProvider).when(
              data: (techs) {
                if (techs.isEmpty) {
                  return const Text('No technicians found. Please add a technician in Technicians section.', style: TextStyle(color: Colors.red, fontSize: 12));
                }
                return SearchableDropdown<TechnicianInfo>(
                  label: 'Select Technician for Dispatch *',
                  value: _selectedTechnician,
                  items: techs,
                  itemLabel: (t) => '${t.name} (${t.status})',
                  itemSubtitle: (t) => t.phone != null ? 'Phone: ${t.phone}' : null,
                  onChanged: (val) {
                    setState(() => _selectedTechnician = val);
                  },
                  decoration: InputDecoration(
                    labelText: 'Select Technician for Dispatch *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9))),
              error: (e, _) => Text('Error loading technicians: $e'),
            ),
          ],

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Complaint Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Divider(),
                Text('Customer: ${_selectedCustomer?.companyName ?? "-"}'),
                Text('Phone: ${_selectedCustomer?.phone ?? "-"}'),
                Text('Address: ${_addressController.text}'),
                Text('Assigned Tech: ${_selectedTechnician?.name ?? "Not Selected"}'),
                Text('Selected Products: ${_selectedProducts.isEmpty ? "All Products" : _selectedProducts.join(", ")}'),
                Text('Priority: $_selectedPriority'),
                Text('Issue: ${_titleController.text.isEmpty ? "General Service Request" : _titleController.text}'),
              ],
            ),
          ),
        ],
      );
    }
  }
}
