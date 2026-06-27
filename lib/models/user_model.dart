import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String role; // 'customer' or 'vendor'
  final String name;
  final String email;
  final String phone;
  final GeoPoint? location;
  final String address;
  final String fcmToken;
  final DateTime createdAt;

  // Vendor-only fields
  final String? businessName;
  final String? category;
  final String? shopPhoto;
  final bool? isOpen;
  final bool? offersDelivery;
  final bool? offersPickup;
  final double? deliveryFee;
  final double? minOrderValue;
  final double? deliveryRadius;
  final String? esp32DeviceId;
  final bool? isVerified;

  UserModel({
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    this.location,
    required this.address,
    required this.fcmToken,
    required this.createdAt,
    this.businessName,
    this.category,
    this.shopPhoto,
    this.isOpen,
    this.offersDelivery,
    this.offersPickup,
    this.deliveryFee,
    this.minOrderValue,
    this.deliveryRadius,
    this.esp32DeviceId,
    this.isVerified,
  });

  // Converts Firestore document → Dart object
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      role: map['role'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      location: map['location'],
      address: map['address'] ?? '',
      fcmToken: map['fcmToken'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      businessName: map['businessName'],
      category: map['category'],
      shopPhoto: map['shopPhoto'],
      isOpen: map['isOpen'],
      offersDelivery: map['offersDelivery'],
      offersPickup: map['offersPickup'],
      deliveryFee: map['deliveryFee']?.toDouble(),
      minOrderValue: map['minOrderValue']?.toDouble(),
      deliveryRadius: map['deliveryRadius']?.toDouble(),
      esp32DeviceId: map['esp32DeviceId'],
      isVerified: map['isVerified'],
    );
  }

  // Converts Dart object → Map to save to Firestore
  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'name': name,
      'email': email,
      'phone': phone,
      'location': location,
      'address': address,
      'fcmToken': fcmToken,
      'createdAt': createdAt,
      if (businessName != null) 'businessName': businessName,
      if (category != null) 'category': category,
      if (shopPhoto != null) 'shopPhoto': shopPhoto,
      if (isOpen != null) 'isOpen': isOpen,
      if (offersDelivery != null) 'offersDelivery': offersDelivery,
      if (offersPickup != null) 'offersPickup': offersPickup,
      if (deliveryFee != null) 'deliveryFee': deliveryFee,
      if (minOrderValue != null) 'minOrderValue': minOrderValue,
      if (deliveryRadius != null) 'deliveryRadius': deliveryRadius,
      if (esp32DeviceId != null) 'esp32DeviceId': esp32DeviceId,
      if (isVerified != null) 'isVerified': isVerified,
    };
  }
}