// smart_split_screen.dart
// Shows the real Set Cover result: which nearby vendors cover which items,
// plus anything not available nearby at all. Tapping "Order" opens that
// vendor's REAL ShopDetailScreen using your actual constructor.

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/vendor_matcher.dart';
import 'shop_detail_screen.dart';

class SmartSplitScreen extends StatelessWidget {
  final SetCoverResult result;
  final UserModel customer;

  const SmartSplitScreen({super.key, required this.result, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your list, matched to nearby shops'), backgroundColor: const Color(0xFF0F7B6C)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (result.matches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No nearby vendors could cover any items on your list.', textAlign: TextAlign.center),
            ),
          ...result.matches.map((match) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF0F7B6C), child: Icon(Icons.storefront, color: Colors.white)),
                title: Text(match.vendor.businessName ?? match.vendor.name),
                subtitle: Text('Covers: ${match.itemsCovered.join(", ")}'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE85A2B)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ShopDetailScreen(vendor: match.vendor, customer: customer),
                    ));
                  },
                  child: const Text('Order', style: TextStyle(color: Colors.white)),
                ),
              ),
            );
          }),
          if (result.unavailableItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Not available nearby:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700])),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: result.unavailableItems.map((item) => Chip(label: Text(item))).toList(),
            ),
          ],
        ],
      ),
    );
  }
}