import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  // Firebase Auth instance — handles login/signup
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Firestore instance — handles database read/write
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Returns current logged-in user (null if not logged in)
  User? get currentUser => _auth.currentUser;

  Future<GeoPoint?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (e) {
      return null;
    }
  }
  Future<OrderModel?> getLastOrderFromShop(
    String customerId, String sellerId) async {
  final snap = await _db
      .collection('orders')
      .where('customerId', isEqualTo: customerId)
      .where('sellerId', isEqualTo: sellerId)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .get();
  if (snap.docs.isEmpty) return null;
  return OrderModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
}

  // CUSTOMER SIGNUP
  Future<UserModel?> signUpCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String address,
  }) async {
    try {
      // Creates account in Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user == null) return null;

      // Capture GPS at signup
      final location = await _getCurrentLocation();

      // Builds user object with customer role
      UserModel newUser = UserModel(
        uid: user.uid,
        role: 'customer',
        name: name,
        email: email,
        phone: phone,
        address: address,
        location: location,
        fcmToken: '',
        createdAt: DateTime.now(),
      );

      // Saves user data to Firestore users collection
      await _db.collection('users').doc(user.uid).set(newUser.toMap());
      // Save FCM token for push notifications
      await updateFcmToken(user.uid);
      return newUser;
    } catch (e) {
      rethrow;
    }
  }

  // VENDOR SIGNUP
  Future<UserModel?> signUpVendor({
    required String businessName,
    required String ownerName,
    required String email,
    required String phone,
    required String password,
    required String address,
    required String category,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user == null) return null;

      // Capture GPS at signup
      final location = await _getCurrentLocation();

      UserModel newUser = UserModel(
        uid: user.uid,
        role: 'vendor',
        name: ownerName,
        email: email,
        phone: phone,
        address: address,
        location: location,
        fcmToken: '',
        createdAt: DateTime.now(),
        businessName: businessName,
        category: category,
        isOpen: false,
        offersDelivery: true,
        offersPickup: true,
        deliveryFee: 0,
        minOrderValue: 0,
        deliveryRadius: 2,
        isVerified: false,
      );

      await _db.collection('users').doc(user.uid).set(newUser.toMap());
      // Save FCM token for push notifications
      await updateFcmToken(user.uid);
      return newUser;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({
          'fcmToken': token,
        });
      }
    } catch (e) {
      // FCM token update is non-critical, fail silently
    }
  }

  // LOGIN (same for both customer and vendor)
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user == null) return null;

      // Fetches user data from Firestore after login
      DocumentSnapshot doc =
          await _db.collection('users').doc(user.uid).get();
      await updateFcmToken(user.uid);
      return UserModel.fromMap(
          doc.data() as Map<String, dynamic>, user.uid);
    } catch (e) {
      rethrow;
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  // GET USER DATA from Firestore by uid
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(
          doc.data() as Map<String, dynamic>, uid);
    } catch (e) {
      rethrow;
    }
  }
}