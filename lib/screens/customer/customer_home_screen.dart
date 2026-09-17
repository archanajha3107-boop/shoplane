import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../../models/user_model.dart';
import '../../constants/app_colors.dart';
import '../../widgets/location_bottom_sheet.dart';
import 'location_picker_screen.dart';
import 'shop_detail_screen.dart';
import 'customer_profile_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final UserModel user;
  const CustomerHomeScreen({super.key, required this.user});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedCategory = 0;
  String _searchQuery = '';
  double? _customerLat;
  double? _customerLng;
  String _shortAddress = '';
  final TextEditingController _searchController = TextEditingController();

  // Product-name search support (Bug #4): holds sellerIds of vendors whose
  // catalogue contains a product matching the search text, refreshed on
  // every keystroke via _searchProducts().
  Set<String> _matchingSellerIds = {};

  @override
  void initState() {
    super.initState();
    _customerLat = widget.user.location?.latitude;
    _customerLng = widget.user.location?.longitude;
    _shortAddress = widget.user.address;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationBottomSheet.showIfNeeded(context, (lat, lng, address) {
        setState(() {
          _customerLat = lat;
          _customerLng = lng;
          _shortAddress = address;
        });
        _loadVendors();
      });
    });
  }

  Future<void> _loadVendors() async {
    if (mounted) setState(() {});
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  // Bug #4 fix: searches product names across ALL nearby vendors' catalogues,
  // not just vendor business names. Client-side filter — fine at your
  // current data scale; if the catalogue grows to thousands of products,
  // this should move to a proper search index (e.g. Algolia) later.
  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _matchingSellerIds = {});
      return;
    }
    final snap = await FirebaseFirestore.instance.collection('products').get();
    final matches = snap.docs.where((d) {
      final name = (d.data()['name'] as String? ?? '').toLowerCase();
      return name.contains(query.toLowerCase());
    }).map((d) => d.data()['sellerId'] as String? ?? '').toSet();
    setState(() => _matchingSellerIds = matches);
  }

  final List<Map<String, dynamic>> _categories = [
    {'label': 'All', 'icon': '🏪'},
    {'label': 'Grocery', 'icon': '🛒'},
    {'label': 'Vegetables', 'icon': '🥦'},
    {'label': 'Dairy', 'icon': '🥛'},
    {'label': 'Meat & Fish', 'icon': '🍗'},
    {'label': 'Snacks', 'icon': '🍿'},
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFF0F7B6C),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Bug #8 fix: this row used to ALSO show "Delivering to
                  // <address>" — duplicating the white card below. Now it's
                  // just branding + profile avatar. The white card underneath
                  // is the single, tappable "Delivering to" display.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'ShopLane',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CustomerProfileScreen(customer: widget.user)),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: Text(
                              widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationPickerScreen(
                            initialLat: _customerLat,
                            initialLng: _customerLng,
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          _customerLat = result['lat'] as double;
                          _customerLng = result['lng'] as double;
                          _shortAddress = result['shortAddress'] as String;
                        });
                        _loadVendors();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFFE85A2B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Delivering to', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                Text(
                                  _shortAddress.isEmpty ? 'Select location' : _shortAddress,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C2C2C)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F7B6C)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) {
                          setState(() => _searchQuery = v.toLowerCase());
                          _searchProducts(v); // Bug #4 fix
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search shops or products...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: Color(0xFF0F7B6C)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(_categories.length, (i) {
                  final selected = _selectedCategory == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF0F7B6C) : const Color(0xFFF2F1EF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? const Color(0xFF0F7B6C) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Text(_categories[i]['icon'], style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            _categories[i]['label'],
                            style: TextStyle(
                              color: selected ? Colors.white : const Color(0xFF2C2C2C),
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                const Text('Shops near you', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2C2C2C))),
                const Spacer(),
                Text(
                  _shortAddress.isNotEmpty ? _shortAddress : 'Nearby',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'vendor')
              .where('isOpen', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF0F7B6C)))),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Text('🏪', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text('No shops open right now', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              );
            }

            var docs = snapshot.data!.docs;

            // Bug #9 fix: radius reduced from 15km to 2km — tight, genuinely
            // hyperlocal range. Adjust this single number if 2km still feels
            // too wide or too narrow for your test data's spread.
            const double maxDistanceKm = 2.0;
            if (_customerLat != null && _customerLng != null) {
              docs = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final geo = data['location'];
                if (geo == null) return true; // vendor with no location set yet — don't hide them entirely
                final vLat = geo.latitude as double;
                final vLng = geo.longitude as double;
                return _distanceKm(_customerLat!, _customerLng!, vLat, vLng) <= maxDistanceKm;
              }).toList();
            }

            if (_selectedCategory != 0) {
              final catLabel = _categories[_selectedCategory]['label'];
              docs = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final cat = (data['category'] ?? '').toString();
                return cat.toLowerCase().contains(catLabel.toLowerCase());
              }).toList();
            }

            if (_searchQuery.isNotEmpty) {
              docs = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final name = (data['businessName'] ?? '').toString().toLowerCase();
                final matchesName = name.contains(_searchQuery);
                final matchesProduct = _matchingSellerIds.contains(d.id); // Bug #4 fix
                return matchesName || matchesProduct;
              }).toList();
            }

            if (docs.isEmpty) {
              return const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No shops found nearby matching this.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final doc = docs[index];
                final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                data['uid'] = doc.id;
                return _VendorCard(data: data);
              }, childCount: docs.length),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _VendorCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _VendorCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final vendor = UserModel.fromMap(data, data['uid'] as String? ?? '');
    final imageUrl = (data['shopPhoto'] ?? '').toString();
    final title = (data['businessName'] ?? data['name'] ?? 'Shop').toString();
    final category = (data['category'] ?? '').toString();
    final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0;
    final minOrder = (data['minOrderValue'] as num?)?.toDouble() ?? 0;
    final isOpen = (data['isOpen'] ?? false) as bool;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShopDetailScreen(
              vendor: vendor,
              customer: UserModel(
                uid: data['uid'] as String? ?? '',
                role: 'customer',
                name: 'Customer',
                email: '',
                phone: '',
                address: '',
                fcmToken: '',
                createdAt: DateTime.now(),
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: _borderColor(category), width: 4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: Colors.grey[200]))
                    : Container(width: 56, height: 56, color: Colors.grey[200], child: const Icon(Icons.storefront, color: Colors.grey)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                   // Emoji enlarged
                    if (vendor.emoji != null && vendor.emoji!.isNotEmpty)
                      Text(vendor.emoji!, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (data['rating'] != null)
                          Row(
                            children: [
                              const Icon(Icons.star, color: AppColors.gold, size: 14),
                              const SizedBox(width: 2),
                              Text(data['rating'].toString(), style: const TextStyle(fontSize: 12, color: AppColors.gold)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(category, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(child: Text('₹${deliveryFee.toStringAsFixed(0)} delivery', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Flexible(child: Text('Min ₹${minOrder.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Distance badge
                    Text('0.3 km', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    // Free delivery chip
                    if (deliveryFee == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.emerald, borderRadius: BorderRadius.circular(6)),
                        child: const Text('Free Delivery', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              // Open/Closed badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: isOpen ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(6)),
                child: Text(isOpen ? 'Open' : 'Closed', style: TextStyle(color: isOpen ? Colors.green[700] : Colors.red[700], fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _borderColor(String category) {
    switch (category.toLowerCase()) {
      case 'grocery':
        return AppColors.emerald;
      case 'vegetables':
        return AppColors.vegetable;
      case 'dairy':
        return AppColors.gold;
      case 'meat & fish':
      case 'meat & fish':
        return AppColors.terracotta;
      case 'snacks':
        return AppColors.snack;
      case 'newspaper':
        return AppColors.newspaper;
      default:
        return AppColors.other;
    }
  }
}
