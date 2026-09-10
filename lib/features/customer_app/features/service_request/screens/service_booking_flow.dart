import 'dart:math';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../features/complaints/providers/complaints_provider.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/shared/widgets/gradient_button.dart';
import 'package:salesapp/features/customer_app/shared/widgets/problem_code_box.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';

class ServiceBookingFlow extends ConsumerStatefulWidget {
  final String? preselectedProductId;

  const ServiceBookingFlow({super.key, this.preselectedProductId});

  @override
  ConsumerState<ServiceBookingFlow> createState() => _ServiceBookingFlowState();
}

class _ServiceBookingFlowState extends ConsumerState<ServiceBookingFlow> {
  int _currentStep = 1;
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Step 1 State
  String? _selectedProductId;
  String _selectedCategory = 'Boiler Not Heating';
  final _descriptionController = TextEditingController();
  final List<String> _uploadedPhotos = []; // mock file paths

  // Step 2 State
  String _generatedProblemCode = '';
  String _warrantyCoverageText = '';

  // Step 3 State
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _bookPreviousTechnician = false;

  // Step 4 State
  final _flatController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _saveAddressFuture = true;

  final List<String> _categories = [
    'Boiler Not Heating',
    'Leak Detected',
    'Thermostat Error',
    'Unusual Noise',
    'No Hot Water',
    'Annual Service',
    'Other',
  ];

  final List<String> _timeSlots = ['08–10 AM', '10–12 PM', '12–2 PM', '2–5 PM'];

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.preselectedProductId;
    _selectedDate = DateTime.now().add(
      const Duration(days: 1),
    ); // Tomorrow default
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _flatController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  // Auto-generate code: IZY-[CATEGORY_PREFIX]-[TIMESTAMP_HASH]-[RANDOM_4DIGITS]
  Future<void> _generateProblemDetails(Product product) async {
    if (_generatedProblemCode.isNotEmpty) return;

    setState(() => _isLoading = true);
    try {
      final ticketNum = await generateNextTicketNumber(ref);
      setState(() {
        _generatedProblemCode = ticketNum;
      });
    } catch (e) {
      setState(() {
        _generatedProblemCode = '#CMP/26-27/${Random().nextInt(9000) + 1000}';
      });
    } finally {
      setState(() => _isLoading = false);
    }

    if (product.amcStatus == 'active') {
      _warrantyCoverageText = 'AMC Active — Priority service guaranteed';
    } else if (product.warrantyExpiryDate.isAfter(DateTime.now())) {
      _warrantyCoverageText = 'Under Warranty — Parts covered at no cost';
    } else {
      _warrantyCoverageText = 'Warranty Expired — Service charges apply';
    }
  }

  Future<void> _submitBooking() async {
    setState(() => _isLoading = true);
    try {
      final products = ref.read(productsProvider).value ?? [];
      final product = products.firstWhere(
        (p) => p.productId == _selectedProductId,
      );

      final newBooking = ServiceRequest(
        requestId: 'req_${Random().nextInt(10000)}',
        customerId: 'mock_user_123',
        productId: (product.productName.isNotEmpty && product.productName != 'None')
            ? product.productName
            : (product.modelNumber.isNotEmpty ? product.modelNumber : 'IZYHEAT System'),
        problemCode: _generatedProblemCode,
        issueCategory: _selectedCategory,
        issueDescription: _descriptionController.text.trim(),
        photoUrls: _uploadedPhotos.isNotEmpty
            ? _uploadedPhotos
            : ['https://images.unsplash.com/photo-1504328345606-18bbc8c9d7d1?w=400'],
        scheduledDate: _selectedDate ?? DateTime.now(),
        timeSlot: _selectedTimeSlot ?? '10–12 PM',
        technicianId: 'tech_1',
        status: 'confirmed',
        warrantyStatus: product.warrantyExpiryDate.isAfter(DateTime.now())
            ? 'Under Warranty'
            : 'Expired',
        amcStatus: product.amcStatus == 'active' ? 'AMC Active' : 'AMC Expired',
        customerLocation: {'latitude': 28.5921, 'longitude': 77.0463},
        customerAddress: {
          'flat': _flatController.text.trim(),
          'street': _streetController.text.trim(),
          'city': _cityController.text.trim(),
          'pincode': _pincodeController.text.trim(),
          'country': 'India',
        },
        createdAt: DateTime.now(),
      );

      await ref
          .read(customerRepositoryProvider)
          .createServiceRequest(newBooking);
      ref.invalidate(serviceRequestsProvider); // refresh list

      setState(() {
        _currentStep = 4; // Go to Confirmation
      });
    } catch (e) {
      if (mounted) {
        ToastService.show(context, e.toString(), type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _useSavedAddress() async {
    setState(() => _isLoading = true);
    try {
      final profile = await ref.read(userProfileProvider.future);
      final addresses = (profile['savedAddresses'] as List?)?.whereType<String>().toList() ?? [];
      if (addresses.isNotEmpty) {
        final firstAddr = addresses.first;
        final parts = firstAddr.split(',');
        setState(() {
          if (parts.length > 1) {
            _flatController.text = parts[0].trim();
            _streetController.text = parts.sublist(1).join(', ').trim();
          } else {
            _streetController.text = firstAddr;
          }
        });
        if (mounted) {
          ToastService.show(context, 'Loaded saved address', type: ToastType.success);
        }
      } else {
        if (mounted) {
          ToastService.show(context, 'No saved address found. Please enter address below.', type: ToastType.info);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ToastService.show(context, 'Please enable device location services.', type: ToastType.warning);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ToastService.show(context, 'Location permissions are denied.', type: ToastType.error);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ToastService.show(context, 'Location permissions are permanently denied. Please enable in Settings.', type: ToastType.error);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final street = [place.street, place.subLocality].where((s) => s != null && s.trim().isNotEmpty).join(', ');
          final city = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? '';
          final pin = place.postalCode ?? '';

          setState(() {
            if (street.isNotEmpty) _streetController.text = street;
            if (city.isNotEmpty) _cityController.text = city;
            if (pin.isNotEmpty) _pincodeController.text = pin;
          });

          if (mounted) {
            ToastService.show(context, 'Location fetched: $city', type: ToastType.success);
          }
          return;
        }
      } catch (_) {}

      // Fallback if reverse geocoding is unavailable
      if (mounted) {
        ToastService.show(context, 'Coordinates fetched: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(context, 'Error fetching location: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: [
              const ListTile(
                title: Text(
                  'Attach Photo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Take Photo (Camera)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhotoFromSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhotoFromSource(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhotoFromSource(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 70);
      if (image == null) return;

      setState(() => _isLoading = true);

      final file = File(image.path);
      final fileExt = image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      final supabase = Supabase.instance.client;
      await supabase.storage.from('complaint-photos').upload(fileName, file);

      final imageUrl = supabase.storage.from('complaint-photos').getPublicUrl(fileName);

      setState(() {
        _uploadedPhotos.add(imageUrl);
        _isLoading = false;
      });

      if (mounted) {
        ToastService.show(context, 'Photo attached successfully!', type: ToastType.success);
      }
    } catch (e) {
      // Fallback
      if (e.toString().contains('403') || e.toString().contains('Unauthorized')) {
        setState(() {
          _uploadedPhotos.add('https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=400');
          _isLoading = false;
        });
        if (mounted) {
          ToastService.show(context, 'Mock mode: using placeholder image', type: ToastType.warning);
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastService.show(context, 'Failed to upload photo: $e', type: ToastType.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? [];

    // Ensure product is selected
    if (_selectedProductId == null && products.isNotEmpty) {
      _selectedProductId = products.first.productId;
    }

    final selectedProduct = products.firstWhere(
      (p) => p.productId == _selectedProductId,
      orElse: () => products.isNotEmpty
          ? products.first
          : Product(
              productId: '',
              productName: 'None',
              modelNumber: '',
              imageUrl: '',
              purchasedDate: DateTime.now(),
              sellerName: '',
              amountPaid: 0,
              currencyCode: '',
              warrantyExpiryDate: DateTime.now(),
              amcStatus: 'none',
              serialNumber: '',
              category: '',
            ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight;
    final contentBg = isDark ? AppColors.bgSecondary : Colors.white;
    final borderCol = isDark ? AppColors.borderColor : AppColors.borderColorLight;

    return Scaffold(
      backgroundColor: scaffoldBg.withOpacity(0.95),
      body: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.08),
        decoration: BoxDecoration(
          color: contentBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(color: borderCol, width: 1),
          ),
        ),
        child: Column(
          children: [
            // Top Stepper Header Bar
            _buildStepperHeader(),

            // Step content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                physics: const BouncingScrollPhysics(),
                child: _buildStepContent(selectedProduct, products),
              ),
            ),

            // Bottom Stepper Actions Row
            if (_currentStep < 5) _buildStepperActions(selectedProduct),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentBg = isDark ? AppColors.bgSecondary : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final borderCol = isDark ? AppColors.borderColor : AppColors.borderColorLight;
    final scaffoldBg = isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: contentBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(color: borderCol, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Request Service',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => context.pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Visual Stepper Steps Indicator
          Row(
            children: List.generate(3, (index) {
              final stepNum = index + 1;
              final isCompleted = stepNum < _currentStep;
              final isActive = stepNum == _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? AppColors.success
                            : (isActive
                                  ? AppColors.primary
                                  : scaffoldBg),
                        border: Border.all(
                          color: isActive
                              ? AppColors.accent
                              : borderCol,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : Text(
                                '$stepNum',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                      ),
                    ),
                    if (index < 2)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted
                              ? AppColors.success
                              : borderCol,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(Product selectedProduct, List<Product> allProducts) {
    switch (_currentStep) {
      case 1:
        return _buildStep1(allProducts);
      case 2:
        return _buildStep2(selectedProduct);
      case 3:
        return _buildStep4();
      case 4:
      default:
        return _buildStep5(selectedProduct);
    }
  }

  // STEP 1: Issue Description
  Widget _buildStep1(List<Product> allProducts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentBg = isDark ? AppColors.bgSecondary : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final borderCol = isDark ? AppColors.borderColor : AppColors.borderColorLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Affected Product',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: contentBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedProductId,
              dropdownColor: contentBg,
              items: allProducts.map((p) {
                return DropdownMenuItem(
                  value: p.productId,
                  child: Text(
                    '${p.productName} (${p.modelNumber})',
                    style: TextStyle(color: textColor),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedProductId = val);
              },
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Select Issue Category',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: AppColors.accent.withOpacity(0.2),
              backgroundColor: contentBg,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.accent : subtitleColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.accent : borderCol,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedCategory = cat);
                }
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        Text(
          'Issue Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: 300,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText:
                'Please describe the problem in detail (e.g. error code shown, noise frequency, leakage quantity)...',
            hintStyle: TextStyle(color: subtitleColor),
            fillColor: contentBg,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Attach Photos (Optional)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            InkWell(
              onTap: _showPhotoSourceSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: contentBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderCol,
                    style: BorderStyle.values[1],
                  ), // Dashed
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Photo Preview Row
            Expanded(
              child: SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _uploadedPhotos.length,
                  itemBuilder: (context, idx) => Container(
                    width: 72,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(_uploadedPhotos[idx]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 2: Problem Code Generation
  Widget _buildStep2(Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    if (_generatedProblemCode.isEmpty) {
      _generateProblemDetails(product);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Problem Code Generated',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We have auto-compiled your diagnostics issue and generated a unique problem reference code.',
          style: TextStyle(color: subtitleColor),
        ),
        const SizedBox(height: 24),

        Text(
          'Your Issue Reference Code',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: subtitleColor.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        ProblemCodeBox(code: _generatedProblemCode),

        const SizedBox(height: 24),

        // Warranty Status Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: product.amcStatus == 'active'
                ? AppColors.success.withOpacity(0.1)
                : (product.warrantyExpiryDate.isAfter(DateTime.now())
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.warning.withOpacity(0.1)),
            border: Border.all(
              color: product.amcStatus == 'active'
                  ? AppColors.success.withOpacity(0.3)
                  : (product.warrantyExpiryDate.isAfter(DateTime.now())
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.warning.withOpacity(0.3)),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                product.amcStatus == 'active'
                    ? Icons.verified
                    : (product.warrantyExpiryDate.isAfter(DateTime.now())
                          ? Icons.verified
                          : Icons.warning_amber_rounded),
                color: product.amcStatus == 'active'
                    ? AppColors.success
                    : (product.warrantyExpiryDate.isAfter(DateTime.now())
                          ? AppColors.success
                          : AppColors.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _warrantyCoverageText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: product.amcStatus == 'active'
                            ? AppColors.success
                            : (product.warrantyExpiryDate.isAfter(
                                    DateTime.now(),
                                  )
                                  ? AppColors.success
                                  : AppColors.warning),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.amcStatus == 'active'
                          ? 'Priority technical dispatch will be applied at zero cost.'
                          : (product.warrantyExpiryDate.isAfter(DateTime.now())
                                ? 'Parts coverage is active under standard manufacturer warranty.'
                                : 'Service call charges and parts costs will apply after repair.'),
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your technical details will be shared directly with your assigned expert to prepare tools beforehand.',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 4: Customer Location Input
  Widget _buildStep4() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentBg = isDark ? AppColors.bgSecondary : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final borderCol = isDark ? AppColors.borderColor : AppColors.borderColorLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm Location',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),

        // Map Placeholder
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: contentBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
            image: const DecorationImage(
              image: NetworkImage(
                'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=600&auto=format&fit=crop',
              ),
              fit: BoxFit.cover,
              opacity: 0.6,
            ),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
              child: const Icon(
                Icons.my_location,
                color: AppColors.accent,
                size: 28,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Street Address',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.location_searching, size: 14, color: AppColors.primary),
                  label: const Text(
                    'Get Location',
                    style: TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ),
                TextButton.icon(
                  onPressed: _useSavedAddress,
                  icon: const Icon(Icons.bookmark_outline, size: 14, color: AppColors.accent),
                  label: const Text(
                    'Use Saved',
                    style: TextStyle(color: AppColors.accent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),

        TextField(
          controller: _flatController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Flat / House / Office Number',
            labelStyle: TextStyle(color: subtitleColor),
            fillColor: contentBg,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _streetController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Street Name & Locality',
            labelStyle: TextStyle(color: subtitleColor),
            fillColor: contentBg,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cityController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'City',
                  labelStyle: TextStyle(color: subtitleColor),
                  fillColor: contentBg,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _pincodeController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Pincode / ZIP',
                  labelStyle: TextStyle(color: subtitleColor),
                  fillColor: contentBg,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: _saveAddressFuture,
              activeColor: AppColors.accent,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _saveAddressFuture = val);
                }
              },
            ),
            Text(
              'Save this address for future bookings',
              style: TextStyle(color: subtitleColor, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep5(Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final borderCol = isDark ? AppColors.borderColor : AppColors.borderColorLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Column(
      children: [
        const SizedBox(height: 12),
        // Success Circle Icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withOpacity(0.12),
            border: Border.all(color: AppColors.success, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withOpacity(0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Booking Confirmed!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your technician visit is scheduled successfully.',
          style: TextStyle(color: subtitleColor),
        ),
        const SizedBox(height: 24),

        // Summary Card
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reference Code',
                    style: TextStyle(color: subtitleColor),
                  ),
                  Text(
                    _generatedProblemCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              Divider(color: borderCol, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scheduled Visit',
                    style: TextStyle(color: subtitleColor),
                  ),
                  Text(
                    'As soon as possible',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Divider(color: borderCol, height: 24),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned Technician',
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Technician will be allotted shortly',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Pending Assignment',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(color: borderCol, height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Address',
                    style: TextStyle(color: subtitleColor),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      '${_flatController.text}, ${_streetController.text}, ${_cityController.text}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              Divider(color: borderCol, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Coverage status',
                    style: TextStyle(color: subtitleColor),
                  ),
                  Text(
                    product.amcStatus == 'active'
                        ? 'AMC COVERED'
                        : (product.warrantyExpiryDate.isAfter(DateTime.now())
                              ? 'WARRANTY COVERED'
                              : 'PAID SERVICE'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          product.amcStatus == 'active' ||
                              product.warrantyExpiryDate.isAfter(DateTime.now())
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: GradientButton(
                label: 'Track Technician',
                onTap: () {
                  context.pop();
                  context.go('/track');
                },
                icon: const Icon(
                  Icons.location_searching,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderCol),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton(
                  onPressed: () {
                    context.pop();
                    context.go('/bookings');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(
                      'View My Bookings',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isDark ? Colors.white : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepperActions(Product selectedProduct) {
    final isNextEnabled = _isStepValid();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentBg = isDark ? AppColors.bgSecondary : Colors.white;
    final borderCol = isDark ? AppColors.borderColor : AppColors.borderColorLight;
    final buttonIconColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: contentBg,
        border: Border(
          top: BorderSide(color: borderCol, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 1) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderCol),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: buttonIconColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: GradientButton(
                label: _currentStep == 3 ? 'Confirm & Book Visit' : 'Next Step',
                isLoading: _isLoading,
                onTap: isNextEnabled
                    ? () async {
                        if (_currentStep == 3) {
                          _submitBooking();
                        } else {
                          if (_currentStep == 1) {
                            await _generateProblemDetails(selectedProduct);
                          }
                          setState(() {
                            _currentStep++;
                          });
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isStepValid() {
    switch (_currentStep) {
      case 1:
        return _selectedProductId != null &&
            _descriptionController.text.trim().isNotEmpty;
      case 2:
        return true;
      case 3:
        return _flatController.text.trim().isNotEmpty &&
            _streetController.text.trim().isNotEmpty &&
            _cityController.text.trim().isNotEmpty;
      default:
        return true;
    }
  }
}
