import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'dart:math';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius in km
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // ── PRODUCTS ──────────────────────────────────────────────
  Future<OrderModel?> getLastOrderFromShop(
      String customerId, String sellerId) async {
    try {
      final snap = await _db
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return OrderModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
    } catch (e) {
      return null;
    }
  }

  Future<OrderModel?> getOrder(String orderId) async {
    final doc = await _db.collection('orders').doc(orderId).get();
    if (!doc.exists) return null;
    return OrderModel.fromMap(doc.data()!, doc.id);
  }

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

  Future<void> sendOrderNotification({
    required String vendorFcmToken,
    required String customerName,
    required double total,
    required String orderId,
  }) async {
    await _db.collection('notifications').add({
      'to': vendorFcmToken,
      'title': 'New Order!',
      'body': '$customerName placed an order for ₹${total.toStringAsFixed(0)}',
      'orderId': orderId,
      'createdAt': FieldValue.serverTimestamp(),
      'sent': false,
    });
  }

  Map<String, dynamic> buildKhataEntry({
    required String vendorId,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String orderId,
    required double amount,
  }) {
    return {
      'vendorId': vendorId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'orderId': orderId,
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
      'paid': false,
    };
  }

  Future<String> placeOrder(OrderModel order) async {
    final ref = await _db.collection('orders').add(order.toMap());

    try {
      await NotificationService.notifyVendorNewOrder(
        vendorId: order.sellerId,
        customerName: order.customerName,
        total: order.total,
        orderId: ref.id,
      );
    } catch (e) {
      // Notification failure should not block order placement.
    }

    if (order.paymentMethod == 'Khata Credit') {
      final customerDoc = await _db.collection('users').doc(order.customerId).get();
      final customerName =
          (customerDoc.data()?['name'] as String?) ?? order.customerName;
      final customerPhone = (customerDoc.data()?['phone'] as String?) ?? '';

      await _db.collection('khataEntries').add(buildKhataEntry(
        vendorId: order.sellerId,
        customerId: order.customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        orderId: ref.id,
        amount: order.total,
      ));
    }

    return ref.id;
  }

  Future<double> getCommunityImpact() async {
    final snap = await _db
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .get();

    double total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['total'] as num? ?? 0).toDouble();
    }
    return total;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final order = status == 'accepted' ? await getOrder(orderId) : null;
    await _db.collection('orders').doc(orderId).update({'status': status});

    if (order != null) {
      try {
        await NotificationService.notifyCustomerOrderAccepted(
          customerId: order.customerId,
          shopName: order.shopName,
          orderId: orderId,
        );
      } catch (e) {
        // Notification failure should not block status updates.
      }
    }
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

  Future<List<UserModel>> getNearbyVendors({
  double? customerLat,
  double? customerLng,
  double radiusKm = 10,
}) async {
  final snap = await _db
      .collection('users')
      .where('role', isEqualTo: 'vendor')
      .get();

  final vendors = snap.docs
      .map((d) => UserModel.fromMap(d.data(), d.id))
      .toList();

  // If we have customer location, sort by distance and filter by radius
  if (customerLat != null && customerLng != null) {
    final vendorsWithDistance = vendors.where((v) {
      if (v.location == null) return true; // show vendors with no location
      final dist = _haversineDistance(
        customerLat,
        customerLng,
        v.location!.latitude,
        v.location!.longitude,
      );
      return dist <= radiusKm;
    }).toList();

    vendorsWithDistance.sort((a, b) {
      if (a.location == null) return 1;
      if (b.location == null) return -1;
      final distA = _haversineDistance(
          customerLat, customerLng,
          a.location!.latitude, a.location!.longitude);
      final distB = _haversineDistance(
          customerLat, customerLng,
          b.location!.latitude, b.location!.longitude);
      return distA.compareTo(distB);
    });

    return vendorsWithDistance;
  }

  return vendors;
}

// Helper to get distance string for UI display
String getDistanceString(
    double customerLat, double customerLng, UserModel vendor) {
  if (vendor.location == null) return '';
  final dist = _haversineDistance(
    customerLat, customerLng,
    vendor.location!.latitude, vendor.location!.longitude,
  );
  if (dist < 1) return '${(dist * 1000).toStringAsFixed(0)}m';
  return '${dist.toStringAsFixed(1)}km';
}

  Future<void> toggleShopOpen(String vendorId, bool isOpen) async {
    await _db.collection('users').doc(vendorId).update({'isOpen': isOpen});
  }

  Future<void> updateVendorSettings(
    String vendorId, Map<String, dynamic> data) async {
  await _db.collection('users').doc(vendorId).update(data);
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