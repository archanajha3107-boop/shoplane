import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth_error_handler.dart';

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
    String? flat,
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
        flat: flat,
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
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(formatAuthError(e));
    } catch (e) {
      throw AuthFailure(formatAuthError(e));
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
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(formatAuthError(e));
    } catch (e) {
      throw AuthFailure(formatAuthError(e));
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

      // THIS WAS THE BUG: doc.data() can be null if no Firestore profile
      // exists for this UID (e.g. signup's Firestore write never completed,
      // or the document was deleted during testing). Casting null straight
      // to Map<String, dynamic> throws a raw TypeError — which isn't a
      // FirebaseAuthException or PlatformException, so it fell through
      // formatAuthError()'s switch statements straight to the generic
      // "Something went wrong. Please try again." fallback, hiding the
      // real cause completely.
      if (!doc.exists || doc.data() == null) {
        throw AuthFailure(
          'Your login was successful, but no profile data was found for this account. '
          'This can happen if signup was interrupted. Please contact support or try signing up again.',
        );
      }

      await updateFcmToken(user.uid);
      return UserModel.fromMap(
          doc.data() as Map<String, dynamic>, user.uid);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(formatAuthError(e));
    } catch (e) {
      throw AuthFailure(formatAuthError(e));
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
      throw AuthFailure(formatAuthError(e));
    }
  }
}