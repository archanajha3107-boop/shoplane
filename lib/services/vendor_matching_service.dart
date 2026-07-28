import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../utils/fuzzy_match.dart';

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

  /// Given a wishlist of product names, find nearby open vendors ranked by
  /// how many items they can fulfill (using fuzzy matching), then by distance.
  Future<List<VendorMatch>> matchVendors({
    required List<String> wishlistNames,
    required double customerLat,
    required double customerLng,
    double radiusKm = 5,
  }) async {
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
        final hit = products.where((p) => isFuzzyMatch(p.name, wishItem));
        if (hit.isNotEmpty) matched.add(hit.first);
      }

      if (matched.isEmpty) continue;

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

    matches.sort((a, b) {
      final scoreCompare = b.matchScore.compareTo(a.matchScore);
      if (scoreCompare != 0) return scoreCompare;
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return matches;
  }

  /// Greedy Set Cover approximation — used only as a documented, designed
  /// concept for now. NOT wired into tomorrow's demo flow. Queued for the
  /// sprint after the pilot, once single-vendor matching is proven stable.
  List<VendorMatch> greedySetCover(List<VendorMatch> allMatches, List<String> wishlist) {
    final Set<String> uncovered = wishlist.map((e) => e.toLowerCase()).toSet();
    final List<VendorMatch> chosen = [];
    final remaining = List<VendorMatch>.from(allMatches);

    while (uncovered.isNotEmpty && remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final aCover = a.matchedProducts.where((p) => uncovered.any((u) => isFuzzyMatch(p.name, u))).length;
        final bCover = b.matchedProducts.where((p) => uncovered.any((u) => isFuzzyMatch(p.name, u))).length;
        return bCover.compareTo(aCover);
      });

      final best = remaining.first;
      final coveredByBest = best.matchedProducts.where((p) => uncovered.any((u) => isFuzzyMatch(p.name, u))).toList();
      if (coveredByBest.isEmpty) break;

      chosen.add(best);
      for (final p in coveredByBest) {
        uncovered.removeWhere((u) => isFuzzyMatch(p.name, u));
      }
      remaining.remove(best);
    }
    return chosen;
  }
}