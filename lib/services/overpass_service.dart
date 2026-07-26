import 'dart:convert';
import 'package:http/http.dart' as http;

class NearbyShop {
  final String name;
  final double lat;
  final double lng;
  final String type;
  final bool isRegistered;

  NearbyShop({
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    this.isRegistered = false,
  });
}

class OverpassService {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<NearbyShop>> getNearbyShops({
    required double lat,
    required double lng,
    double radiusMeters = 1000,
  }) async {
    final query = '''
[out:json][timeout:10];
(
  node["shop"~"grocery|supermarket|convenience|general|kirana|vegetables|butcher|seafood|dairy|farm"](around:$radiusMeters,$lat,$lng);
  node["amenity"="marketplace"](around:$radiusMeters,$lat,$lng);
);
out body;
''';

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            body: query,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final elements = data['elements'] as List<dynamic>? ?? [];

      return elements
          .where((e) =>
              e['lat'] != null &&
              e['lon'] != null &&
              e['tags']?['name'] != null)
          .map((e) {
        final tags = e['tags'] as Map<String, dynamic>;
        final shopType =
            (tags['shop'] ?? tags['amenity'] ?? 'shop') as String;
        return NearbyShop(
          name: tags['name'] as String,
          lat: (e['lat'] as num).toDouble(),
          lng: (e['lon'] as num).toDouble(),
          type: _mapShopType(shopType),
        );
      }).toList();
    } catch (e) {
      // Overpass timeout or no internet — return empty, don't crash
      return [];
    }
  }

  String _mapShopType(String rawType) {
    switch (rawType.toLowerCase()) {
      case 'grocery':
      case 'supermarket':
      case 'convenience':
      case 'general':
        return 'Grocery & Provisions';
      case 'vegetables':
        return 'Vegetables & Fruits';
      case 'butcher':
      case 'seafood':
        return 'Meat & Fish';
      case 'dairy':
      case 'farm':
        return 'Milk & Dairy';
      default:
        return 'General';
    }
  }
}