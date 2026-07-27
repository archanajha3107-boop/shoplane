import 'dart:convert';
import 'package:http/http.dart' as http;

class RemoteProduct {
  final String name;
  final String brand;
  final String imageUrl;
  final String category;
  final String barcode;

  RemoteProduct({
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.category,
    required this.barcode,
  });
}

class ProductLookupService {
  /// Free-text search against Open Food Facts (v1 API — the only one
  /// supporting free-text search). No key, no billing, rate-limited
  /// only for abusive traffic which a college project won't hit.
  Future<List<RemoteProduct>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query)}'
        '&search_simple=1&action=process&json=1&page_size=15'
        '&fields=product_name,brands,image_front_small_url,categories',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'ShopLane-StudentProject/1.0 (college project)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final products = data['products'] as List<dynamic>? ?? [];

      return products
          .where((p) => p['product_name'] != null && (p['product_name'] as String).isNotEmpty)
          .map((p) => RemoteProduct(
                name: p['product_name'] ?? '',
                brand: p['brands'] ?? 'Generic',
                imageUrl: p['image_front_small_url'] ?? '',
                category: _guessCategory(p['categories'] ?? ''),
                barcode: p['code'] ?? '',
              ))
          .toList();
    } catch (e) {
      return []; // graceful fallback — never crash the search screen
    }
  }

  String _guessCategory(String rawCategories) {
    final c = rawCategories.toLowerCase();
    if (c.contains('dairy') || c.contains('milk')) return 'Dairy';
    if (c.contains('snack') || c.contains('chip')) return 'Snacks';
    if (c.contains('fruit')) return 'Fruits';
    if (c.contains('vegetable')) return 'Vegetables';
    if (c.contains('meat') || c.contains('fish')) return 'Meat & Fish';
    return 'Groceries';
  }
}