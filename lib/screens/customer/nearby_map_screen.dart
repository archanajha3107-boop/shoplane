import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/overpass_service.dart';
import 'shop_detail_screen.dart';

class NearbyMapScreen extends StatefulWidget {
  final UserModel customer;
  final double customerLat;
  final double customerLng;

  const NearbyMapScreen({
    super.key,
    required this.customer,
    required this.customerLat,
    required this.customerLng,
  });

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  List<UserModel> _registeredVendors = [];
  List<NearbyShop> _osmShops = [];
  bool _loading = true;
  UserModel? _selectedVendor;
  NearbyShop? _selectedOsmShop;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Load registered vendors and OSM shops in parallel
    final results = await Future.wait([
      FirestoreService().getNearbyVendors(
        customerLat: widget.customerLat,
        customerLng: widget.customerLng,
        radiusKm: 2,
      ),
      OverpassService().getNearbyShops(
        lat: widget.customerLat,
        lng: widget.customerLng,
        radiusMeters: 1500,
      ),
    ]);

    if (mounted) {
      setState(() {
        _registeredVendors = results[0] as List<UserModel>;
        _osmShops = results[1] as List<NearbyShop>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Nearby Shops'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(widget.customerLat, widget.customerLng),
              initialZoom: 15,
              onTap: (_, _) => setState(() {
                _selectedVendor = null;
                _selectedOsmShop = null;
              }),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.shoplane',
              ),
              // Customer position
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.customerLat, widget.customerLng),
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              // OSM unregistered shops — grey markers
              MarkerLayer(
                markers: _osmShops
                    .where((s) {
                      // Don't show if a registered vendor is at the same location
                      return !_registeredVendors.any(
                        (v) =>
                            v.location != null &&
                            (v.location!.latitude - s.lat).abs() < 0.0002 &&
                            (v.location!.longitude - s.lng).abs() < 0.0002,
                      );
                    })
                    .map(
                      (shop) => Marker(
                        point: LatLng(shop.lat, shop.lng),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedOsmShop = shop;
                            _selectedVendor = null;
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              // Registered vendors — emerald markers
              MarkerLayer(
                markers: _registeredVendors
                    .where((v) => v.location != null)
                    .map(
                      (vendor) => Marker(
                        point: LatLng(
                          vendor.location!.latitude,
                          vendor.location!.longitude,
                        ),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedVendor = vendor;
                            _selectedOsmShop = null;
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              color: vendor.isOpen ?? false
                                  ? const Color(0xFF0F7B6C)
                                  : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 6),
                              ],
                            ),
                            child: const Icon(
                              Icons.storefront,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          // Loading overlay
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F7B6C)),
              ),
            ),
          // Legend
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legendRow(const Color(0xFF0F7B6C), 'On ShopLane'),
                  const SizedBox(height: 4),
                  _legendRow(Colors.grey, 'Not registered'),
                  const SizedBox(height: 4),
                  _legendRow(Colors.blue, 'You'),
                ],
              ),
            ),
          ),
          // Bottom card for selected marker
          if (_selectedVendor != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _VendorCard(
                vendor: _selectedVendor!,
                customer: widget.customer,
                onClose: () => setState(() => _selectedVendor = null),
              ),
            ),
          if (_selectedOsmShop != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _OsmShopCard(
                shop: _selectedOsmShop!,
                onClose: () => setState(() => _selectedOsmShop = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF2C2C2C)),
        ),
      ],
    );
  }
}

class _VendorCard extends StatelessWidget {
  final UserModel vendor;
  final UserModel customer;
  final VoidCallback onClose;

  const _VendorCard({
    required this.vendor,
    required this.customer,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.businessName ?? vendor.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                    Text(
                      vendor.category ?? 'General',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: (vendor.isOpen ?? false)
                      ? const Color(0xFF0F7B6C)
                      : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                (vendor.isOpen ?? false) ? 'Open now' : 'Closed',
                style: TextStyle(
                  color: (vendor.isOpen ?? false)
                      ? const Color(0xFF0F7B6C)
                      : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Delivery ₹${vendor.deliveryFee?.toStringAsFixed(0) ?? '0'}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (vendor.isOpen ?? false)
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopDetailScreen(
                          vendor: vendor,
                          customer: customer,
                        ),
                      ),
                    )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85A2B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                (vendor.isOpen ?? false) ? 'Order Now' : 'Shop Closed',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OsmShopCard extends StatelessWidget {
  final NearbyShop shop;
  final VoidCallback onClose;

  const _OsmShopCard({required this.shop, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                    Text(
                      shop.type,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This shop is not on ShopLane yet. Know the owner? Tell them to register!',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
