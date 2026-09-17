import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/vendor_matcher.dart';

class VendorMatchResultsScreen extends StatelessWidget {
  final SetCoverResult matchResult;
  final UserModel customer;
  final List<String> wishlist; // Added wishlist parameter

  const VendorMatchResultsScreen({
    super.key,
    required this.matchResult,
    required this.customer,
    required this.wishlist, // Mark as required
  });

  @override
  Widget build(BuildContext context) {
    final matches = matchResult.matches;
    final unavailable = matchResult.unavailableItems;

    return Scaffold(
      appBar: AppBar(
        title: Text('Vendor Match Results for ${customer.name ?? "Customer"}'),
      ),
      body: matches.isEmpty && unavailable.isEmpty
          ? const Center(
              child: Text('No items in the shopping list.'),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                if (matches.isNotEmpty) ...[
                  const Text(
                    'Matched Vendors',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...matches.map((match) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.vendor.name ?? 'Local Vendor',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Covered Items:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6.0,
                              runSpacing: 4.0,
                              children: match.itemsCovered.map((item) {
                                return Chip(
                                  label: Text(item),
                                  backgroundColor: Colors.green.shade50,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                if (unavailable.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Unavailable Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Wrap(
                        spacing: 6.0,
                        runSpacing: 4.0,
                        children: unavailable.map((item) {
                          return Chip(
                            label: Text(item),
                            backgroundColor: Colors.white,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}