// recurring_orders_screen.dart
// VENDOR-SIDE: "Today's Regular Deliveries" — shows every customer with an
// active recurring order for this vendor, lets vendor mark each delivered
// for today. Real V1: no automatic daily reset job (would need Cloud
// Functions/Blaze), so "delivered today" is tracked by comparing
// lastDeliveredAt's date to today — vendor marks it once per day manually.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringOrdersScreen extends StatelessWidget {
  final String vendorId;
  const RecurringOrdersScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Regular Deliveries'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('recurringOrders')
            .where('vendorId', isEqualTo: vendorId)
            .where('active', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F7B6C)));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No regular customers yet.\nCustomers can set this up from your shop page.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ),
            );
          }

          final today = DateTime.now();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final items = (data['items'] as List<dynamic>? ?? [])
                  .map((it) => '${it['name']} x${it['qty']}')
                  .join(', ');
              final lastDelivered = (data['lastDeliveredAt'] as Timestamp?)?.toDate();
              final deliveredToday = lastDelivered != null &&
                  lastDelivered.year == today.year &&
                  lastDelivered.month == today.month &&
                  lastDelivered.day == today.day;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: deliveredToday ? Colors.green[100] : const Color(0xFFC9A227).withValues(alpha: 0.15),
                    child: Icon(deliveredToday ? Icons.check : Icons.repeat_rounded,
                        color: deliveredToday ? Colors.green[700] : const Color(0xFFC9A227)),
                  ),
                  title: Text(data['customerName'] as String? ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(items),
                  trailing: deliveredToday
                      ? const Text('Delivered ✓', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))
                      : ElevatedButton(
                          onPressed: () async {
                            await doc.reference.update({'lastDeliveredAt': FieldValue.serverTimestamp()});
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F7B6C), foregroundColor: Colors.white),
                          child: const Text('Mark Delivered', style: TextStyle(fontSize: 12)),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}