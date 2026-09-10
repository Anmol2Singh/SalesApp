// lib/core/models/inventory_item.dart

class InventoryItem {
  final String id;
  final String itemName;
  final String? hsnSac;
  final String? uom;
  final double price;
  final int warrantyMonths;
  final DateTime createdAt;

  InventoryItem({
    required this.id,
    required this.itemName,
    this.hsnSac,
    this.uom,
    this.price = 0.0,
    this.warrantyMonths = 12,
    required this.createdAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      itemName: json['item_name'] as String,
      hsnSac: json['hsn_sac'] as String?,
      uom: json['uom'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      warrantyMonths: (json['warranty_months'] as num?)?.toInt() ?? 12,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_name': itemName,
      'hsn_sac': hsnSac,
      'uom': uom,
      'price': price,
      'warranty_months': warrantyMonths,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // To support searchable dropdown display
  @override
  String toString() => itemName;
  
  // Need custom equality for DropdownSearch to correctly match items
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
