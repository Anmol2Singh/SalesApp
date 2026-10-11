// lib/features/quotation_generator/models/sales_person.dart

class SalesPerson {
  final String id;
  final String name;
  final String mobile;
  final String? email;

  const SalesPerson({
    required this.id,
    required this.name,
    required this.mobile,
    this.email,
  });

  String get displayName => '$name ($mobile)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'email': email,
      };

  factory SalesPerson.fromJson(Map<String, dynamic> json) => SalesPerson(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        email: json['email'] as String?,
      );

  static List<SalesPerson> defaultList() => const [
        SalesPerson(id: 'sp_1', name: 'Aman Khan', mobile: '9044495184'),
        SalesPerson(id: 'sp_2', name: 'Sagar Farate', mobile: '7588874019'),
        SalesPerson(id: 'sp_3', name: 'Sir', mobile: '9292922992'),
      ];
}
