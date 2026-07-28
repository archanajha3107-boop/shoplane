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
  List<VendorMatch> _fullMatch = [];
  List<VendorMatch> _splitPlan = [];
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
    final fullMatch = results.where((m) => m.matchedItemCount == m.totalCartItems).toList();
    final splitPlan = fullMatch.isEmpty
    ? VendorMatchingService().greedySetCover(results, widget.wishlist)
    : <VendorMatch>[];    if (mounted) setState(() {
      _matches = results;
      _fullMatch = fullMatch;
      _splitPlan = splitPlan;
      _loading = false;
    });
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
                  itemCount: _matches.length + (_fullMatch.isEmpty && _splitPlan.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_fullMatch.isEmpty && _splitPlan.isNotEmpty && i == 0) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC9A227).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No single shop has everything — smart split suggested:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC9A227),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ..._splitPlan.map((m) => Text(
                                  '• ${m.vendor.businessName ?? m.vendor.name} — ${m.matchedItemCount} items',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF2C2C2C)),
                                )),
                          ],
                        ),
                      );
                    }
                    final matchIndex = _fullMatch.isEmpty && _splitPlan.isNotEmpty ? i - 1 : i;
                    final m = _matches[matchIndex];
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