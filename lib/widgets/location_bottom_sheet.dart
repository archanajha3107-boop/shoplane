import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/customer/location_picker_screen.dart';

class LocationBottomSheet extends StatelessWidget {
  final Function(double lat, double lng, String address) onLocationSet;
  const LocationBottomSheet({super.key, required this.onLocationSet});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSet = prefs.getInt('location_timestamp') ?? 0;
    final hoursSince = (DateTime.now().millisecondsSinceEpoch - lastSet) / (1000 * 60 * 60);
    return hoursSince > 6; // Re-ask every 6 hours
  }

  static Future<void> markSet(double lat, double lng, String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('location_timestamp', DateTime.now().millisecondsSinceEpoch);
    await prefs.setDouble('location_lat', lat);
    await prefs.setDouble('location_lng', lng);
    await prefs.setString('location_address', address);
  }

  static Future<Map<String, dynamic>?> getSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('location_lat');
    final lng = prefs.getDouble('location_lng');
    final address = prefs.getString('location_address');
    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng, 'address': address ?? ''};
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.location_on_rounded, color: Color(0xFFE85A2B), size: 48),
          const SizedBox(height: 12),
          const Text('Where should we deliver?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
                );
                if (result != null) {
                  await markSet(result['lat'], result['lng'], result['shortAddress']);
                  onLocationSet(result['lat'], result['lng'], result['shortAddress']);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Use current location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F7B6C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
                );
                if (result != null) {
                  await markSet(result['lat'], result['lng'], result['shortAddress']);
                  onLocationSet(result['lat'], result['lng'], result['shortAddress']);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Enter manually'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F7B6C),
                side: const BorderSide(color: Color(0xFF0F7B6C)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showIfNeeded(BuildContext context, Function(double, double, String) onSet) async {
    final needed = await shouldShow();
    if (!needed) {
      final saved = await getSaved();
      if (saved != null) onSet(saved['lat'], saved['lng'], saved['address']);
      return;
    }
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      builder: (_) => LocationBottomSheet(onLocationSet: onSet),
    );
  }
}