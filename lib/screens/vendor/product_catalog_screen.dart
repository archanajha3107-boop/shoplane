import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/firestore_service.dart';
import 'add_product_screen.dart';
import 'product_search_screen.dart';
import 'voice_product_screen.dart';

class ProductCatalogScreen extends StatelessWidget {
  final String vendorId;
  final bool embedded;
  const ProductCatalogScreen({super.key, required this.vendorId, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    final content = StreamBuilder<List<ProductModel>>(
      stream: fs.vendorProducts(vendorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF0F7B6C)));
        }
        // THIS WAS MISSING — a parsing error on any product document (e.g. a
        // missing required field) was silently falling through to "No products
        // yet" with zero indication anything had gone wrong. Now it shows the
        // real error instead of hiding it.
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Couldn\'t load products:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ),
            ),
          );
        }
        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('No products yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                Text('Tap + to add your first product',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }
        final Map<String, List<ProductModel>> grouped = {};
        for (final p in products) {
          grouped.putIfAbsent(p.category, () => []).add(p);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F7B6C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF0F7B6C),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...entry.value.map((p) => _ProductTile(
                      product: p,
                      onToggle: (val) => fs.toggleStock(p.id, val),
                    )),
                const SizedBox(height: 16),
              ],
            );
          }).toList(),
        );
      },
    );

    final actionButtons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'voice',
          backgroundColor: const Color(0xFF0F7B6C),
          foregroundColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VoiceProductScreen(vendorId: vendorId),
            ),
          ),
          icon: const Icon(Icons.mic),
          label: const Text('Voice'),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'add',
          backgroundColor: const Color(0xFFE85A2B),
          foregroundColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddProductScreen(vendorId: vendorId),
            ),
          ),
          child: const Icon(Icons.add),
        ),
      ],
    );

    if (embedded) {
      return Container(
        color: const Color(0xFFF2F1EF),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    color: const Color(0xFF0F7B6C),
                    child: const Text(
                      'My Products',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(child: content),
                  const SizedBox(height: 120),
                ],
              ),
              Positioned(
                bottom: 24,
                right: 24,
                child: actionButtons,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('My Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductSearchScreen(vendorId: vendorId),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: actionButtons,
      body: content,
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductModel product;
  final ValueChanged<bool> onToggle;

  const _ProductTile({required this.product, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C2C2C))),
                Text('₹${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: product.inStock,
            onChanged: onToggle,
            activeThumbColor: const Color(0xFF0F7B6C),
          ),
        ],
      ),
    );
  }
}