// delivery_fee_calculator.dart
// Calculates a dynamic delivery fee based on real distance between
// customer and vendor, instead of one fixed fee for everyone regardless
// of how far they are.

import 'dart:math' as math;

class DeliveryFeeCalculator {
  // Tune these to whatever makes sense for your actual test area.
  static const double baseFee = 15.0;       // flat fee for anything under 500m
  static const double perKmRate = 8.0;      // rupees added per km beyond that
  static const double maxFee = 60.0;        // cap so it never looks absurd

  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double calculate({
    required double customerLat,
    required double customerLng,
    required double vendorLat,
    required double vendorLng,
  }) {
    final distanceKm = _distanceKm(customerLat, customerLng, vendorLat, vendorLng);
    if (distanceKm <= 0.5) return baseFee;

    final extraKm = distanceKm - 0.5;
    final fee = baseFee + (extraKm * perKmRate);
    return fee > maxFee ? maxFee : double.parse(fee.toStringAsFixed(0));
  }
}