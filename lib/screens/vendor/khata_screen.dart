import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';

class KhataScreen extends StatefulWidget {
  final String vendorId;
  const KhataScreen({super.key, required this.vendorId});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Khata'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customer',
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF0F7B6C)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) =>
                  setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: FirestoreService()
                  .vendorOrders(widget.vendorId),
              builder: (context, snapshot) {
                final orders = snapshot.data ?? [];
                // Group credit orders by customer
                final Map<String, _KhataEntry> entries = {};
                for (final order in orders) {
                  if (order.paymentMethod == 'khata_credit' &&
                      order.status == 'delivered') {
                    entries.putIfAbsent(
                      order.customerId,
                      () => _KhataEntry(
                          name: order.customerName,
                          customerId: order.customerId),
                    );
                    entries[order.customerId]!.balance +=
                        order.total;
                    entries[order.customerId]!.orders.add(order);
                  }
                }
                final filtered = entries.values
                    .where((e) =>
                        _search.isEmpty ||
                        e.name.toLowerCase().contains(_search))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No Khata entries yet',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 16)),
                        SizedBox(height: 4),
                        Text(
                          'Credit orders appear here automatically',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final entry = filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF0F7B6C),
                            foregroundColor: Colors.white,
                            child: Icon(Icons.person),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(entry.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2C2C2C))),
                                Text(
                                    '${entry.orders.length} order${entry.orders.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              if (entry.balance > 0)
                                Text(
                                  '₹${entry.balance.toStringAsFixed(0)} due',
                                  style: const TextStyle(
                                    color: Color(0xFFE85A2B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F7B6C)
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Settled',
                                    style: TextStyle(
                                        color: Color(0xFF0F7B6C),
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.w600),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              color: Colors.grey),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Entries created automatically from delivered credit orders',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _KhataEntry {
  final String name;
  final String customerId;
  double balance = 0;
  final List<OrderModel> orders = [];
  _KhataEntry({required this.name, required this.customerId});
}