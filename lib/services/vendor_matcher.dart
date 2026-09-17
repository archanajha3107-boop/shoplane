// vendor_matcher.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class VendorMatch {
  final UserModel vendor;
  final List<String> itemsCovered;
  VendorMatch({required this.vendor, required this.itemsCovered});
}

class SetCoverResult {
  final List<VendorMatch> matches;
  final List<String> unavailableItems;
  SetCoverResult({required this.matches, required this.unavailableItems});
}

Future<SetCoverResult> findVendorsForList(
  List<String> shoppingList,
  List<UserModel> nearbyVendors,
) async {
  final db = FirebaseFirestore.instance;
  final normalizedList = shoppingList.map((e) => e.trim().toLowerCase()).toSet();

  final Map<String, List<String>> vendorItemNames = {};
  for (final vendor in nearbyVendors) {
    final snap = await db
        .collection('products')
        .where('sellerId', isEqualTo: vendor.uid)
        .where('inStock', isEqualTo: true)
        .get();
    vendorItemNames[vendor.uid] =
        snap.docs.map((d) => (d.data()['name'] as String? ?? '').toLowerCase()).toList();
  }

  final uncovered = Set<String>.from(normalizedList);
  final matches = <VendorMatch>[];

  while (uncovered.isNotEmpty) {
    UserModel? bestVendor;
    List<String> bestCoverage = [];

    for (final vendor in nearbyVendors) {
      final items = vendorItemNames[vendor.uid] ?? [];
      final coverage = uncovered.where((item) => items.contains(item)).toList();
      if (coverage.length > bestCoverage.length) {
        bestVendor = vendor;
        bestCoverage = coverage;
      }
    }

    if (bestVendor == null || bestCoverage.isEmpty) break;
    matches.add(VendorMatch(vendor: bestVendor, itemsCovered: bestCoverage));
    uncovered.removeAll(bestCoverage);
  }

  return SetCoverResult(matches: matches, unavailableItems: uncovered.toList());
}