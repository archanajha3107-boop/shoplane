import 'package:flutter_test/flutter_test.dart';
import 'package:shoplane/models/product_model.dart';
import 'package:shoplane/screens/customer/grouped_product_card.dart';
import 'package:shoplane/services/firestore_service.dart';

void main() {
  test('groups products by name while preserving individual Firestore IDs', () {
    final grouped = groupProductsByName([
      {'name': 'Tomatoes', 'variant': 'Premium', 'price': 40, 'emoji': '🍅'},
      {'name': 'Tomatoes', 'variant': 'Regular', 'price': 25, 'emoji': '🍅'},
    ], ['docA', 'docB']);

    expect(grouped, hasLength(1));
    expect(grouped.first.name, 'Tomatoes');
    expect(grouped.first.variants.map((v) => v.productId).toList(), ['docA', 'docB']);
  });

  test('cart keys merge using Firestore product id instead of object identity', () {
    final first = ProductModel(
      id: 'p1',
      sellerId: 'seller',
      name: 'Tomatoes',
      price: 40,
      category: 'Veg',
      inStock: true,
      isVariableStock: false,
      lastUpdated: DateTime.now(),
    );

    final second = ProductModel(
      id: 'p1',
      sellerId: 'seller',
      name: 'Tomatoes',
      price: 40,
      category: 'Veg',
      inStock: true,
      isVariableStock: false,
      lastUpdated: DateTime.now(),
    );

    final cart = {first: 1};
    expect(cart[second], 1);
  });

  test('khata credit ledger payload matches required fields', () {
    final service = FirestoreService();
    final entry = service.buildKhataEntry(
      vendorId: 'vendor-1',
      customerId: 'customer-1',
      customerName: 'Asha Singh',
      customerPhone: '9876543210',
      orderId: 'order-1',
      amount: 450.0,
    );

    expect(entry['vendorId'], 'vendor-1');
    expect(entry['customerId'], 'customer-1');
    expect(entry['customerName'], 'Asha Singh');
    expect(entry['customerPhone'], '9876543210');
    expect(entry['orderId'], 'order-1');
    expect(entry['amount'], 450.0);
    expect(entry['paid'], false);
    expect(entry['createdAt'], isNotNull);
  });
}