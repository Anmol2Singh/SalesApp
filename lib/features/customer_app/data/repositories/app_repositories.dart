import 'dart:async';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthRepository {
  Stream<String?> get authStateChanges;
  String? get currentUid;
  Future<void> sendOtp(String phone);
  Future<bool> verifyOtp(String otp);
  Future<void> logout();
  Future<Map<String, dynamic>> getUserProfile();
  Future<void> updateProfile({
    required String name,
    required String email,
    required List<String> addresses,
  });
}

abstract class CustomerRepository {
  Future<List<Product>> getProducts();
  Future<List<Product>> getAdvertisementProducts();
  Future<List<ServiceRequest>> getServiceRequests();
  Future<List<Invoice>> getInvoices();
  Future<Technician> getTechnician(String techId);
  Stream<Technician> listenToTechnicianLocation(String techId);
  Future<List<SupportTicket>> getSupportTickets();
  Future<void> createServiceRequest(ServiceRequest request);
  Future<void> createSupportTicket(SupportTicket ticket);
  Future<void> addSupportMessage(String ticketId, String text, bool isUser);
  Future<void> payInvoice(String invoiceId);
  Future<void> renewAmc(String productId);
  Future<void> requestAmc({required String packageTitle, String? productId});
  Future<void> requestAmcService({required String productId, String? pipelineId});
  Future<List<Map<String, dynamic>>> getActivityLogs();
}

class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>.broadcast();
  String? _uid;
  String? _pendingPhone;

  @override
  Stream<String?> get authStateChanges {
    final controller = StreamController<String?>();
    controller.add(_uid);

    final subscription = _controller.stream.listen(
      (val) => controller.add(val),
      onError: (err) => controller.addError(err),
      onDone: () => controller.close(),
    );

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  @override
  String? get currentUid => _uid;

  @override
  Future<void> sendOtp(String phone) async {
    _pendingPhone = phone;
    await Future.delayed(const Duration(seconds: 1)); // Simulate delay
  }

  @override
  Future<bool> verifyOtp(String otp) async {
    await Future.delayed(const Duration(milliseconds: 1500)); // Simulate delay
    if (otp == '123456' ||
        _pendingPhone == '+919999999999' ||
        _pendingPhone == '9999999999') {
      _uid = 'mock_user_123';
      _controller.add(_uid);
      return true;
    }
    throw Exception('Invalid OTP entered. Please try again.');
  }

  @override
  Future<void> logout() async {
    _uid = null;
    _pendingPhone = null;
    _controller.add(null);
  }

  @override
  Future<Map<String, dynamic>> getUserProfile() async {
    return {
      'name': 'Jane Doe',
      'phone': _pendingPhone ?? '+91 99999 99999',
      'email': 'jane.doe@example.com',
      'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/svg?seed=Jane',
      'savedAddresses': [
        'Flat 402, Radiant Heights, Sector 15, Dwarka, Delhi - 110075',
        'IZYHEAT Office, Block B, Industrial Area Phase I, Noida - 201301',
      ],
      'preferenceSettings': {'push': true, 'sms': true, 'email': false},
    };
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String email,
    required List<String> addresses,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
  }
}

class MockCustomerRepository implements CustomerRepository {
  final List<Product> _products = [
    Product(
      productId: 'prod_1',
      productName: 'IZYSmart Eco Boiler',
      modelNumber: 'IZY-BLR-800X',
      imageUrl:
          'assets/images/boiler_placeholder.jpg', // Local fallback or network URL
      purchasedDate: DateTime.now().subtract(const Duration(days: 365)),
      sellerName: 'Northern HVAC Distributors Ltd',
      amountPaid: 1850.00,
      currencyCode: 'USD',
      warrantyExpiryDate: DateTime.now().add(const Duration(days: 365)),
      amcStatus: 'active',
      amcExpiryDate: DateTime.now().add(const Duration(days: 120)),
      serialNumber: 'SN-BLR800-98319',
      category: 'boiler',
    ),
    Product(
      productId: 'prod_2',
      productName: 'IZYFlow Heat Pump',
      modelNumber: 'IZY-HP-500e',
      imageUrl: 'assets/images/heatpump_placeholder.jpg',
      purchasedDate: DateTime.now().subtract(const Duration(days: 800)),
      sellerName: 'Apex Solar Solutions',
      amountPaid: 3200.00,
      currencyCode: 'USD',
      warrantyExpiryDate: DateTime.now().subtract(const Duration(days: 70)),
      amcStatus: 'expired',
      amcExpiryDate: DateTime.now().subtract(const Duration(days: 15)),
      serialNumber: 'SN-HP500-24108',
      category: 'heat_pump',
    ),
    Product(
      productId: 'prod_3',
      productName: 'IZYTemp Smart Thermostat',
      modelNumber: 'IZY-THR-10',
      imageUrl: 'assets/images/thermostat_placeholder.jpg',
      purchasedDate: DateTime.now().subtract(const Duration(days: 120)),
      sellerName: 'IZYHEAT Store Delhi',
      amountPaid: 249.99,
      currencyCode: 'USD',
      warrantyExpiryDate: DateTime.now().add(const Duration(days: 610)),
      amcStatus: 'none',
      serialNumber: 'SN-THR10-754123',
      category: 'thermostat',
    ),
  ];

  final List<ServiceRequest> _requests = [
    ServiceRequest(
      requestId: 'req_101',
      customerId: 'mock_user_123',
      productId: 'prod_1',
      problemCode: 'IZY-BLR-20260601-3829',
      issueCategory: 'Annual Service',
      issueDescription:
          'Scheduled annual preventative maintenance contract checkup.',
      photoUrls: [],
      scheduledDate: DateTime.now().subtract(const Duration(days: 35)),
      timeSlot: '10–12 PM',
      technicianId: 'tech_1',
      status: 'completed',
      warrantyStatus: 'Under Warranty',
      amcStatus: 'AMC Active',
      customerLocation: {'latitude': 28.5921, 'longitude': 77.0463},
      customerAddress: {
        'flat': 'Flat 402, Radiant Heights',
        'street': 'Sector 15, Dwarka',
        'city': 'Delhi',
        'pincode': '110075',
        'country': 'India',
      },
      createdAt: DateTime.now().subtract(const Duration(days: 36)),
    ),
    ServiceRequest(
      requestId: 'req_102',
      customerId: 'mock_user_123',
      productId: 'prod_2',
      problemCode: 'IZY-HP-20260707-4821',
      issueCategory: 'Leak Detected',
      issueDescription:
          'There is water dripping from the main outer radiator valve unit.',
      photoUrls: [
        'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=400',
      ],
      scheduledDate: DateTime.now(), // Today
      timeSlot: '2–5 PM',
      technicianId: 'tech_1',
      status: 'in_progress', // Active tracking!
      warrantyStatus: 'Warranty Expired',
      amcStatus: 'AMC Expired',
      customerLocation: {'latitude': 28.5921, 'longitude': 77.0463},
      customerAddress: {
        'flat': 'Flat 402, Radiant Heights',
        'street': 'Sector 15, Dwarka',
        'city': 'Delhi',
        'pincode': '110075',
        'country': 'India',
      },
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  final List<Invoice> _invoices = [
    Invoice(
      invoiceId: 'inv_201',
      customerId: 'mock_user_123',
      requestId: 'req_101',
      title: 'Annual Service Maintenance Contract',
      date: DateTime.now().subtract(const Duration(days: 35)),
      dueDate: DateTime.now().subtract(const Duration(days: 20)),
      amount: 150.00,
      status: 'paid',
      lineItems: [
        {'name': 'Preventative Service Labor', 'qty': 1, 'price': 100.00},
        {'name': 'HVAC Filter Replacements', 'qty': 2, 'price': 25.00},
      ],
    ),
    Invoice(
      invoiceId: 'inv_202',
      customerId: 'mock_user_123',
      requestId: 'req_102',
      title: 'Boiler Pipe Leak Repair',
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 15)),
      amount: 285.50,
      status: 'unpaid',
      lineItems: [
        {'name': 'Emergency Call-out charge', 'qty': 1, 'price': 75.00},
        {'name': 'Valve and Gasket Seal Kits', 'qty': 1, 'price': 60.50},
        {'name': 'Copper Pipe & Welding Labor', 'qty': 1, 'price': 150.00},
      ],
    ),
  ];

  final List<SupportTicket> _tickets = [
    SupportTicket(
      ticketId: 'tkt_301',
      customerId: 'mock_user_123',
      subject: 'Pressure drops on eco boiler',
      description:
          'The pressure gauge drops from 2 bar to 0.5 bar daily even after manual refill.',
      status: 'open',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      messages: [
        {
          'sender': 'user',
          'text': 'The pressure drops constantly. Should I turn it off?',
          'timestamp': DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
        },
        {
          'sender': 'agent',
          'text':
              'Hello Jane. Please check if there are any visual leaks under the radiator valves. We have registered a ticket, and an agent will call you shortly.',
          'timestamp': DateTime.now()
              .subtract(const Duration(days: 2, hours: 23))
              .toIso8601String(),
        },
      ],
    ),
  ];

  final Technician _mockTech = Technician(
    techId: 'tech_1',
    name: 'Marcus Vance',
    phone: '+919876543210',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Marcus',
    vehicleInfo: 'Ford Transit - TX9082',
    rating: 4.8,
    currentLocation: {
      'latitude': 28.6015,
      'longitude': 77.0392,
    }, // Near Dwarka Sector 15
    isOnline: true,
  );

  @override
  Future<List<Product>> getProducts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _products;
  }

  @override
  Future<List<Product>> getAdvertisementProducts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Product(
        productId: 'adv_1',
        productName: 'IZYRadiator Plus',
        modelNumber: 'IZY-RAD-V1',
        imageUrl: 'assets/images/radiator_placeholder.jpg',
        purchasedDate: DateTime.now(),
        sellerName: 'IZYHEAT Store',
        amountPaid: 450.00,
        currencyCode: 'INR',
        warrantyExpiryDate: DateTime.now(),
        amcStatus: 'none',
        serialNumber: 'SN-RAD-001',
        category: 'radiator',
      ),
    ];
  }

  @override
  Future<List<ServiceRequest>> getServiceRequests() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _requests;
  }

  @override
  Future<List<Invoice>> getInvoices() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _invoices;
  }

  @override
  Future<Technician> getTechnician(String techId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockTech;
  }

  @override
  Stream<Technician> listenToTechnicianLocation(String techId) {
    // Return a stream that updates technician location slowly towards customer location (28.5921, 77.0463)
    double customerLat = 28.5921;
    double customerLng = 77.0463;
    double startLat = 28.6045;
    double startLng = 77.0315;

    int step = 0;
    const maxSteps = 12;

    return Stream.periodic(const Duration(seconds: 8), (count) {
      step = (count % maxSteps);
      double fraction = step / (maxSteps - 1);
      double currentLat = startLat + (customerLat - startLat) * fraction;
      double currentLng = startLng + (customerLng - startLng) * fraction;

      return Technician(
        techId: _mockTech.techId,
        name: _mockTech.name,
        phone: _mockTech.phone,
        avatarUrl: _mockTech.avatarUrl,
        vehicleInfo: _mockTech.vehicleInfo,
        rating: _mockTech.rating,
        currentLocation: {'latitude': currentLat, 'longitude': currentLng},
        isOnline: true,
      );
    }).asBroadcastStream();
  }

  @override
  Future<List<SupportTicket>> getSupportTickets() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _tickets;
  }

  @override
  Future<void> createServiceRequest(ServiceRequest request) async {
    await Future.delayed(const Duration(seconds: 1));
    _requests.add(request);
  }

  @override
  Future<void> createSupportTicket(SupportTicket ticket) async {
    await Future.delayed(const Duration(seconds: 1));
    _tickets.add(ticket);
  }

  @override
  Future<void> addSupportMessage(
    String ticketId,
    String text,
    bool isUser,
  ) async {
    final ticket = _tickets.firstWhere((t) => t.ticketId == ticketId);
    ticket.messages.add({
      'sender': isUser ? 'user' : 'agent',
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> payInvoice(String invoiceId) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final index = _invoices.indexWhere((inv) => inv.invoiceId == invoiceId);
    if (index != -1) {
      _invoices[index] = _invoices[index].copyWith(status: 'paid');
    }
  }

  @override
  Future<void> renewAmc(String productId) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final index = _products.indexWhere((prod) => prod.productId == productId);
    if (index != -1) {
      final p = _products[index];
      _products[index] = Product(
        productId: p.productId,
        productName: p.productName,
        modelNumber: p.modelNumber,
        imageUrl: p.imageUrl,
        purchasedDate: p.purchasedDate,
        sellerName: p.sellerName,
        amountPaid: p.amountPaid,
        currencyCode: p.currencyCode,
        warrantyExpiryDate: p.warrantyExpiryDate,
        amcStatus: 'active',
        amcExpiryDate: DateTime.now().add(const Duration(days: 365)),
        serialNumber: p.serialNumber,
        category: p.category,
      );
    }
  }

  @override
  Future<void> requestAmc({required String packageTitle, String? productId}) async {
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Future<void> requestAmcService({required String productId, String? pipelineId}) async {
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  @override
  Future<List<Map<String, dynamic>>> getActivityLogs() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {
        'id': 'log_1',
        'customer_id': 'mock_user_123',
        'event_type': 'booking_created',
        'title': 'Service Visit Scheduled',
        'body': 'Your visit for Annual Boiler Tune-up is booked.',
        'created_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      },
      {
        'id': 'log_2',
        'customer_id': 'mock_user_123',
        'event_type': 'invoice_paid',
        'title': 'Invoice Paid',
        'body': 'Your payment for invoice was processed.',
        'created_at': DateTime.now().subtract(const Duration(days: 35)).toIso8601String(),
      }
    ];
  }
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _pendingPhone;
  bool _isMockMode = false;
  String? _mockUid;
  final _mockAuthStateController = StreamController<String?>.broadcast();

  static String? loggedInPhone;

  SupabaseAuthRepository() {
    _initPersistentSession();
  }

  Future<void> _initPersistentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUid = prefs.getString('customer_session_uid');
      final savedPhone = prefs.getString('customer_session_phone');
      if (savedUid != null && savedUid.isNotEmpty) {
        _mockUid = savedUid;
        _pendingPhone = savedPhone;
        loggedInPhone = savedPhone;
        _isMockMode = true;
        _mockAuthStateController.add(_mockUid);
      }
    } catch (_) {}
  }

  @override
  Stream<String?> get authStateChanges {
    final controller = StreamController<String?>();
    
    controller.add(_isMockMode ? _mockUid : _supabase.auth.currentUser?.id);

    final listener = _supabase.auth.onAuthStateChange.listen((data) {
      if (!_isMockMode) {
        controller.add(data.session?.user.id);
      }
    }, onError: (_) {
      // Gracefully ignore offline/DNS network errors on auth stream
    });

    final mockListener = _mockAuthStateController.stream.listen((uid) {
      controller.add(uid);
    });

    controller.onCancel = () {
      listener.cancel();
      mockListener.cancel();
    };

    return controller.stream;
  }

  @override
  String? get currentUid => _isMockMode ? _mockUid : _supabase.auth.currentUser?.id;

  @override
  Future<void> sendOtp(String phone) async {
    _pendingPhone = phone;
    loggedInPhone = phone;
    try {
      await _supabase.auth.signInWithOtp(phone: phone);
      _isMockMode = false;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains("phone_provider_disabled") || errStr.contains("Unsupported phone provider")) {
        print("Supabase phone provider is disabled. Falling back to local mock authentication.");
        _isMockMode = true;
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<bool> verifyOtp(String otp) async {
    if (_pendingPhone == null) {
      throw Exception('Phone number not set. Please request OTP again.');
    }
    if (_isMockMode) {
      if (otp == '123456' || otp.length == 6) {
        _mockUid = 'mock-user-${_pendingPhone!.replaceAll(RegExp(r'\D'), '')}';
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('customer_session_uid', _mockUid!);
          if (_pendingPhone != null) {
            await prefs.setString('customer_session_phone', _pendingPhone!);
          }
        } catch (_) {}
        _mockAuthStateController.add(_mockUid);
        return true;
      }
      return false;
    }
    final response = await _supabase.auth.verifyOTP(
      phone: _pendingPhone!,
      token: otp,
      type: OtpType.sms,
    );
    return response.user != null;
  }

  @override
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('customer_session_uid');
      await prefs.remove('customer_session_phone');
    } catch (_) {}
    if (_isMockMode) {
      _mockUid = null;
      _pendingPhone = null;
      loggedInPhone = null;
      _mockAuthStateController.add(null);
    } else {
      await _supabase.auth.signOut();
    }
  }

  @override
  Future<Map<String, dynamic>> getUserProfile() async {
    final uid = currentUid;
    if (uid == null) return {};

    String cleanPhone = _pendingPhone ?? _supabase.auth.currentUser?.phone ?? '';
    if (cleanPhone.isEmpty && uid.startsWith('mock-user-')) {
      cleanPhone = uid.replaceAll('mock-user-', '');
    }
    final cleanDigits = cleanPhone.replaceAll(RegExp(r'\D'), '');
    final last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;

    if (cleanDigits.isNotEmpty) {
      try {
        final customerResult = await _supabase
            .from('customers')
            .select()
            .or('phone.eq.$cleanPhone,phone.eq.$cleanDigits,phone.ilike.%$last10')
            .limit(1);

        if (customerResult.isNotEmpty) {
          final customer = customerResult.first;
          final name = customer['customer_name'] ?? customer['contact_person'] ?? 'Customer';
          return {
            'name': name,
            'phone': customer['phone'] ?? cleanPhone,
            'email': customer['email'] ?? '',
            'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/svg?seed=${name.replaceAll(' ', '')}',
            'savedAddresses': [customer['address'] ?? ''].where((addr) => (addr as String).isNotEmpty).toList(),
            'preferenceSettings': {'push': true, 'sms': true, 'email': false},
          };
        }
      } catch (_) {}
    }

    if (_isMockMode || uid.startsWith('mock-user-')) {
      try {
        final response = await _supabase
            .from('customer_profiles')
            .select();
        
        for (final row in response as List) {
          final rowPhone = (row['phone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
          if (rowPhone.isNotEmpty && (rowPhone == cleanDigits || cleanDigits.endsWith(rowPhone) || rowPhone.endsWith(cleanDigits))) {
            return {
              'name': row['full_name'] ?? 'Customer',
              'phone': row['phone'] ?? cleanPhone,
              'email': row['email'] ?? '',
              'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/svg?seed=${(row['full_name'] ?? 'Jane').replaceAll(' ', '')}',
              'savedAddresses': [],
              'preferenceSettings': {'push': true, 'sms': true, 'email': false},
            };
          }
        }
      } catch (_) {}

      return {
        'name': 'Customer',
        'phone': cleanPhone,
        'email': '',
        'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/svg?seed=Customer',
        'savedAddresses': [],
        'preferenceSettings': {'push': true, 'sms': true, 'email': false},
      };
    }

    var response = await _supabase
        .from('customer_profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (response == null) {
      response = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
    }

    final fullName = response?['full_name'] ?? 'Customer';
    final pPhone = response?['phone'] ?? _pendingPhone ?? '';
    final pEmail = response?['email'] ?? '';

    return {
      'name': fullName,
      'phone': pPhone,
      'email': pEmail,
      'avatarUrl':
          'https://api.dicebear.com/7.x/adventurer/svg?seed=${fullName.replaceAll(' ', '')}',
      'savedAddresses': [],
      'preferenceSettings': {'push': true, 'sms': true, 'email': false},
    };
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String email,
    required List<String> addresses,
  }) async {
    final uid = currentUid;
    if (uid == null) return;

    if (_isMockMode || uid.startsWith('mock-user-')) {
      return;
    }

    try {
      await _supabase
          .from('customer_profiles')
          .update({'full_name': name, 'email': email})
          .eq('id', uid);
    } catch (_) {
      try {
        await _supabase
            .from('profiles')
            .update({'full_name': name, 'email': email})
            .eq('id', uid);
      } catch (_) {}
    }
  }
}

class SupabaseCustomerRepository implements CustomerRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> _resolveCustomerId() async {
    // 1. Check customer portal session phone first
    String? phone = SupabaseAuthRepository.loggedInPhone;
    String? email;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('customer_session_phone');
      final savedUid = prefs.getString('customer_session_uid');
      if (savedPhone != null && savedPhone.isNotEmpty) {
        phone = savedPhone;
        SupabaseAuthRepository.loggedInPhone = savedPhone;
      } else if (savedUid != null && savedUid.startsWith('mock-user-')) {
        phone = savedUid.replaceAll('mock-user-', '');
        SupabaseAuthRepository.loggedInPhone = phone;
      }
    } catch (_) {}

    final currentUser = _supabase.auth.currentUser;
    if (phone == null || phone.isEmpty) {
      phone = currentUser?.phone;
      email = currentUser?.email;
    }

    if (phone != null && phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final last10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
      
      try {
        final response = await _supabase
            .from('customers')
            .select('id, phone');
        
        for (final row in response as List) {
          final rowPhone = (row['phone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
          if (rowPhone.isNotEmpty && (rowPhone == cleanPhone || cleanPhone.endsWith(rowPhone) || rowPhone.endsWith(cleanPhone) || (last10.isNotEmpty && rowPhone.endsWith(last10)))) {
            return row['id'] as String;
          }
        }
      } catch (e) {
        print("Error fetching customers by phone: $e");
      }
    }

    if (email != null && email.isNotEmpty) {
      try {
        final response = await _supabase
            .from('customers')
            .select('id')
            .eq('email', email)
            .limit(1)
            .maybeSingle();
        if (response != null) {
          return response['id'] as String;
        }
      } catch (e) {
        print("Error fetching customer by email: $e");
      }
    }

    // Attempt matching customer via user profile name/phone
    String fullName = 'Customer (${phone ?? email})';
    if (currentUser?.id != null && !currentUser!.id.startsWith('mock-user-')) {
      try {
        var profile = await _supabase
            .from('customer_profiles')
            .select('full_name, email, phone')
            .eq('id', currentUser.id)
            .limit(1)
            .maybeSingle();
        if (profile == null) {
          profile = await _supabase
              .from('profiles')
              .select('full_name, email, phone')
              .eq('id', currentUser.id)
              .limit(1)
              .maybeSingle();
        }
        if (profile != null) {
          fullName = profile['full_name'] ?? fullName;
          final pName = (profile['full_name'] as String? ?? '').trim().toLowerCase();
          final pEmail = (profile['email'] as String? ?? '').trim().toLowerCase();
          final pPhone = (profile['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');

          final custResponse = await _supabase.from('customers').select('id, customer_name, company_name, contact_person, phone, email');
          for (final row in (custResponse as List? ?? [])) {
            final rowName = (row['customer_name'] as String? ?? row['company_name'] as String? ?? row['contact_person'] as String? ?? '').trim().toLowerCase();
            final rowPhone = (row['phone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
            final rowEmail = (row['email'] as String? ?? '').trim().toLowerCase();

            if (pPhone.isNotEmpty && rowPhone.isNotEmpty && (pPhone == rowPhone || pPhone.endsWith(rowPhone) || rowPhone.endsWith(pPhone))) {
              return row['id'] as String;
            }
            if (pEmail.isNotEmpty && rowEmail.isNotEmpty && pEmail == rowEmail) {
              return row['id'] as String;
            }
            if (pName.isNotEmpty && rowName.isNotEmpty && (pName == rowName || rowName.contains(pName) || pName.contains(rowName))) {
              return row['id'] as String;
            }
          }
        }
      } catch (_) {}
    }

    final insertData = {
      'customer_name': fullName,
      'contact_person': fullName,
      'phone': phone ?? '',
      'email': email ?? '',
    };

    if (currentUser?.id != null && !currentUser!.id.startsWith('mock-user-')) {
      insertData['created_by'] = currentUser.id;
    }

    final newCustomer = await _supabase
        .from('customers')
        .insert(insertData)
        .select('id')
        .single();
    return newCustomer['id'] as String;
  }

  @override
  Future<List<Product>> getProducts() async {
    try {
      String? sessionPhone = SupabaseAuthRepository.loggedInPhone;
      try {
        final prefs = await SharedPreferences.getInstance();
        sessionPhone = prefs.getString('customer_session_phone') ?? sessionPhone;
        final sessionUid = prefs.getString('customer_session_uid');
        if ((sessionPhone == null || sessionPhone.isEmpty) && sessionUid != null && sessionUid.startsWith('mock-user-')) {
          sessionPhone = sessionUid.replaceAll('mock-user-', '');
        }
      } catch (_) {}

      String cleanDigits = (sessionPhone ?? '').replaceAll(RegExp(r'\D'), '');
      String last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;

      String? userEmail = _supabase.auth.currentUser?.email?.trim().toLowerCase();
      String? userName;
      try {
        final currentUid = _supabase.auth.currentUser?.id;
        if (currentUid != null && !currentUid.startsWith('mock-user-')) {
          var profile = await _supabase
              .from('customer_profiles')
              .select('full_name, email, phone')
              .eq('id', currentUid)
              .maybeSingle();
          if (profile == null) {
            profile = await _supabase
                .from('profiles')
                .select('full_name, email, phone')
                .eq('id', currentUid)
                .maybeSingle();
          }
          if (profile != null) {
            userEmail = (profile['email'] as String?)?.trim().toLowerCase() ?? userEmail;
            userName = (profile['full_name'] as String?)?.trim().toLowerCase();
            final pPhone = (profile['phone'] as String?)?.replaceAll(RegExp(r'\D'), '');
            if (cleanDigits.isEmpty && pPhone != null && pPhone.isNotEmpty) {
              cleanDigits = pPhone;
              last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
            }
          }
        }
      } catch (_) {}

      final allCustomerIds = <String>{};

      // 1. Match from customers table by phone, email, or profile name
      try {
        final allCusts = await _supabase.from('customers').select('id, phone, email, customer_name, company_name, contact_person');
        for (final row in (allCusts as List? ?? [])) {
          final rowPhone = (row['phone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
          final rowEmail = (row['email'] as String?)?.trim().toLowerCase() ?? '';
          final rowName = (row['customer_name'] as String? ?? row['company_name'] as String? ?? row['contact_person'] as String? ?? '').trim().toLowerCase();

          bool isMatch = false;
          if (cleanDigits.isNotEmpty && rowPhone.isNotEmpty) {
            if (rowPhone == cleanDigits || cleanDigits.endsWith(rowPhone) || rowPhone.endsWith(cleanDigits) || (last10.isNotEmpty && rowPhone.endsWith(last10))) {
              isMatch = true;
            }
          }
          if (userEmail != null && userEmail.isNotEmpty && rowEmail.isNotEmpty) {
            if (rowEmail == userEmail || (rowEmail.contains('@') && userEmail.contains('@') && rowEmail.split('@').first == userEmail.split('@').first)) {
              isMatch = true;
            }
          }
          if (userName != null && userName.isNotEmpty && rowName.isNotEmpty) {
            if (rowName == userName || rowName.contains(userName) || userName.contains(rowName)) {
              isMatch = true;
            }
          }
          if (isMatch) {
            allCustomerIds.add(row['id'] as String);
          }
        }
      } catch (e) {
        print("Error resolving customer IDs in getProducts: $e");
      }

      // Also get the resolved customer ID
      try {
        final resolvedId = await _resolveCustomerId();
        allCustomerIds.add(resolvedId);
      } catch (_) {}

      dynamic response;
      if (allCustomerIds.isNotEmpty) {
        try {
          response = await _supabase
              .from('sales_pipelines')
              .select('''
                id,
                created_at,
                customer_id,
                status,
                product_id,
                products (id, name, category, image_urls, brochure_urls),
                customers (id, address, company_name, customer_name),
                sales_orders (shipping_address),
                quotations (grand_total),
                warranty_cards (start_date, end_date)
              ''')
              .inFilter('customer_id', allCustomerIds.toList())
              .or('status.eq.completed,current_step.eq.completed');
        } catch (e) {
          print("Primary pipelines query fallback: $e");
          try {
            response = await _supabase
                .from('sales_pipelines')
                .select('*, products(*), customers(*)')
                .inFilter('customer_id', allCustomerIds.toList())
                .or('status.eq.completed,current_step.eq.completed');
          } catch (_) {
            response = [];
          }
        }
      }

      // Fallback matching by customer phone across all pipelines if list is empty
      if ((response as List? ?? []).isEmpty) {
        try {
          final allPipes = await _supabase
              .from('sales_pipelines')
              .select('id, created_at, customer_id, status, product_id, products(*), customers(*)')
              .or('status.eq.completed,current_step.eq.completed');
          final matchingPipes = <Map<String, dynamic>>[];
          for (final p in (allPipes as List? ?? [])) {
            final cust = p['customers'] as Map<String, dynamic>?;
            final cPhone = (cust?['phone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
            final cEmail = (cust?['email'] as String?)?.trim().toLowerCase() ?? '';
            final cName = (cust?['customer_name'] as String? ?? cust?['company_name'] as String? ?? '').trim().toLowerCase();

            bool pipeMatch = false;
            if (cleanDigits.isNotEmpty && cPhone.isNotEmpty && (cPhone == cleanDigits || cleanDigits.endsWith(cPhone) || cPhone.endsWith(cleanDigits) || (last10.isNotEmpty && cPhone.endsWith(last10)))) {
              pipeMatch = true;
            }
            if (userEmail != null && userEmail.isNotEmpty && cEmail.isNotEmpty && (cEmail == userEmail || cEmail.split('@').first == userEmail.split('@').first)) {
              pipeMatch = true;
            }
            if (userName != null && userName.isNotEmpty && cName.isNotEmpty && (cName == userName || cName.contains(userName) || userName.contains(cName))) {
              pipeMatch = true;
            }
            if (pipeMatch) {
              matchingPipes.add(p as Map<String, dynamic>);
            }
          }
          if (matchingPipes.isNotEmpty) {
            response = matchingPipes;
          }
        } catch (_) {}
      }

      // Fetch service requests count for this customer
      int requestedCount = 0;
      try {
        if (allCustomerIds.isNotEmpty) {
          final reqRes = await _supabase
              .from('service_requests')
              .select('id')
              .inFilter('customer_id', allCustomerIds.toList());
          requestedCount = (reqRes as List).length;
        }
      } catch (_) {}

      final list = <Product>[];
      for (final item in (response as List? ?? [])) {
        final pipelineId = item['id'] as String;
        final createdAtStr = item['created_at'] as String;
        final purchasedDate = DateTime.tryParse(createdAtStr) ?? DateTime.now();

        final productData = item['products'] as Map<String, dynamic>? ?? {};

        // Quote & Sales Order data
        final quoteList = item['quotations'] as List?;
        final quoteData = (quoteList != null && quoteList.isNotEmpty) ? quoteList.first as Map<String, dynamic> : (item['quotations'] as Map<String, dynamic>?);
        final soList = item['sales_orders'] as List?;
        final soData = (soList != null && soList.isNotEmpty) ? soList.first as Map<String, dynamic> : null;

        String? lineItemDesc;
        final qItems = (quoteData?['line_items'] as List?);
        if (qItems != null && qItems.isNotEmpty) {
          lineItemDesc = (qItems.first as Map)['description'] as String?;
        }
        final soItems = (soData?['line_items'] as List?);
        if (lineItemDesc == null && soItems != null && soItems.isNotEmpty) {
          lineItemDesc = (soItems.first as Map)['description'] as String?;
        }

        final productName = productData['name'] as String? 
            ?? lineItemDesc 
            ?? item['product_name'] as String?
            ?? item['deal_name'] as String?
            ?? 'IZYHEAT System';
        final category = productData['category'] as String? ?? 'heat_pump';
        final modelNumber = category.toUpperCase();
        
        final imgList = List<String>.from(productData['image_urls'] ?? []);
        final String firstImg = imgList.isNotEmpty ? imgList.first : '';

        // Seller/Dealer
        final sellerName = 'IZYHEAT Industry';

        // Price paid
        final amountPaid = (quoteData?['grand_total'] as num?)?.toDouble() 
            ?? (soData?['grand_total'] as num?)?.toDouble() 
            ?? 0.0;

        // Warranty
        final warrantyList = item['warranty_cards'] as List?;
        final warrantyData = (warrantyList != null && warrantyList.isNotEmpty) ? warrantyList.first as Map<String, dynamic> : null;
        final warrantyStartDateStr = warrantyData?['start_date'] as String?;
        final warrantyEndDateStr = warrantyData?['end_date'] as String?;
        
        final warrantyStartDate = warrantyStartDateStr != null 
            ? DateTime.tryParse(warrantyStartDateStr) ?? purchasedDate
            : purchasedDate;
            
        final warrantyExpiryDate = warrantyEndDateStr != null 
            ? DateTime.tryParse(warrantyEndDateStr) ?? purchasedDate.add(const Duration(days: 365))
            : purchasedDate.add(const Duration(days: 365));

        // Installation Location
        final custData = item['customers'] as Map<String, dynamic>?;
        final installationAddress = custData?['address'] as String? ?? soData?['shipping_address'] as String?;

        // AMC Contract info
        String amcStatus = 'none';
        DateTime? amcExpiryDate;
        String serialNumber = pipelineId;
        int visitsIncluded = 0;
        int visitsCompleted = 0;
        List<Map<String, dynamic>> amcVisits = [];
        final pipeCustId = item['customer_id'] as String?;

        try {
          final amcRes = await _supabase
              .from('amc_contracts')
              .select('id, status, end_date, amc_number, number_of_visits_included, amc_service_visits (id, visit_number, scheduled_date, completed_date, status, notes)')
              .or('pipeline_id.eq.$pipelineId${pipeCustId != null ? ',customer_id.eq.$pipeCustId' : ''}')
              .limit(1)
              .maybeSingle();
          if (amcRes != null) {
            final rawStatus = amcRes['status'] as String? ?? 'interested';
            amcStatus = (rawStatus == 'active') ? 'active' : (rawStatus == 'expired' ? 'expired' : 'none');
            final amcEndDateStr = amcRes['end_date'] as String?;
            if (amcEndDateStr != null) {
              amcExpiryDate = DateTime.tryParse(amcEndDateStr);
            }
            serialNumber = amcRes['amc_number'] as String? ?? pipelineId;
            visitsIncluded = amcRes['number_of_visits_included'] as int? ?? 0;
            final visitsList = amcRes['amc_service_visits'] as List?;
            if (visitsList != null) {
              visitsCompleted = visitsList.where((v) => v['status'] == 'completed').length;
              amcVisits = visitsList.map((v) => Map<String, dynamic>.from(v as Map)).toList();
            }
          }
        } catch (_) {}

        list.add(Product(
          productId: pipelineId,
          productName: productName,
          modelNumber: modelNumber,
          imageUrl: firstImg.isNotEmpty ? firstImg : (category == 'heat_pump'
              ? 'assets/images/heatpump_placeholder.jpg'
              : (category == 'thermostat'
                    ? 'assets/images/thermostat_placeholder.jpg'
                    : 'assets/images/boiler_placeholder.jpg')),
          purchasedDate: purchasedDate,
          sellerName: sellerName,
          amountPaid: amountPaid,
          currencyCode: 'INR',
          warrantyStartDate: warrantyStartDate,
          warrantyExpiryDate: warrantyExpiryDate,
          amcStatus: amcStatus,
          amcExpiryDate: amcExpiryDate,
          serialNumber: serialNumber,
          category: category,
          numberOfVisitsIncluded: visitsIncluded,
          numberOfVisitsCompleted: visitsCompleted,
          brochureUrls: (productData['brochure_urls'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
          installationAddress: installationAddress,
          amcVisits: amcVisits,
          requestedServicesCount: requestedCount,
        ));
      }

      // Query direct confirmed quotations / orders for this customer
      try {
        final directQuotes = await _supabase
            .from('quotations')
            .select('id, quotation_number, customer_name, customer_phone, grand_total, line_items, created_at, status, pipeline_id')
            .or('customer_phone.eq.$cleanDigits,customer_phone.ilike.%$last10')
            .eq('status', 'confirmed');
        for (final q in (directQuotes as List? ?? [])) {
          final qPipeId = q['pipeline_id'] as String?;
          if (qPipeId != null && list.any((p) => p.productId == qPipeId)) {
            continue;
          }
          final qId = q['id'] as String;
          if (list.any((p) => p.productId == qId)) continue;
          
          final lineItems = (q['line_items'] as List?) ?? [];
          final firstItem = lineItems.isNotEmpty ? lineItems.first as Map : {};
          final qProdName = firstItem['description'] as String? ?? 'IZYHEAT Solar System';
          final grandTotal = (q['grand_total'] as num?)?.toDouble() ?? 0.0;
          final qCreatedAt = DateTime.tryParse(q['created_at'] ?? '') ?? DateTime.now();

          list.add(Product(
            productId: qId,
            productName: qProdName,
            modelNumber: 'COMMERCIAL',
            imageUrl: 'assets/images/heatpump_placeholder.jpg',
            purchasedDate: qCreatedAt,
            sellerName: 'IZYHEAT Industry',
            amountPaid: grandTotal,
            currencyCode: 'INR',
            warrantyStartDate: qCreatedAt,
            warrantyExpiryDate: qCreatedAt.add(const Duration(days: 365)),
            amcStatus: 'none',
            serialNumber: q['quotation_number'] ?? qId,
            category: 'heat_pump',
            brochureUrls: const [],
            installationAddress: null,
            amcVisits: const [],
            requestedServicesCount: requestedCount,
          ));
        }
      } catch (_) {}

      // Link any active AMC contract for this customer
      try {
        if (allCustomerIds.isNotEmpty) {
          final allAmc = await _supabase
              .from('amc_contracts')
              .select('id, status, end_date, amc_number, number_of_visits_included, pipeline_id, customer_id, amc_service_visits (id, visit_number, scheduled_date, completed_date, status, notes)')
              .inFilter('customer_id', allCustomerIds.toList());
          for (final amc in (allAmc as List? ?? [])) {
            final amcPipeId = amc['pipeline_id'] as String?;
            final rawStatus = amc['status'] as String? ?? 'interested';
            final statusStr = (rawStatus == 'active') ? 'active' : (rawStatus == 'expired' ? 'expired' : 'none');
            final amcEndDate = DateTime.tryParse(amc['end_date'] ?? '');
            final amcNum = amc['amc_number'] as String?;
            final visitsIncluded = amc['number_of_visits_included'] as int? ?? 0;
            final visitsList = amc['amc_service_visits'] as List?;
            final visitsCompleted = visitsList != null ? visitsList.where((v) => v['status'] == 'completed').length : 0;
            final amcVisitsList = visitsList != null ? visitsList.map((v) => Map<String, dynamic>.from(v as Map)).toList() : <Map<String, dynamic>>[];

            for (int i = 0; i < list.length; i++) {
              if (amcPipeId != null && list[i].productId == amcPipeId) {
                list[i] = list[i].copyWith(
                  amcStatus: statusStr,
                  amcExpiryDate: amcEndDate ?? list[i].amcExpiryDate,
                  serialNumber: amcNum ?? list[i].serialNumber,
                  numberOfVisitsIncluded: visitsIncluded,
                  numberOfVisitsCompleted: visitsCompleted,
                  amcVisits: amcVisitsList,
                );
              } else if (list[i].amcStatus == 'none' && statusStr == 'active') {
                list[i] = list[i].copyWith(
                  amcStatus: statusStr,
                  amcExpiryDate: amcEndDate ?? list[i].amcExpiryDate,
                  serialNumber: amcNum ?? list[i].serialNumber,
                  numberOfVisitsIncluded: visitsIncluded,
                  numberOfVisitsCompleted: visitsCompleted,
                  amcVisits: amcVisitsList,
                );
              }
            }
          }
        }
      } catch (_) {}

      return list;
    } catch (e) {
      print("Error fetching purchased products: $e");
      return [];
    }
  }

  @override
  Future<void> requestAmc({required String packageTitle, String? productId}) async {
    try {
      final customerId = await _resolveCustomerId();

      final customerData = await _supabase
          .from('customers')
          .select('company_name, contact_person, phone, created_by')
          .eq('id', customerId)
          .maybeSingle();

      final custName = customerData?['company_name'] ?? customerData?['contact_person'] ?? 'Customer';
      final custPhone = customerData?['phone'] ?? '';
      final createdBy = customerData?['created_by'] as String?;

      // Notify staff (admin, sales_head, service_head, manager, and customer creator)
      final userIdsToNotify = <String>{};
      if (createdBy != null && createdBy.isNotEmpty) {
        userIdsToNotify.add(createdBy);
      }
      try {
        final staffResponse = await _supabase
            .from('profiles')
            .select('id, roles, role');
        for (final staff in (staffResponse as List? ?? [])) {
          final sid = staff['id'] as String?;
          final role = (staff['role'] as String? ?? '').toLowerCase();
          final rolesList = (staff['roles'] is List) ? (staff['roles'] as List).map((e) => e.toString().toLowerCase()).toList() : [];
          if (role == 'admin' || role == 'manager' || role == 'sales_head' || role == 'service_head' ||
              rolesList.contains('admin') || rolesList.contains('manager') || rolesList.contains('sales_head') || rolesList.contains('service_head')) {
            if (sid != null) userIdsToNotify.add(sid);
          }
        }
      } catch (e) {
        print("Error querying staff for notification: $e");
      }

      if (userIdsToNotify.isNotEmpty) {
        try {
          final notifs = userIdsToNotify.map((uid) => {
            'user_id': uid,
            'title': 'New AMC Package Request 🛡️',
            'body': 'Customer $custName ($custPhone) has requested $packageTitle.',
            'type': 'amc_package_request',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          }).toList();

          await _supabase.from('notifications').insert(notifs);
        } catch (e) {
          print("Error inserting notifications: $e");
        }
      }

      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        try {
          await _supabase.from('activity_log').insert({
            'customer_id': currentUser.id,
            'event_type': 'amc_requested',
            'title': 'AMC Requested: $packageTitle',
            'body': 'You requested $packageTitle. Our team will contact you shortly.',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
    } catch (e) {
      print("Error in requestAmc: $e");
      rethrow;
    }
  }

  @override
  Future<List<Product>> getAdvertisementProducts() async {
    try {
      final customerId = await _resolveCustomerId();
      final pipelinesResponse = await _supabase
          .from('sales_pipelines')
          .select('product_id')
          .eq('customer_id', customerId);
      
      final purchasedProductIds = (pipelinesResponse as List)
          .map((item) => item['product_id'] as String)
          .toSet();

      final dbProducts = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('name');

      final advertisementProducts = <Product>[];
      for (final p in dbProducts as List) {
        final String prodId = p['id'] as String;
        if (purchasedProductIds.contains(prodId)) continue;

        final imgList = List<String>.from(p['image_urls'] ?? []);
        final String firstImg = imgList.isNotEmpty ? imgList.first : '';

        advertisementProducts.add(Product(
          productId: prodId,
          productName: p['name'] as String? ?? 'IZYHEAT System',
          modelNumber: p['model_number'] as String? ?? p['category'] as String? ?? 'IZY-01',
          imageUrl: firstImg.isNotEmpty ? firstImg : (p['category'] == 'heat_pump'
              ? 'assets/images/heatpump_placeholder.jpg'
              : (p['category'] == 'thermostat'
                    ? 'assets/images/thermostat_placeholder.jpg'
                    : 'assets/images/boiler_placeholder.jpg')),
          purchasedDate: DateTime.now().add(const Duration(days: 3650)), // Far future to mark as NOT purchased
          sellerName: 'IZYHEAT Store',
          amountPaid: (p['base_price'] as num?)?.toDouble() ?? 0.0,
          currencyCode: 'INR',
          warrantyExpiryDate: DateTime.now(),
          amcStatus: 'none',
          serialNumber: p['hsn_code'] ?? p['id'],
          category: p['category'] as String? ?? 'other',
          brochureUrls: (p['brochure_urls'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
        ));
      }
      return advertisementProducts;
    } catch (e) {
      print("Error fetching advertisement products: $e");
      return [];
    }
  }

  @override
  Future<List<ServiceRequest>> getServiceRequests() async {
    final list = <ServiceRequest>[];
    final seenIds = <String>{};

    try {
      final customerId = await _resolveCustomerId();
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('customer_session_phone') ?? _supabase.auth.currentUser?.phone ?? '';
      final cleanCustPhone = savedPhone.replaceAll(RegExp(r'\D'), '');
      final last10CustPhone = cleanCustPhone.length >= 10 ? cleanCustPhone.substring(cleanCustPhone.length - 10) : cleanCustPhone;

      // 1. Fetch complaints from public.complaints
      try {
        final complaintsRes = await _supabase
            .from('complaints')
            .select()
            .order('created_at', ascending: false);

        for (final item in complaintsRes as List) {
          final id = item['id'] as String;
          if (seenIds.contains(id)) continue;

          final itemCustId = item['customer_id']?.toString() ?? '';
          final itemCustPhone = (item['customer_phone']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');

          // Check if matches resolved customerId OR customer phone
          final matchesId = itemCustId.isNotEmpty && itemCustId == customerId;
          final matchesPhone = cleanCustPhone.isNotEmpty && itemCustPhone.isNotEmpty &&
              (itemCustPhone == cleanCustPhone || itemCustPhone.endsWith(cleanCustPhone) || cleanCustPhone.endsWith(itemCustPhone) ||
               (last10CustPhone.isNotEmpty && itemCustPhone.endsWith(last10CustPhone)));

          if (!matchesId && !matchesPhone) continue;

          seenIds.add(id);

          final ticketNumber = item['ticket_number'] as String? ?? '#CMP';
          final title = item['title'] as String? ?? item['category'] as String? ?? 'Service Complaint';
          final desc = item['description'] as String? ?? '';
          final status = (item['status'] as String? ?? 'pending').toLowerCase();
          final techId = item['assigned_to'] as String? ?? item['technician_id'] as String?;
          final techName = item['technician_name'] as String?;
          final techPhone = item['technician_phone'] as String?;
          final createdAtStr = item['created_at'] as String?;
          final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();
          final hasAmc = item['has_active_amc'] == true;

          final beforeImg = item['before_image_url'] as String?;
          final List<String> photoUrls = [];
          if (beforeImg != null && beforeImg.isNotEmpty) {
            if (beforeImg.contains('|||')) {
              photoUrls.addAll(beforeImg.split('|||'));
            } else {
              photoUrls.add(beforeImg);
            }
          }

          list.add(ServiceRequest(
            requestId: id,
            customerId: customerId.isNotEmpty ? customerId : itemCustId,
            productId: item['product_name'] as String? ?? 'Solar System',
            problemCode: ticketNumber,
            issueCategory: title,
            issueDescription: desc,
            photoUrls: photoUrls,
            scheduledDate: createdAt,
            timeSlot: 'Regular Service Hours',
            technicianId: techId,
            technicianName: techName,
            technicianPhone: techPhone,
            registeredBy: item['source'] == 'customer' ? 'Customer App' : 'Company Staff / Admin',
            status: status,
            warrantyStatus: 'Standard',
            amcStatus: hasAmc ? 'AMC Active' : 'AMC Expired',
            customerLocation: {'latitude': 28.5921, 'longitude': 77.0463},
            customerAddress: {'flat': '', 'street': item['customer_address'] ?? '', 'city': '', 'pincode': ''},
            createdAt: createdAt,
          ));
        }
      } catch (e) {
        print("Error querying complaints in getServiceRequests: $e");
      }

      // 2. Fetch from bookings table if existing
      if (customerId.isNotEmpty) {
        try {
          final bookingsRes = await _supabase
              .from('bookings')
              .select('*, amc_contracts(*, products(*))')
              .eq('customer_id', customerId)
              .order('scheduled_date', ascending: false);

          for (final item in bookingsRes as List) {
            final bookingId = item['id'] as String;
            if (seenIds.contains(bookingId)) continue;
            seenIds.add(bookingId);

            final deviceId = item['device_id'] as String? ?? '';
            final problemCode = item['problem_code'] as String? ?? '#SRV';
            final issueCategory = item['issue_category'] as String? ?? 'Service';
            final issueDescription = item['notes'] as String? ?? '';
            final photoUrls = List<String>.from(item['photo_urls'] ?? []);
            final scheduledDate = DateTime.tryParse(item['scheduled_date'] ?? '') ?? DateTime.now();
            final timeSlot = item['scheduled_slot'] as String? ?? '10:00 AM';
            final assignedTo = item['assigned_technician_id'] as String?;
            final status = item['status'] as String? ?? 'pending';
            final warrantyStatus = (item['warranty_covered'] as bool? ?? false) ? 'Under Warranty' : 'Expired';
            final contractData = item['amc_contracts'] as Map<String, dynamic>? ?? {};

            list.add(ServiceRequest(
              requestId: bookingId,
              customerId: customerId,
            productId: deviceId,
            problemCode: problemCode,
            issueCategory: issueCategory,
            issueDescription: issueDescription,
            photoUrls: photoUrls,
            scheduledDate: scheduledDate,
            timeSlot: timeSlot,
            technicianId: assignedTo,
            status: status,
            warrantyStatus: warrantyStatus,
            amcStatus: contractData['status'] == 'active' ? 'AMC Active' : 'AMC Expired',
            customerLocation: {'latitude': 28.5921, 'longitude': 77.0463},
            customerAddress: Map<String, dynamic>.from(item['location'] ?? {}),
            createdAt: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
          ));
        }
      } catch (_) {}
    }
  } catch (e) {
      print("Error in getServiceRequests: $e");
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<Invoice>> getInvoices() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return [];

    final customerId = await _resolveCustomerId();
    final ids = {currentUser.id, customerId}.toList();

    final response = await _supabase
        .from('invoices')
        .select('*, bookings(*, amc_contracts(*, products(*)))')
        .inFilter('customer_id', ids)
        .order('created_at', ascending: false);

    return (response as List).map((item) {
      final invoiceId = item['id'] as String;
      final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
      final status = item['status'] as String;
      final createdAt = DateTime.parse(item['created_at'] as String);
      
      final bookingData = item['bookings'] as Map<String, dynamic>? ?? {};
      final category = bookingData['issue_category'] as String? ?? 'Service Charge';

      return Invoice(
        invoiceId: invoiceId,
        customerId: currentUser.id,
        requestId: item['related_booking_id'] as String? ?? '',
        title: 'Invoice for $category',
        date: createdAt,
        dueDate: createdAt.add(const Duration(days: 15)),
        amount: amount,
        status: status,
        lineItems: [
          {'name': 'Service & Repairs', 'qty': 1, 'price': amount},
        ],
      );
    }).toList();
  }

  @override
  Future<Technician> getTechnician(String techId) async {
    final response = await _supabase
        .from('profiles')
        .select('full_name, phone')
        .eq('id', techId)
        .limit(1)
        .maybeSingle();

    final name = response?['full_name'] ?? 'Service Technician';
    final phone = response?['phone'] ?? '+919999999999';

    return Technician(
      techId: techId,
      name: name,
      phone: phone,
      avatarUrl:
          'https://api.dicebear.com/7.x/avataaars/svg?seed=${name.replaceAll(' ', '')}',
      vehicleInfo: 'IZYHEAT Service Van',
      rating: 4.9,
      currentLocation: {'latitude': 28.6015, 'longitude': 77.0392},
      isOnline: true,
    );
  }

  @override
  Stream<Technician> listenToTechnicianLocation(String techId) {
    double customerLat = 28.5921;
    double customerLng = 77.0463;
    double startLat = 28.6045;
    double startLng = 77.0315;

    final controller = StreamController<Technician>();
    int step = 0;
    const maxSteps = 12;

    final timer = Timer.periodic(const Duration(seconds: 8), (t) {
      step = (t.tick % maxSteps);
      double fraction = step / (maxSteps - 1);
      double currentLat = startLat + (customerLat - startLat) * fraction;
      double currentLng = startLng + (customerLng - startLng) * fraction;

      controller.add(Technician(
        techId: techId,
        name: 'Technician Marcus',
        phone: '+91 99999 88888',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Marcus',
        vehicleInfo: 'IZYHEAT Service Van',
        rating: 4.8,
        currentLocation: {'latitude': currentLat, 'longitude': currentLng},
        isOnline: true,
      ));
    });

    final channel = _supabase.channel('tech-location-$techId');
    channel.onBroadcast(
      event: 'location-update',
      callback: (payload) {
        final lat = (payload['latitude'] as num?)?.toDouble();
        final lng = (payload['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          controller.add(Technician(
            techId: techId,
            name: 'Technician Marcus',
            phone: '+91 99999 88888',
            avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Marcus',
            vehicleInfo: 'IZYHEAT Service Van',
            rating: 4.8,
            currentLocation: {'latitude': lat, 'longitude': lng},
            isOnline: true,
          ));
        }
      },
    ).subscribe();

    controller.onCancel = () {
      timer.cancel();
      channel.unsubscribe();
    };

    return controller.stream.asBroadcastStream();
  }

  @override
  Future<List<SupportTicket>> getSupportTickets() async {
    final customerId = await _resolveCustomerId();
    final response = await _supabase
        .from('support_tickets')
        .select()
        .eq('customer_id', customerId);

    return (response as List).map((json) {
      return SupportTicket.fromJson(json);
    }).toList();
  }

  @override
  Future<void> createServiceRequest(ServiceRequest request) async {
    final customerId = await _resolveCustomerId();

    final customerProfile = await _supabase.from('customers').select().eq('id', customerId).maybeSingle();
    final customerName = customerProfile != null ? customerProfile['customer_name'] : 'Unknown Customer';
    final customerPhone = customerProfile != null ? customerProfile['phone'] : '';

    String productName = request.productId;
    if (productName.isEmpty || (productName.length > 25 && RegExp(r'^[0-9a-fA-F\-]+$').hasMatch(productName.trim()))) {
      try {
        final prod = await _supabase.from('products').select('name, category').eq('id', request.productId).maybeSingle();
        if (prod != null && prod['name'] != null) {
          productName = prod['name'] as String;
        } else {
          productName = 'IZYHEAT Solar System';
        }
      } catch (_) {
        productName = 'IZYHEAT Solar System';
      }
    }

    await _supabase.from('complaints').insert({
      'id': const Uuid().v4(),
      'ticket_number': request.problemCode,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': '${request.customerAddress['flat']}, ${request.customerAddress['street']}, ${request.customerAddress['city']} - ${request.customerAddress['pincode']}',
      'product_name': productName,
      'has_active_amc': request.amcStatus == 'AMC Active',
      'amc_expiry': request.amcStatus == 'AMC Active' ? 'Active' : 'Expired',
      'priority': 'Medium Priority',
      'title': request.issueCategory,
      'description': request.issueDescription,
      'status': 'pending',
      'source': 'customer',
      'tat_remaining': '24h',
      'before_image_url': request.photoUrls.isNotEmpty ? request.photoUrls.first : null,
      'created_at': DateTime.now().toIso8601String(),
    });

    try {
      await _supabase.from('activity_log').insert({
        'customer_id': customerId,
        'event_type': 'booking_created',
        'title': 'Service Request Submitted',
        'body': 'Your complaint for ${request.issueCategory} has been submitted.',
      });
    } catch (_) {}
  }

  @override
  Future<void> createSupportTicket(SupportTicket ticket) async {
    final customerId = await _resolveCustomerId();
    await _supabase.from('support_tickets').insert({
      'customer_id': customerId,
      'subject': ticket.subject,
      'description': ticket.description,
      'status': ticket.status,
      'messages': ticket.messages,
    });
  }

  @override
  Future<void> addSupportMessage(
    String ticketId,
    String text,
    bool isUser,
  ) async {
    final response = await _supabase
        .from('support_tickets')
        .select('messages')
        .eq('id', ticketId)
        .single();

    final messages = List<Map<String, dynamic>>.from(
      response['messages'] ?? [],
    );
    messages.add({
      'sender': isUser ? 'user' : 'agent',
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _supabase
        .from('support_tickets')
        .update({'messages': messages})
        .eq('id', ticketId);
  }

  @override
  Future<void> payInvoice(String invoiceId) async {
    await _supabase
        .from('invoices')
        .update({
          'status': 'paid',
        })
        .eq('id', invoiceId);

    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      try {
        await _supabase.from('activity_log').insert({
          'customer_id': currentUser.id,
          'event_type': 'invoice_paid',
          'title': 'Invoice Paid',
          'body': 'Your payment for invoice has been successfully processed.',
          'related_invoice_id': invoiceId,
        });
      } catch (_) {}
    }
  }

  @override
  Future<void> renewAmc(String productId) async {
    final response = await _supabase
        .from('amc_contracts')
        .select('end_date')
        .eq('id', productId)
        .single();

    final currentEndDate = response['end_date'] != null
        ? DateTime.parse(response['end_date'] as String)
        : DateTime.now();

    final newEndDate = currentEndDate.add(const Duration(days: 365));

    await _supabase
        .from('amc_contracts')
        .update({
          'status': 'active',
          'end_date': newEndDate.toIso8601String().split('T')[0],
        })
        .eq('id', productId);

    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      try {
        await _supabase.from('activity_log').insert({
          'customer_id': currentUser.id,
          'event_type': 'amc_renewed',
          'title': 'AMC Contract Renewed',
          'body': 'Your contract has been extended for 1 year.',
        });
      } catch (_) {}
    }
  }

  @override
  Future<void> requestAmcService({required String productId, String? pipelineId}) async {
    try {
      final customerId = await _resolveCustomerId();
      
      final customerData = await _supabase
          .from('customers')
          .select('customer_name, contact_person, phone')
          .eq('id', customerId)
          .single();
      final custName = customerData['customer_name'] ?? customerData['contact_person'] ?? 'Customer';
      final custPhone = customerData['phone'] ?? '';

      final productData = await _supabase
          .from('products')
          .select('name, model_number')
          .eq('id', productId)
          .single();
      final prodName = productData['name'] ?? 'Product';
      final modelNo = productData['model_number'] ?? '';

      final staffResponse = await _supabase
          .from('profiles')
          .select('id')
          .or('role.eq.admin,role.eq.sales_head');

      for (final staff in staffResponse as List) {
        final staffId = staff['id'] as String;
        await _supabase.from('notifications').insert({
          'user_id': staffId,
          'title': 'New AMC Service Request 🛠️',
          'body': 'Customer $custName ($custPhone) has requested AMC service for product $prodName ($modelNo).',
          'type': 'amc_renewal_request',
          'related_pipeline_id': pipelineId,
        });
      }

      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        await _supabase.from('activity_log').insert({
          'customer_id': currentUser.id,
          'event_type': 'amc_requested',
          'title': 'AMC Service Requested',
          'body': 'You requested AMC service for $prodName. Our team will contact you shortly.',
        });
      }
    } catch (e) {
      print("Error in requestAmcService: $e");
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getActivityLogs() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      final response = await _supabase
          .from('activity_log')
          .select()
          .eq('customer_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print("Error fetching activity logs: $e");
      return [];
    }
  }
}
