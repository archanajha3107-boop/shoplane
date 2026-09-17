import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String sellerId;
  final String name;
  final double price;
  final String category;
  final String? photoUrl;
  final bool inStock;
  final bool isVariableStock;
  final DateTime lastUpdated;

  ProductModel({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.price,
    required this.category,
    this.photoUrl,
    required this.inStock,
    required this.isVariableStock,
    required this.lastUpdated,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'name': name,
      'price': price,
      'category': category,
      'photoUrl': photoUrl ?? '',
      'inStock': inStock,
      'isVariableStock': isVariableStock,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id: id,
      sellerId: map['sellerId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      photoUrl: map['photoUrl'],
      inStock: map['inStock'] ?? true,
      isVariableStock: map['isVariableStock'] ?? false,
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }
}