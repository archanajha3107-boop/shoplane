import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import 'shop_detail_screen.dart';

class UncleScreen extends StatelessWidget {
  final UserModel customer;
  final bool embedded;

  UncleScreen({super.key, required this.customer, this.embedded = false});

  final FirestoreService _firestoreService = FirestoreService();
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<String>>(
      stream: _firestoreService.mySavedShopIds(customer.uid),
      builder: (context, savedIdsSnapshot) {
        if (savedIdsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final savedShopIds = savedIdsSnapshot.data ?? [];

        if (savedShopIds.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No saved vendors yet.\nTap "Add to Uncle" on any shop you visit often.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: savedShopIds.length,
          itemBuilder: (context, i) {
            final vendorId = savedShopIds[i];

            // mySavedShopIds only returns IDs, so each saved shop needs its
            // own fetch to get the real vendor details for display + navigation.
            return FutureBuilder<UserModel?>(
              future: _getVendorById(vendorId),
              builder: (context, vendorSnapshot) {
                if (!vendorSnapshot.hasData || vendorSnapshot.data == null) {
                  return const SizedBox.shrink(); // skip silently if a saved vendor was deleted
                }

                final vendor = vendorSnapshot.data!;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF0F7B6C),
                      child: Icon(Icons.storefront, color: Colors.white),
                    ),
                    title: Text(vendor.businessName ?? vendor.name),
                    subtitle: Text(vendor.category ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShopDetailScreen(
                            vendor: vendor,
                            customer: customer,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Uncle'), backgroundColor: const Color(0xFF0F7B6C)),
      body: body,
    );
  }

  // FirestoreService doesn't currently expose a "get single user by id" method,
  // so this reads directly from the same 'users' collection FirestoreService uses,
  // and builds a UserModel the same way UserModel.fromMap already does elsewhere.
  Future<UserModel?> _getVendorById(String vendorId) async {
    final doc = await _usersCollection.doc(vendorId).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}