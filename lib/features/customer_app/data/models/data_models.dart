

class Product {
  final String productId;
  final String productName;
  final String modelNumber;
  final String imageUrl;
  final DateTime purchasedDate;
  final String sellerName;
  final double amountPaid;
  final String currencyCode;
  final DateTime? warrantyStartDate;
  final DateTime warrantyExpiryDate;
  final String amcStatus; // active, expired, none
  final DateTime? amcExpiryDate;
  final String serialNumber;
  final String category; // boiler, heat_pump, thermostat, radiator, other
  final int numberOfVisitsIncluded;
  final int numberOfVisitsCompleted;
  final List<Map<String, dynamic>> brochureUrls;
  final String? installationAddress;
  final List<Map<String, dynamic>> amcVisits;
  final int requestedServicesCount;

  Product({
    required this.productId,
    required this.productName,
    required this.modelNumber,
    required this.imageUrl,
    required this.purchasedDate,
    required this.sellerName,
    required this.amountPaid,
    required this.currencyCode,
    this.warrantyStartDate,
    required this.warrantyExpiryDate,
    required this.amcStatus,
    this.amcExpiryDate,
    required this.serialNumber,
    required this.category,
    this.numberOfVisitsIncluded = 0,
    this.numberOfVisitsCompleted = 0,
    this.brochureUrls = const [],
    this.installationAddress,
    this.amcVisits = const [],
    this.requestedServicesCount = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d is String) return DateTime.parse(d);
      return DateTime.now();
    }

    return Product(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      modelNumber: json['modelNumber'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      purchasedDate: parseDate(json['purchasedDate']),
      sellerName: json['sellerName'] ?? '',
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currencyCode'] ?? 'USD',
      warrantyStartDate: json['warrantyStartDate'] != null ? parseDate(json['warrantyStartDate']) : null,
      warrantyExpiryDate: parseDate(json['warrantyExpiryDate']),
      amcStatus: json['amcStatus'] ?? 'none',
      amcExpiryDate: json['amcExpiryDate'] != null ? parseDate(json['amcExpiryDate']) : null,
      serialNumber: json['serialNumber'] ?? '',
      category: json['category'] ?? 'other',
      numberOfVisitsIncluded: json['numberOfVisitsIncluded'] ?? 0,
      numberOfVisitsCompleted: json['numberOfVisitsCompleted'] ?? 0,
      brochureUrls: List<Map<String, dynamic>>.from(json['brochureUrls'] ?? []),
      installationAddress: json['installationAddress'] as String?,
      amcVisits: List<Map<String, dynamic>>.from(json['amcVisits'] ?? []),
      requestedServicesCount: json['requestedServicesCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'modelNumber': modelNumber,
      'imageUrl': imageUrl,
      'purchasedDate': purchasedDate.toIso8601String(),
      'sellerName': sellerName,
      'amountPaid': amountPaid,
      'currencyCode': currencyCode,
      'warrantyStartDate': warrantyStartDate?.toIso8601String(),
      'warrantyExpiryDate': warrantyExpiryDate.toIso8601String(),
      'amcStatus': amcStatus,
      'amcExpiryDate': amcExpiryDate?.toIso8601String(),
      'serialNumber': serialNumber,
      'category': category,
      'numberOfVisitsIncluded': numberOfVisitsIncluded,
      'numberOfVisitsCompleted': numberOfVisitsCompleted,
      'brochureUrls': brochureUrls,
    };
  }
}

class ServiceRequest {
  final String requestId;
  final String customerId;
  final String productId;
  final String problemCode;
  final String issueCategory;
  final String issueDescription;
  final List<String> photoUrls;
  final DateTime scheduledDate;
  final String timeSlot;
  final String? technicianId;
  final String? technicianName;
  final String? technicianPhone;
  final String? registeredBy;
  final String status; // pending, confirmed, in_progress, completed, cancelled
  final String warrantyStatus;
  final String amcStatus;
  final Map<String, double> customerLocation; // lat, lng
  final Map<String, dynamic> customerAddress;
  final DateTime createdAt;

  ServiceRequest({
    required this.requestId,
    required this.customerId,
    required this.productId,
    required this.problemCode,
    required this.issueCategory,
    required this.issueDescription,
    required this.photoUrls,
    required this.scheduledDate,
    required this.timeSlot,
    this.technicianId,
    this.technicianName,
    this.technicianPhone,
    this.registeredBy,
    required this.status,
    required this.warrantyStatus,
    required this.amcStatus,
    required this.customerLocation,
    required this.customerAddress,
    required this.createdAt,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d is String) return DateTime.parse(d);
      return DateTime.now();
    }

    Map<String, double> parseLocation(dynamic loc) {
      if (loc is Map) {
        return {
          'latitude': (loc['latitude'] as num?)?.toDouble() ?? 0.0,
          'longitude': (loc['longitude'] as num?)?.toDouble() ?? 0.0,
        };
      }
      return {'latitude': 0.0, 'longitude': 0.0};
    }

    return ServiceRequest(
      requestId: json['requestId'] ?? '',
      customerId: json['customerId'] ?? '',
      productId: json['productId'] ?? '',
      problemCode: json['problemCode'] ?? '',
      issueCategory: json['issueCategory'] ?? '',
      issueDescription: json['issueDescription'] ?? '',
      photoUrls: List<String>.from(json['photoUrls'] ?? []),
      scheduledDate: parseDate(json['scheduledDate']),
      timeSlot: json['timeSlot'] ?? '',
      technicianId: json['technicianId'],
      technicianName: json['technicianName'],
      technicianPhone: json['technicianPhone'],
      registeredBy: json['registeredBy'],
      status: json['status'] ?? 'pending',
      warrantyStatus: json['warrantyStatus'] ?? 'none',
      amcStatus: json['amcStatus'] ?? 'none',
      customerLocation: parseLocation(json['customerLocation']),
      customerAddress: Map<String, dynamic>.from(json['customerAddress'] ?? {}),
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'customerId': customerId,
      'productId': productId,
      'problemCode': problemCode,
      'issueCategory': issueCategory,
      'issueDescription': issueDescription,
      'photoUrls': photoUrls,
      'scheduledDate': scheduledDate.toIso8601String(),
      'timeSlot': timeSlot,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'technicianPhone': technicianPhone,
      'registeredBy': registeredBy,
      'status': status,
      'warrantyStatus': warrantyStatus,
      'amcStatus': amcStatus,
      'customerLocation': customerLocation,
      'customerAddress': customerAddress,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  ServiceRequest copyWith({
    String? status,
    String? technicianId,
    String? technicianName,
    String? technicianPhone,
    String? registeredBy,
    int? etaMinutes,
  }) {
    return ServiceRequest(
      requestId: requestId,
      customerId: customerId,
      productId: productId,
      problemCode: problemCode,
      issueCategory: issueCategory,
      issueDescription: issueDescription,
      photoUrls: photoUrls,
      scheduledDate: scheduledDate,
      timeSlot: timeSlot,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      technicianPhone: technicianPhone ?? this.technicianPhone,
      registeredBy: registeredBy ?? this.registeredBy,
      status: status ?? this.status,
      warrantyStatus: warrantyStatus,
      amcStatus: amcStatus,
      customerLocation: customerLocation,
      customerAddress: customerAddress,
      createdAt: createdAt,
    );
  }
}

class Invoice {
  final String invoiceId;
  final String customerId;
  final String requestId;
  final String title;
  final DateTime date;
  final DateTime dueDate;
  final double amount;
  final String status; // paid, unpaid
  final List<Map<String, dynamic>> lineItems;

  Invoice({
    required this.invoiceId,
    required this.customerId,
    required this.requestId,
    required this.title,
    required this.date,
    required this.dueDate,
    required this.amount,
    required this.status,
    required this.lineItems,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d is String) return DateTime.parse(d);
      return DateTime.now();
    }

    return Invoice(
      invoiceId: json['invoiceId'] ?? '',
      customerId: json['customerId'] ?? '',
      requestId: json['requestId'] ?? '',
      title: json['title'] ?? 'Repair Service Invoice',
      date: parseDate(json['date']),
      dueDate: parseDate(json['dueDate']),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'unpaid',
      lineItems: List<Map<String, dynamic>>.from(json['lineItems'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoiceId': invoiceId,
      'customerId': customerId,
      'requestId': requestId,
      'title': title,
      'date': date.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'amount': amount,
      'status': status,
      'lineItems': lineItems,
    };
  }

  Invoice copyWith({String? status}) {
    return Invoice(
      invoiceId: invoiceId,
      customerId: customerId,
      requestId: requestId,
      title: title,
      date: date,
      dueDate: dueDate,
      amount: amount,
      status: status ?? this.status,
      lineItems: lineItems,
    );
  }
}

class Technician {
  final String techId;
  final String name;
  final String phone;
  final String avatarUrl;
  final String vehicleInfo;
  final double rating;
  final Map<String, double> currentLocation; // latitude, longitude
  final bool isOnline;

  Technician({
    required this.techId,
    required this.name,
    required this.phone,
    required this.avatarUrl,
    required this.vehicleInfo,
    required this.rating,
    required this.currentLocation,
    required this.isOnline,
  });

  factory Technician.fromJson(Map<String, dynamic> json) {
    Map<String, double> parseLocation(dynamic loc) {
      if (loc is Map) {
        return {
          'latitude': (loc['latitude'] as num?)?.toDouble() ?? 0.0,
          'longitude': (loc['longitude'] as num?)?.toDouble() ?? 0.0,
        };
      }
      return {'latitude': 0.0, 'longitude': 0.0};
    }

    return Technician(
      techId: json['techId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      vehicleInfo: json['vehicleInfo'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      currentLocation: parseLocation(json['currentLocation']),
      isOnline: json['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'techId': techId,
      'name': name,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'vehicleInfo': vehicleInfo,
      'rating': rating,
      'currentLocation': currentLocation,
      'isOnline': isOnline,
    };
  }
}

class SupportTicket {
  final String ticketId;
  final String customerId;
  final String subject;
  final String description;
  final String status; // open, closed
  final List<Map<String, dynamic>> messages; // sender, text, timestamp
  final DateTime createdAt;

  SupportTicket({
    required this.ticketId,
    required this.customerId,
    required this.subject,
    required this.description,
    required this.status,
    required this.messages,
    required this.createdAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d is String) return DateTime.parse(d);
      return DateTime.now();
    }

    return SupportTicket(
      ticketId: json['ticketId'] ?? '',
      customerId: json['customerId'] ?? '',
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'open',
      messages: List<Map<String, dynamic>>.from(json['messages'] ?? []),
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticketId': ticketId,
      'customerId': customerId,
      'subject': subject,
      'description': description,
      'status': status,
      'messages': messages,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
