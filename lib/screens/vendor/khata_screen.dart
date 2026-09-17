// khata_screen.dart
// Vendor-side: pending dues grouped by customer, search, mark-as-paid.
// DEPENDS ON: order creation writing a khataEntries doc when
// paymentMethod == 'Khata Credit' — see the snippet below this file's
// code for the write-side piece, which needs your actual checkout code
// to place correctly.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KhataScreen extends StatefulWidget {
  final String vendorId;
  const KhataScreen({super.key, required this.vendorId});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Khata & Customers'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('khataEntries')
            .where('vendorId', isEqualTo: widget.vendorId)
            .where('paid', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F7B6C)));
          }

          final docs = snapshot.data?.docs ?? [];

          // Group entries by customer, sum pending amount
          final Map<String, List<QueryDocumentSnapshot>> byCustomer = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final customerId = data['customerId'] as String;
            byCustomer.putIfAbsent(customerId, () => []).add(doc);
          }

          final totalPending = docs.fold<double>(
              0, (sum, d) => sum + ((d.data() as Map<String, dynamic>)['amount'] as num? ?? 0));

          final filteredCustomers = byCustomer.entries.where((entry) {
            if (_searchQuery.isEmpty) return true;
            final data = entry.value.first.data() as Map<String, dynamic>;
            final name = (data['customerName'] as String? ?? '').toLowerCase();
            final phone = (data['customerPhone'] as String? ?? '');
            return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery);
          }).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A227).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC9A227).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL PENDING KHATA', style: TextStyle(fontSize: 11, color: Colors.grey[700], letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text('₹${totalPending.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFC9A227))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search name or phone',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredCustomers.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🎉', style: TextStyle(fontSize: 40)),
                              SizedBox(height: 8),
                              Text('All settled!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('No pending dues right now.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, i) {
                          final entries = filteredCustomers[i].value;
                          final data = entries.first.data() as Map<String, dynamic>;
                          final customerTotal = entries.fold<double>(
                              0, (sum, d) => sum + ((d.data() as Map<String, dynamic>)['amount'] as num? ?? 0));

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0F7B6C).withValues(alpha: 0.1),
                                child: Text((data['customerName'] as String? ?? '?')[0].toUpperCase(),
                                    style: const TextStyle(color: Color(0xFF0F7B6C), fontWeight: FontWeight.bold)),
                              ),
                              title: Text(data['customerName'] as String? ?? 'Customer'),
                              subtitle: Text(data['customerPhone'] as String? ?? ''),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${customerTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC9A227))),
                                  TextButton(
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                                    onPressed: () async {
                                      final batch = FirebaseFirestore.instance.batch();
                                      for (final entry in entries) {
                                        batch.update(entry.reference, {'paid': true, 'paidAt': FieldValue.serverTimestamp()});
                                      }
                                      await batch.commit();
                                    },
                                    child: const Text('Mark Paid', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}