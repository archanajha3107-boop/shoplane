import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/user_model.dart';
import '../models/product_model.dart';

class VendorMatch {
  final UserModel vendor;
  final int matchedItemCount;
  final int totalCartItems;
  final double distanceKm;
  final List<ProductModel> matchedProducts;

  VendorMatch({
    required this.vendor,
    required this.matchedItemCount,
    required this.totalCartItems,
    required this.distanceKm,
    required this.matchedProducts,
  });

  double get matchScore => matchedItemCount / totalCartItems;
}

class VendorMatchingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Given a wishlist of product names, find nearby vendors ranked by
  /// how many items they can fulfill, then by distance.
  Future<List<VendorMatch>> matchVendors({
    required List<String> wishlistNames,
    required double customerLat,
    required double customerLng,
    double radiusKm = 5,
  }) async {
    // 1. Get all open vendors within radius
    final vendorSnap = await _db.collection('users')
        .where('role', isEqualTo: 'vendor')
        .where('isOpen', isEqualTo: true)
        .get();

    final vendors = vendorSnap.docs
        .map((d) => UserModel.fromMap(d.data(), d.id))
        .where((v) => v.location != null)
        .where((v) => _haversine(customerLat, customerLng,
            v.location!.latitude, v.location!.longitude) <= radiusKm)
        .toList();

    if (vendors.isEmpty) return [];

    // 2. For each vendor, fetch their in-stock products and count matches
    final List<VendorMatch> matches = [];
    for (final vendor in vendors) {
      final productSnap = await _db.collection('products')
          .where('sellerId', isEqualTo: vendor.uid)
          .where('inStock', isEqualTo: true)
          .get();

      final products = productSnap.docs
          .map((d) => ProductModel.fromMap(d.data(), d.id))
          .toList();

      final matched = <ProductModel>[];
      for (final wishItem in wishlistNames) {
        final hit = products.where((p) =>
            p.name.toLowerCase().contains(wishItem.toLowerCase()) ||
            wishItem.toLowerCase().contains(p.name.toLowerCase()));
        if (hit.isNotEmpty) matched.add(hit.first);
      }

      if (matched.isEmpty) continue; // skip vendors with zero matches

      final dist = _haversine(customerLat, customerLng,
          vendor.location!.latitude, vendor.location!.longitude);

      matches.add(VendorMatch(
        vendor: vendor,
        matchedItemCount: matched.length,
        totalCartItems: wishlistNames.length,
        distanceKm: dist,
        matchedProducts: matched,
      ));
    }

    // 3. Rank: highest match % first, then closest distance
    matches.sort((a, b) {
      final scoreCompare = b.matchScore.compareTo(a.matchScore);
      if (scoreCompare != 0) return scoreCompare;
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return matches;
  }
}