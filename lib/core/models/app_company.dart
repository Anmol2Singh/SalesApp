// lib/core/models/app_company.dart

class AppCompany {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String website;
  final String gstin;
  final String? logoUrl;
  final String? stampUrl;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNo;
  final String bankBranch;
  final String bankIfsc;
  final bool isDefault;

  const AppCompany({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.gstin = '',
    this.logoUrl,
    this.stampUrl,
    this.bankName = '',
    this.bankAccountName = '',
    this.bankAccountNo = '',
    this.bankBranch = '',
    this.bankIfsc = '',
    this.isDefault = false,
  });

  List<String> get addressLines {
    if (address.isEmpty) return [];
    if (address.contains('\n')) {
      return address.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    // Try split by comma if long
    if (address.length > 50 && address.contains(',')) {
      final parts = address.split(',');
      final mid = (parts.length / 2).ceil();
      final line1 = parts.take(mid).join(',').trim();
      final line2 = parts.skip(mid).join(',').trim();
      return [line1, line2];
    }
    return [address];
  }

  factory AppCompany.fromJson(Map<String, dynamic> json) {
    return AppCompany(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['company_name']?.toString() ?? '',
      address: json['address']?.toString() ?? json['company_address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['company_phone']?.toString() ?? '',
      email: json['email']?.toString() ?? json['company_email']?.toString() ?? '',
      website: json['website']?.toString() ?? json['company_website']?.toString() ?? '',
      gstin: json['gstin']?.toString() ?? json['company_gst']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
      stampUrl: json['stamp_url']?.toString(),
      bankName: json['bank_name']?.toString() ?? '',
      bankAccountName: json['bank_account_name']?.toString() ?? '',
      bankAccountNo: json['bank_account_no']?.toString() ?? '',
      bankBranch: json['bank_branch']?.toString() ?? '',
      bankIfsc: json['bank_ifsc']?.toString() ?? '',
      isDefault: json['is_default'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'phone': phone,
    'email': email,
    'website': website,
    'gstin': gstin,
    'logo_url': logoUrl,
    'stamp_url': stampUrl,
    'bank_name': bankName,
    'bank_account_name': bankAccountName,
    'bank_account_no': bankAccountNo,
    'bank_branch': bankBranch,
    'bank_ifsc': bankIfsc,
    'is_default': isDefault,
  };

  AppCompany copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? gstin,
    String? logoUrl,
    String? stampUrl,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNo,
    String? bankBranch,
    String? bankIfsc,
    bool? isDefault,
  }) {
    return AppCompany(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      gstin: gstin ?? this.gstin,
      logoUrl: logoUrl ?? this.logoUrl,
      stampUrl: stampUrl ?? this.stampUrl,
      bankName: bankName ?? this.bankName,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNo: bankAccountNo ?? this.bankAccountNo,
      bankBranch: bankBranch ?? this.bankBranch,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  static const AppCompany defaultInsiyaSolar = AppCompany(
    id: 'insiya-solar',
    name: 'INSIYA SOLAR INDUSTRY',
    address: 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra 411014',
    phone: '+91 9292922992',
    email: 'insiyasolarindustry@gmail.com',
    website: 'www.insiyasolar.com',
    gstin: '27CFTPS5292A1ZY',
    logoUrl: 'assets/images/logo.png',
    stampUrl: 'assets/images/company_stamp.png',
    bankName: 'HDFC BANK',
    bankAccountName: 'INSIYA SOLAR INDUSTRY',
    bankAccountNo: '50200062828292',
    bankBranch: 'VIMAN NAGAR PUNE',
    bankIfsc: 'HDFC0001804',
    isDefault: true,
  );

  static const AppCompany defaultInsiyaTrading = AppCompany(
    id: 'insiya-trading',
    name: 'INSIYA TRADING CORPORATION',
    address: 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra 411014',
    phone: '+91 7588874019 & +91 9292922992',
    email: 'insiyaindia@gmail.com    info@insiyacorp.com',
    website: 'www.insiyacorp.com',
    gstin: '27CFTPS5292A1ZY',
    logoUrl: 'assets/images/boom_barrier/sefdor_logo.png',
    stampUrl: 'assets/images/company_stamp.png',
    bankName: 'KOTAK MAHINDRA BANK',
    bankAccountName: 'INSIYA TRADING CORPORATION',
    bankAccountNo: '9446865227',
    bankBranch: 'VIMAN NAGAR PUNE',
    bankIfsc: 'KKBK0001804',
    isDefault: false,
  );

  static const List<AppCompany> defaultCompanies = [
    defaultInsiyaSolar,
    defaultInsiyaTrading,
  ];
}
