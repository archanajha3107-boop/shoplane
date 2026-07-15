import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int qty;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
  });

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'price': price,
    'qty': qty,
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
    productId: map['productId'] ?? '',
    name: map['name'] ?? '',
    price: (map['price'] ?? 0).toDouble(),
    qty: map['qty'] ?? 1,
  );
}

class OrderModel {
  final String id;
  final String customerId;
  final String sellerId;
  final String customerName;
  final String shopName;
  final List<OrderItem> items;
  final double total;
  final String status;
  final String fulfillmentType;
  final String paymentMethod;
  final bool issueFlag;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.sellerId,
    required this.customerName,
    required this.shopName,
    required this.items,
    required this.total,
    required this.status,
    required this.fulfillmentType,
    required this.paymentMethod,
    required this.issueFlag,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'sellerId': sellerId,
      'customerName': customerName,
      'shopName': shopName,
      'items': items.map((i) => i.toMap()).toList(),
      'total': total,
      'status': status,
      'fulfillmentType': fulfillmentType,
      'paymentMethod': paymentMethod,
      'issueFlag': issueFlag,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      customerId: map['customerId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      customerName: map['customerName'] ?? '',
      shopName: map['shopName'] ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
          .toList(),
      total: (map['total'] ?? 0).toDouble(),
      status: map['status'] ?? 'new',
      fulfillmentType: map['fulfillmentType'] ?? 'delivery',
      paymentMethod: map['paymentMethod'] ?? 'cash',
      issueFlag: map['issueFlag'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}