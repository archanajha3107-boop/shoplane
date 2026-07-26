import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../widgets/location_bottom_sheet.dart';
import 'location_picker_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      body: CustomScrollView(
        slivers: [
          // Top bar — location + search
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF0F7B6C),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Location row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Delivering to',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                              Text(
                                widget.user.address.isNotEmpty
                                    ? widget.user.address
                                    : 'Magathane, Borivali East',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const Spacer(),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            child: Text(
                              widget.user.name.isNotEmpty
                                  ? widget.user.name[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: Color(0xFFE85A2B), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Delivering to',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 11)),
                                  Text(
                                    _shortAddress.isEmpty
                                        ? 'Select location'
                                        : _shortAddress,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF2C2C2C)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF0F7B6C)),
                          ],
                        ),
                      ),
                    ),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) =>
                              setState(() => _searchQuery = v.toLowerCase()),
                          decoration: const InputDecoration(
                            hintText: 'Search shops or products...',
                            hintStyle: TextStyle(
                                color: Colors.grey, fontSize: 14),
                            prefixIcon: Icon(Icons.search,
                                color: Color(0xFF0F7B6C)),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Category chips
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
                      onTap: () =>
                          setState(() => _selectedCategory = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF0F7B6C)
                              : const Color(0xFFF2F1EF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF0F7B6C)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(_categories[i]['icon'],
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              _categories[i]['label'],
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF2C2C2C),
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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

          // Section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  const Text(
                    'Shops near you',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Magathane area',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Vendor list from Firestore
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'vendor')
                .where('isOpen', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                          color: Color(0xFF0F7B6C)),
                    ),
                  ),
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
                          Text('No shops open right now',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              var docs = snapshot.data!.docs;

              // Filter by category
              if (_selectedCategory != 0) {
                final catLabel = _categories[_selectedCategory]['label'];
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final cat = (data['category'] ?? '').toString();
                  return cat.toLowerCase().contains(catLabel.toLowerCase());
                }).toList();
              }

              // Filter by search
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['businessName'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _VendorCard(data: data);
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF0F7B6C).withValues(alpha: 0.1),
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded,
                  color: Color(0xFF0F7B6C)),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded,
                  color: Color(0xFF0F7B6C)),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded,
                  color: Color(0xFF0F7B6C)),
              label: 'Profile'),
        ],
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _VendorCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['businessName'] ?? 'Shop';
    final category = data['category'] ?? '';
    final deliveryFee = (data['deliveryFee'] ?? 0).toDouble();
    final minOrder = (data['minOrderValue'] ?? 0).toDouble();
    final offersDelivery = data['offersDelivery'] ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Shop icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F7B6C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _categoryEmoji(category),
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Shop info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (offersDelivery) ...[
                            Icon(Icons.delivery_dining_rounded,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 3),
                            Text(
                              deliveryFee == 0
                                  ? 'Free delivery'
                                  : '₹${deliveryFee.toInt()} delivery',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Icon(Icons.shopping_bag_outlined,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 3),
                          Text(
                            'Min ₹${minOrder.toInt()}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Open badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F7B6C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Open',
                    style: TextStyle(
                      color: Color(0xFF0F7B6C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _categoryEmoji(String category) {
    if (category.contains('Grocery')) return '🛒';
    if (category.contains('Dairy') || category.contains('Milk')) return '🥛';
    if (category.contains('Vegetable') || category.contains('Fruit')) return '🥦';
    if (category.contains('Meat') || category.contains('Fish')) return '🍗';
    if (category.contains('Snack')) return '🍿';
    return '🏪';
  }
}