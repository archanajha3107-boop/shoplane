import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../role_selection_screen.dart';
import 'shop_detail_screen.dart';
import 'customer_profile_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final UserModel customer;
  const CustomerHomeScreen({super.key, required this.customer});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  double? _customerLat;
  double? _customerLng;
  List<UserModel> _allVendors = [];
  bool _loading = true;

  final List<String> _categories = [
    'All', 'Grocery & Provisions', 'Vegetables & Fruits',
    'Milk & Dairy', 'Meat & Fish', 'Snacks & Food Stalls',
  ];

  @override
  void initState() {
    super.initState();
    _loadLocationAndVendors();
  }

  Future<void> _loadLocationAndVendors() async {
    setState(() => _loading = true);

    // Get customer GPS
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _customerLat = pos.latitude;
      _customerLng = pos.longitude;
    } catch (e) {
      // Use stored location from profile if GPS fails
      if (widget.customer.location != null) {
        _customerLat = widget.customer.location!.latitude;
        _customerLng = widget.customer.location!.longitude;
      }
    }

    // Fetch vendors sorted by distance
    final vendors = await FirestoreService().getNearbyVendors(
      customerLat: _customerLat,
      customerLng: _customerLng,
    );

    if (mounted) {
      setState(() {
        _allVendors = vendors;
        _loading = false;
      });
    }
  }

  List<UserModel> get _filteredVendors {
    return _allVendors.where((v) {
      final matchesCategory = _selectedCategory == 'All' ||
          v.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          (v.businessName ?? v.name)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('ShopLane'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CustomerProfileScreen(customer: widget.customer),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0F7B6C),
        onRefresh: _loadLocationAndVendors,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting + search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${widget.customer.name.split(' ').first}!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                  const Text('What do you need today?',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 12),
                  FutureBuilder<double>(
                    future: FirestoreService().getCommunityImpact(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F7B6C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '₹${snap.data!.toStringAsFixed(0)} kept in your neighbourhood this month',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Search bar
                  TextField(
                    onChanged: (v) =>
                        setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search shops...',
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFF0F7B6C)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Category chips
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF0F7B6C)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF0F7B6C)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF2C2C2C),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Nearby Shops',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C2C2C)),
                  ),
                  const SizedBox(width: 8),
                  if (_customerLat != null)
                    const Icon(Icons.location_on,
                        color: Color(0xFF0F7B6C), size: 14),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Vendor list
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF0F7B6C)))
                  : _filteredVendors.isEmpty
                      ? const Center(
                          child: Text('No shops found',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          itemCount: _filteredVendors.length,
                          itemBuilder: (context, i) => _ShopCard(
                            vendor: _filteredVendors[i],
                            customer: widget.customer,
                            customerLat: _customerLat,
                            customerLng: _customerLng,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final UserModel vendor;
  final UserModel customer;
  final double? customerLat;
  final double? customerLng;

  const _ShopCard({
    required this.vendor,
    required this.customer,
    this.customerLat,
    this.customerLng,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final distStr = (customerLat != null &&
            customerLng != null &&
            vendor.location != null)
        ? fs.getDistanceString(
            customerLat!, customerLng!, vendor)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vendor.businessName ?? vendor.name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C2C2C)),
                ),
              ),
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
                  const SizedBox(width: 4),
                  Text(
                    (vendor.isOpen ?? false) ? 'Open' : 'Closed',
                    style: TextStyle(
                        fontSize: 12,
                        color: (vendor.isOpen ?? false)
                            ? const Color(0xFF0F7B6C)
                            : Colors.red),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (vendor.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A227)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    vendor.category!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFC9A227),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              if (distStr.isNotEmpty) ...[
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Icon(Icons.near_me,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(distStr,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
              if (vendor.deliveryFee != null) ...[
                const SizedBox(width: 8),
                Text(
                  'Delivery ₹${vendor.deliveryFee!.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12),
                ),
              ],
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
                disabledBackgroundColor: Colors.grey.shade300,
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                (vendor.isOpen ?? false)
                    ? 'Order Now'
                    : 'Shop Closed',
                style: const TextStyle(
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}