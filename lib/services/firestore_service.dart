import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── PRODUCTS ──────────────────────────────────────────────

  Future<void> addProduct(ProductModel product) async {
    await _db.collection('products').add(product.toMap());
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    await _db.collection('products').doc(id).update(data);
  }

  Future<void> toggleStock(String productId, bool inStock) async {
    await _db.collection('products').doc(productId).update({
      'inStock': inStock,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ProductModel>> vendorProducts(String sellerId) {
    return _db
        .collection('products')
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProductModel.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<ProductModel>> shopProducts(String sellerId) {
    return _db
        .collection('products')
        .where('sellerId', isEqualTo: sellerId)
        .where('inStock', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProductModel.fromMap(d.data(), d.id))
            .toList());
  }

  // ── ORDERS ────────────────────────────────────────────────

  Future<String> placeOrder(OrderModel order) async {
    final ref = await _db.collection('orders').add(order.toMap());
    return ref.id;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.collection('orders').doc(orderId).update({'status': status});
  }

  Future<void> flagOrderIssue(String orderId, String reason) async {
    await _db.collection('orders').doc(orderId).update({
      'issueFlag': true,
      'issueReason': reason,
    });
  }

  Stream<List<OrderModel>> vendorOrders(String sellerId) {
    return _db
        .collection('orders')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OrderModel.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<OrderModel>> customerOrders(String customerId) {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OrderModel.fromMap(d.data(), d.id))
            .toList());
  }

  // ── VENDORS (for customer home) ───────────────────────────

  Future<List<UserModel>> getNearbyVendors() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'vendor')
        .get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data(), d.id))
        .toList();
  }

  Future<void> toggleShopOpen(String vendorId, bool isOpen) async {
    await _db.collection('users').doc(vendorId).update({'isOpen': isOpen});
  }

  // ── MY SHOPS ──────────────────────────────────────────────

  Future<void> saveShop(String customerId, String sellerId) async {
    await _db
        .collection('users')
        .doc(customerId)
        .collection('myShops')
        .doc(sellerId)
        .set({'savedAt': FieldValue.serverTimestamp()});
  }

  Stream<List<String>> mySavedShopIds(String customerId) {
    return _db
        .collection('users')
        .doc(customerId)
        .collection('myShops')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }
}