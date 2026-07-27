import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/product_lookup_service.dart';
import '../../models/product_model.dart';
import '../../services/firestore_service.dart';

class ProductSearchScreen extends StatefulWidget {
  final String vendorId;
  const ProductSearchScreen({super.key, required this.vendorId});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _controller = TextEditingController();
  List<RemoteProduct> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _loading = true);
    final results = await ProductLookupService().search(query);
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  void _showAddDialog(RemoteProduct product) {
    final priceController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: product.imageUrl, width: 60, height: 60, fit: BoxFit.contain)
                      : Container(width: 60, height: 60, color: Colors.grey.shade100),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${product.brand} · ${product.category}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Your selling price (₹)',
                helperText: 'Set your own price for this item',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F7B6C), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () async {
                  final price = double.tryParse(priceController.text);
                  if (price == null || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid price')));
                    return;
                  }
                  final newProduct = ProductModel(
                    id: '',
                    sellerId: widget.vendorId,
                    name: product.name,
                    price: price,
                    category: product.category,
                    photoUrl: product.imageUrl,
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
            ),
          ],
        ),
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
        title: const Text('Search & Add Products'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'e.g. Kurkure, Amul, Parle-G...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F7B6C)),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward, color: Color(0xFFE85A2B)), onPressed: () => _search(_controller.text)),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: p.imageUrl.isNotEmpty
                            ? CachedNetworkImage(imageUrl: p.imageUrl, width: 50, height: 50, fit: BoxFit.contain,
                                errorWidget: (c, u, e) => Container(width: 50, height: 50, color: Colors.grey.shade100))
                            : Container(width: 50, height: 50, color: Colors.grey.shade100, child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C))),
                            Text('${p.brand} · ${p.category}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => _showAddDialog(p), icon: const Icon(Icons.add_circle, color: Color(0xFFE85A2B), size: 28)),
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