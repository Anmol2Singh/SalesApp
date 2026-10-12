class PmCompany {
  final String id;
  final String name;
  final String? tagline;
  final double openingBalance;

  const PmCompany({
    required this.id,
    required this.name,
    this.tagline,
    this.openingBalance = 0.0,
  });

  static const List<PmCompany> defaultCompanies = [
    PmCompany(
      id: 'insiya-solar',
      name: 'Insiya Solar Industry',
      tagline: 'Solar & Heat Pump Project Manager',
      openingBalance: 0.0,
    ),
    PmCompany(
      id: 'insiya-trading',
      name: 'Insiya Trading Corporation',
      tagline: 'Trading & Supply Project Manager',
      openingBalance: 0.0,
    ),
  ];

  factory PmCompany.fromJson(Map<String, dynamic> json) {
    return PmCompany(
      id: json['id'] as String? ?? 'insiya-solar',
      name: json['name'] as String? ?? 'Insiya Solar Industry',
      tagline: json['tagline'] as String?,
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (tagline != null) 'tagline': tagline,
    'opening_balance': openingBalance,
  };
}
