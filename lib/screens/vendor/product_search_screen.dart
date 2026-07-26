import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/master_product.dart';
import '../../models/product_model.dart';
import '../../services/firestore_service.dart';

class ProductSearchScreen extends StatefulWidget {
  final String vendorId;
  const ProductSearchScreen({super.key, required this.vendorId});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _searchController = TextEditingController();
  List<MasterProduct> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final snap = await FirebaseFirestore.instance.collection('masterProducts').get();
    final all = snap.docs.map((d) => MasterProduct.fromMap(d.data())).toList();
    final matches = all.where((p) =>
        p.name.toLowerCase().contains(query.toLowerCase()) ||
        p.brand.toLowerCase().contains(query.toLowerCase())).toList();
    setState(() { _results = matches; _loading = false; });
  }

  void _showAddDialog(MasterProduct product) {
    final priceController = TextEditingController(text: product.mrp.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${product.brand} · ${product.unit}', style: const TextStyle(color: Colors.grey)),
            Text('MRP: ₹${product.mrp.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF0F7B6C), fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Your selling price (max MRP)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F7B6C), foregroundColor: Colors.white),
            onPressed: () async {
              final enteredPrice = double.tryParse(priceController.text) ?? product.mrp;
              if (enteredPrice > product.mrp) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Price cannot exceed MRP ₹${product.mrp.toStringAsFixed(0)}')),
                );
                return;
              }
              final newProduct = ProductModel(
                id: '',
                sellerId: widget.vendorId,
                name: product.name,
                price: enteredPrice,
                category: product.category,
                inStock: true,
                isVariableStock: product.category == 'Meat & Fish',
                lastUpdated: DateTime.now(),
              );
              await FirestoreService().addProduct(newProduct);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${product.name} added!'), backgroundColor: const Color(0xFF0F7B6C)),
                );
              }
            },
            child: const Text('Add to my shop'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Search Products'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search e.g. Kurkure, Amul, Rice...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F7B6C)),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (_loading) const CircularProgressIndicator(color: Color(0xFF0F7B6C)),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final p = _results[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: const Color(0xFF0F7B6C).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0F7B6C)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C))),
                            Text('${p.brand} · ${p.unit} · MRP ₹${p.mrp.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showAddDialog(p),
                        icon: const Icon(Icons.add_circle, color: Color(0xFFE85A2B), size: 28),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}