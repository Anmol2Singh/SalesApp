import 'dart:math';
import 'dart:convert';
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
  final _errorCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _uploadedPhotos = []; // mock file paths

  // Step 2 State
  String _generatedProblemCode = '';
  String _warrantyCoverageText = '';

  // Step 3 State
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  // Step 4 State
  final _flatController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _saveAddressFuture = true;

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
    _errorCodeController.dispose();
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
        productId:
            (product.productName.isNotEmpty && product.productName != 'None')
                ? product.productName
                : (product.modelNumber.isNotEmpty
                    ? product.modelNumber
                    : 'IZYHEAT System'),
        problemCode: _generatedProblemCode,
        issueCategory: _errorCodeController.text.trim().isNotEmpty
            ? _errorCodeController.text.trim()
            : 'General Issue',
        issueDescription: _descriptionController.text.trim(),
        photoUrls: List<String>.from(_uploadedPhotos),
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
      final addresses =
          (profile['savedAddresses'] as List?)?.whereType<String>().toList() ??
              [];
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
          ToastService.show(context, 'Loaded saved address',
              type: ToastType.success);
        }
      } else {
        if (mounted) {
          ToastService.show(
              context, 'No saved address found. Please enter address below.',
              type: ToastType.info);
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
          ToastService.show(context, 'Please enable device location services.',
              type: ToastType.warning);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ToastService.show(context, 'Location permissions are denied.',
                type: ToastType.error);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ToastService.show(context,
              'Location permissions are permanently denied. Please enable in Settings.',
              type: ToastType.error);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      try {
        final placemarks = await Geocoding()
            .placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final street = [place.street, place.subLocality]
              .where((s) => s != null && s.trim().isNotEmpty)
              .join(', ');
          final city = place.locality ??
              place.subAdministrativeArea ??
              place.administrativeArea ??
              '';
          final pin = place.postalCode ?? '';

          setState(() {
            if (street.isNotEmpty) _streetController.text = street;
            if (city.isNotEmpty) _cityController.text = city;
            if (pin.isNotEmpty) _pincodeController.text = pin;
          });

          if (mounted) {
            ToastService.show(context, 'Location fetched: $city',
                type: ToastType.success);
          }
          return;
        }
      } catch (_) {}

      // Fallback if reverse geocoding is unavailable
      if (mounted) {
        ToastService.show(context,
            'Coordinates fetched: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
            type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(context, 'Error fetching location: $e',
            type: ToastType.error);
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
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.primary),
                title: const Text('Take Photo (Camera)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhotoFromSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.accent),
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

  static const List<Map<String, String>> diagnosticErrorCodes = [
    {
      'code': 'E01',
      'title': 'No Heating / Low Water Temp',
      'desc': 'Water not reaching desired temperature setpoint'
    },
    {
      'code': 'E02',
      'title': 'Water Leakage Detected',
      'desc': 'Water dripping or pooling near joints, pipes, or valves'
    },
    {
      'code': 'E03',
      'title': 'Low Water Pressure / Flow Fault',
      'desc': 'Inlet water pressure is below operating limit'
    },
    {
      'code': 'E04',
      'title': 'High Pressure Protection (HP)',
      'desc': 'Compressor discharge high pressure safety switch tripped'
    },
    {
      'code': 'E05',
      'title': 'Low Refrigerant / Low Pressure (LP)',
      'desc': 'Refrigerant circuit pressure low or potential leak'
    },
    {
      'code': 'E06',
      'title': 'Water Flow Switch Failure',
      'desc': 'No circulation detected through the heat exchanger'
    },
    {
      'code': 'E07',
      'title': 'Compressor Overload / Overheat',
      'desc': 'Motor thermal overload protector tripped'
    },
    {
      'code': 'E08',
      'title': 'Inlet Water Sensor Fault',
      'desc': 'Inlet temp sensor open, short-circuit, or disconnected'
    },
    {
      'code': 'E09',
      'title': 'Outlet Water Sensor Fault',
      'desc': 'Outlet temp sensor open, short-circuit, or disconnected'
    },
    {
      'code': 'E10',
      'title': 'Ambient Temperature Sensor Fault',
      'desc': 'Outdoor air sensor reading abnormal'
    },
    {
      'code': 'E11',
      'title': 'Evaporator Coil Sensor Fault',
      'desc': 'Defrost / coil temperature sensor open or short'
    },
    {
      'code': 'E12',
      'title': 'Exhaust Gas Sensor Fault',
      'desc': 'Discharge line temperature sensor abnormal'
    },
    {
      'code': 'E13',
      'title': 'Display / PCB Communication Error',
      'desc': 'Communication failure between controller and main board'
    },
    {
      'code': 'E14',
      'title': 'Phase Sequence / Power Fault',
      'desc': 'Reverse phase, missing phase, or abnormal 3-phase power'
    },
    {
      'code': 'E15',
      'title': 'Antifreeze Protection Active',
      'desc': 'Freeze prevention mode engaged in low temperature'
    },
    {
      'code': 'E16',
      'title': 'Fan Motor Abnormal Current',
      'desc': 'Fan motor blocked, overloaded, or damaged'
    },
    {
      'code': 'E17',
      'title': '4-Way Valve Fault (Defrost)',
      'desc': 'Reversing valve malfunction during heating or defrost cycle'
    },
    {
      'code': 'E18',
      'title': 'EEV Valve Fault',
      'desc': 'Electronic expansion valve drive error'
    },
    {
      'code': 'E19',
      'title': 'Supply Voltage Abnormal',
      'desc': 'Voltage is out of safe range (<180V or >260V)'
    },
    {
      'code': 'E20',
      'title': 'Earth Leakage / MCB Tripping',
      'desc': 'Breaker or ELCM trips when power is turned on'
    },
    {
      'code': 'E21',
      'title': 'Abnormal Noise or Vibration',
      'desc': 'Unusual rattle or vibration from compressor or fan'
    },
    {
      'code': 'E99',
      'title': 'Other / General Maintenance',
      'desc': 'General service, descaling, or inspection needed'
    },
  ];

  void _openSearchableErrorCodePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor =
        isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final borderCol = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCodes = diagnosticErrorCodes.where((item) {
              final q = searchQuery.toLowerCase().trim();
              if (q.isEmpty) return true;
              return item['code']!.toLowerCase().contains(q) ||
                  item['title']!.toLowerCase().contains(q) ||
                  item['desc']!.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: contentBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFF59E0B).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.qr_code_2_rounded,
                                  color: Color(0xFFD97706), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Select Error / Diagnostic Code',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: TextField(
                      autofocus: false,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Search by error code or symptom (e.g. E01, leakage, temp)...',
                        hintStyle:
                            TextStyle(color: subtitleColor, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 20, color: Color(0xFFF59E0B)),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  setModalState(() => searchQuery = '');
                                },
                              )
                            : null,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : const Color(0xFFF8FAFC),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFF59E0B), width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() => searchQuery = val);
                      },
                    ),
                  ),
                  const Divider(height: 12),
                  Expanded(
                    child: filteredCodes.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 40, color: subtitleColor),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No matching error code found',
                                    style: TextStyle(
                                        color: subtitleColor,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You can select E99 - Other or describe the issue below',
                                    style: TextStyle(
                                        color: subtitleColor.withOpacity(0.8),
                                        fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            itemCount: filteredCodes.length,
                            separatorBuilder: (_, __) => Divider(
                                height: 1, color: borderCol.withOpacity(0.5)),
                            itemBuilder: (context, idx) {
                              final item = filteredCodes[idx];
                              final isSelected = _errorCodeController.text
                                  .contains(item['code']!);
                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                tileColor: isSelected
                                    ? const Color(0xFFFEF3C7)
                                        .withOpacity(isDark ? 0.2 : 0.6)
                                    : Colors.transparent,
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFF59E0B)
                                        : (isDark
                                            ? Colors.white10
                                            : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item['code']!,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF1E293B)),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item['title']!,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    fontSize: 13.5,
                                    color: textColor,
                                  ),
                                ),
                                subtitle: Text(
                                  item['desc']!,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.5,
                                    color: subtitleColor,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded,
                                        color: Color(0xFFD97706), size: 18)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _errorCodeController.text =
                                        '${item['code']} - ${item['title']}';
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            },
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

  Widget _buildPhotoThumbnail(String url) {
    if (url.startsWith('data:')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(url.substring(commaIdx + 1));
          return Image.memory(bytes, fit: BoxFit.cover, width: 78, height: 78);
        }
      } catch (_) {}
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: 78,
      height: 78,
      errorBuilder: (ctx, err, stack) => const Center(
        child: Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
      ),
    );
  }

  Future<void> _pickPhotoFromSource(ImageSource source) async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(source: source, imageQuality: 70);
      if (image == null) return;

      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final fileExt =
          image.name.contains('.') ? image.name.split('.').last : 'jpg';
      final fileName =
          'complaint_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      String uploadedUrl = '';
      try {
        final supabase = Supabase.instance.client;
        await supabase.storage.from('complaint-photos').uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                contentType: image.mimeType ?? 'image/$fileExt',
                upsert: true,
              ),
            );
        uploadedUrl =
            supabase.storage.from('complaint-photos').getPublicUrl(fileName);
      } catch (storageError) {
        debugPrint(
            'Supabase complaint-photos uploadBinary fallback to data URI: $storageError');
        final base64String = base64Encode(bytes);
        final mime = image.mimeType ?? 'image/jpeg';
        uploadedUrl = 'data:$mime;base64,$base64String';
      }

      setState(() {
        _uploadedPhotos.add(uploadedUrl);
        _isLoading = false;
      });

      if (mounted) {
        ToastService.show(context, 'Photo attached successfully!',
            type: ToastType.success);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastService.show(context, 'Failed to upload photo: $e',
            type: ToastType.error);
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
    final borderCol =
        isDark ? AppColors.borderColor : AppColors.borderColorLight;

    return Container(
      decoration: BoxDecoration(
        color: contentBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
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
    final contentBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final borderCol = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final subtitleColor =
        isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    final stepLabels = [
      'Diagnosis & Symptom',
      'Coverage Details',
      'Service Location'
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: contentBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.handyman_rounded,
                        color: Color(0xFF1E1B4B), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Service',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: textColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Step $_currentStep of 3 • ${stepLabels[_currentStep.clamp(1, 3) - 1]}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor:
                      isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => context.pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Visual Stepper Steps Indicator with labels
          Row(
            children: List.generate(3, (index) {
              final stepNum = index + 1;
              final isCompleted = stepNum < _currentStep;
              final isActive = stepNum == _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : (isActive
                                ? const Color(0xFF1E1B4B)
                                : (isDark
                                    ? Colors.white10
                                    : const Color(0xFFF1F5F9))),
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xFF10B981)
                              : (isActive
                                  ? const Color(0xFFF59E0B)
                                  : borderCol),
                          width: isActive ? 2 : 1,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(0xFF1E1B4B).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : Text(
                                '$stepNum',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isActive ? Colors.white : subtitleColor,
                                ),
                              ),
                      ),
                    ),
                    if (index < 2)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF10B981)
                                : (isDark
                                    ? Colors.white10
                                    : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(2),
                          ),
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
    final contentBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final borderCol = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final subtitleColor =
        isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.heat_pump_rounded,
                  color: Color(0xFF2563EB), size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'Select Affected Product',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                color: textColor,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: contentBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedProductId,
              dropdownColor: contentBg,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B)),
              items: allProducts.map((p) {
                return DropdownMenuItem(
                  value: p.productId,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.solar_power_outlined,
                            size: 16, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${p.productName} (${p.modelNumber})',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedProductId = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_2_rounded,
                  color: Color(0xFFD97706), size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'Diagnostic / Error Code (Optional)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                color: textColor,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _openSearchableErrorCodePicker,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: contentBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _errorCodeController.text.isNotEmpty
                    ? const Color(0xFFF59E0B)
                    : borderCol,
                width: _errorCodeController.text.isNotEmpty ? 1.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded,
                    color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: _errorCodeController.text.isNotEmpty
                      ? Text(
                          _errorCodeController.text,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          'Tap to search & select error code (e.g. E01, E02...)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: subtitleColor,
                            fontSize: 13.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                if (_errorCodeController.text.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _errorCodeController.clear()),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.cancel_rounded,
                          size: 18, color: subtitleColor),
                    ),
                  )
                else
                  Icon(Icons.arrow_drop_down_rounded,
                      color: subtitleColor, size: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_note_rounded,
                  color: Color(0xFF7C3AED), size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'Issue Details',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                color: textColor,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          maxLength: 300,
          style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText:
                'Please describe the problem in detail (e.g. error code shown, noise frequency, leakage quantity)...',
            hintStyle: TextStyle(
                fontFamily: 'Inter', color: subtitleColor, fontSize: 13.5),
            fillColor: contentBg,
            filled: true,
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderCol, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF1E1B4B), width: 1.8),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_a_photo_rounded,
                  color: Color(0xFF059669), size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'Attach Photos (Optional)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                color: textColor,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            InkWell(
              onTap: _showPhotoSourceSheet,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: contentBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFF59E0B),
                    width: 1.5,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFFD97706),
                      size: 26,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Add Photo',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Photo Preview Row
            Expanded(
              child: SizedBox(
                height: 78,
                child: _uploadedPhotos.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.03)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderCol),
                        ),
                        child: Center(
                          child: Text(
                            'Attach photos to help our technicians diagnose quickly',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _uploadedPhotos.length,
                        itemBuilder: (context, idx) => Stack(
                          children: [
                            Container(
                              width: 78,
                              height: 78,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderCol),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child:
                                    _buildPhotoThumbnail(_uploadedPhotos[idx]),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 14,
                              child: InkWell(
                                onTap: () => setState(
                                    () => _uploadedPhotos.removeAt(idx)),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 12),
                                ),
                              ),
                            ),
                          ],
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
    final subtitleColor =
        isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

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
    final borderCol =
        isDark ? AppColors.borderColor : AppColors.borderColorLight;
    final subtitleColor =
        isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

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

        // Location / Map Container
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
          ),
          child: Stack(
            children: [
              // Grid pattern effect
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: GridPaper(
                    color: AppColors.primary,
                    divisions: 1,
                    subdivisions: 1,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.12),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1.5),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Service Dispatch Location',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Technician will be routed to the address below',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                  icon: const Icon(Icons.location_searching,
                      size: 14, color: AppColors.primary),
                  label: const Text(
                    'Get Location',
                    style: TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ),
                TextButton.icon(
                  onPressed: _useSavedAddress,
                  icon: const Icon(Icons.bookmark_outline,
                      size: 14, color: AppColors.accent),
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
    final borderCol =
        isDark ? AppColors.borderColor : AppColors.borderColorLight;
    final subtitleColor =
        isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

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
                    child: const Icon(Icons.person_outline,
                        color: AppColors.primary, size: 20),
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
                      color: product.amcStatus == 'active' ||
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

        GradientButton(
          label: 'View My Bookings',
          onTap: () {
            context.pop();
            context.go('/bookings');
          },
          icon: const Icon(
            Icons.assignment_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildStepperActions(Product selectedProduct) {
    final isNextEnabled = _isStepValid();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentBg = isDark ? AppColors.bgSecondary : Colors.white;
    final borderCol =
        isDark ? AppColors.borderColor : AppColors.borderColorLight;
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
