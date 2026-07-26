class MasterProduct {
  final String name;
  final String brand;
  final String category;
  final double mrp;
  final String unit;

  MasterProduct({
    required this.name,
    required this.brand,
    required this.category,
    required this.mrp,
    required this.unit,
  });

  Map<String, dynamic> toMap() => {
        'name': name, 'brand': brand, 'category': category, 'mrp': mrp, 'unit': unit,
      };

  factory MasterProduct.fromMap(Map<String, dynamic> map) => MasterProduct(
        name: map['name'] ?? '',
        brand: map['brand'] ?? '',
        category: map['category'] ?? '',
        mrp: (map['mrp'] ?? 0).toDouble(),
        unit: map['unit'] ?? '',
      );
}