import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/vendor_matching_service.dart';
import 'shop_detail_screen.dart';

class VendorMatchResultsScreen extends StatefulWidget {
  final UserModel customer;
  final List<String> wishlist;
  const VendorMatchResultsScreen({super.key, required this.customer, required this.wishlist});

  @override
  State<VendorMatchResultsScreen> createState() => _VendorMatchResultsScreenState();
}

class _VendorMatchResultsScreenState extends State<VendorMatchResultsScreen> {
  List<VendorMatch> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _findMatches();
  }

  Future<void> _findMatches() async {
    final lat = widget.customer.location?.latitude ?? 19.0760;
    final lng = widget.customer.location?.longitude ?? 72.8777;
    final results = await VendorMatchingService().matchVendors(
      wishlistNames: widget.wishlist,
      customerLat: lat,
      customerLng: lng,
    );
    if (mounted) setState(() { _matches = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Best matches near you'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F7B6C)))
          : _matches.isEmpty
              ? const Center(child: Text('No nearby shops have these items', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _matches.length,
                  itemBuilder: (context, i) {
                    final m = _matches[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(m.vendor.businessName ?? m.vendor.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C2C2C))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: m.matchedItemCount == m.totalCartItems
                                      ? const Color(0xFF0F7B6C).withValues(alpha: 0.1)
                                      : const Color(0xFFC9A227).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${m.matchedItemCount}/${m.totalCartItems} items',
                                  style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold,
                                    color: m.matchedItemCount == m.totalCartItems ? const Color(0xFF0F7B6C) : const Color(0xFFC9A227),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${m.distanceKm.toStringAsFixed(1)} km away · ${m.vendor.category ?? ""}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShopDetailScreen(vendor: m.vendor, customer: widget.customer),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE85A2B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('View shop & order', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}