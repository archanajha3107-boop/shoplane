import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import 'shop_detail_screen.dart';

class UncleScreen extends StatelessWidget {
  final UserModel customer;
  const UncleScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('My Uncle Shops'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(customer.uid)
            .collection('myShops')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F7B6C)));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('👨‍🦳', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12),
                    Text('No regular shops saved yet',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Add your regular doodhwala, kirana, or sabzi shop',
                        style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final vendorId = docs[i].id;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(vendorId).get(),
                builder: (context, vendorSnap) {
                  if (!vendorSnap.hasData) return const SizedBox.shrink();
                  final data = vendorSnap.data!.data() as Map<String, dynamic>?;
                  if (data == null) return const SizedBox.shrink();
                  final vendor = UserModel.fromMap(data, vendorId);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF0F7B6C).withValues(alpha: 0.1),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF0F7B6C)),
                      ),
                      title: Text(vendor.businessName ?? vendor.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(vendor.category ?? ''),
                      trailing: (vendor.isOpen ?? false)
                          ? const Text('Open', style: TextStyle(color: Color(0xFF0F7B6C), fontWeight: FontWeight.bold))
                          : const Text('Closed', style: TextStyle(color: Colors.red)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ShopDetailScreen(vendor: vendor, customer: customer)),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}