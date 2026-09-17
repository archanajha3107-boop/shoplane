import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  // FCM HTTP v1 API — sends from client using the vendor/customer's
  // own auth token. Works on free tier.
  
  static Future<void> sendToToken({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (fcmToken.isEmpty) return;

    try {
      // Get current user's ID token for auth
      final idToken = await FirebaseAuth.instance.currentUser
          ?.getIdToken();
      if (idToken == null) return;

      await http.post(
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/shoplane-a39b9/messages:send',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': data ?? {},
            'android': {
              'priority': 'high',
              'notification': {
                'sound': 'default',
                'channel_id': 'shoplane_orders',
              },
            },
          },
        }),
      );
    } catch (e) {
      // Notification failure is non-critical — don't crash the app
      print('FCM send failed: $e');
    }
  }

  // Call this when customer places an order
  static Future<void> notifyVendorNewOrder({
    required String vendorId,
    required String customerName,
    required double total,
    required String orderId,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(vendorId)
        .get();
    final token = doc.data()?['fcmToken'] as String? ?? '';

    await sendToToken(
      fcmToken: token,
      title: '🛍️ New Order!',
      body: '$customerName placed an order for ₹${total.toInt()}',
      data: {'orderId': orderId, 'type': 'new_order'},
    );
  }

  // Call this when vendor accepts
  static Future<void> notifyCustomerOrderAccepted({
    required String customerId,
    required String shopName,
    required String orderId,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(customerId)
        .get();
    final token = doc.data()?['fcmToken'] as String? ?? '';

    await sendToToken(
      fcmToken: token,
      title: '✅ Order Accepted!',
      body: '$shopName accepted your order. Get ready!',
      data: {'orderId': orderId, 'type': 'order_accepted'},
    );
  }

  // Call this on order timeout — suggest next vendor
  static Future<void> notifyCustomerTimeout({
    required String customerId,
    required String originalShopName,
    required String? alternativeShopName,
    required String orderId,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(customerId)
        .get();
    final token = doc.data()?['fcmToken'] as String? ?? '';

    final body = alternativeShopName != null
        ? '$originalShopName didn\'t respond. Try $alternativeShopName nearby!'
        : '$originalShopName didn\'t respond. Please try another shop.';

    await sendToToken(
      fcmToken: token,
      title: '⏱️ Order Timed Out',
      body: body,
      data: {
        'orderId': orderId,
        'type': 'timeout',
        if (alternativeShopName != null) 'suggestion': alternativeShopName,
      },
    );
  }
}