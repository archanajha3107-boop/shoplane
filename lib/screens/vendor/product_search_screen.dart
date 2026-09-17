// product_search_screen.dart
// Vendor-side: search Open Food Facts, capture the REAL packet quantity
// (locked, non-editable — prevents a vendor mispricing a 500ml pack as 1L),
// real images, description, self-reported MRP.
// Writes to the TOP-LEVEL 'products' collection with a 'sellerId' field —
// this matches your real FirestoreService.vendorProducts()/shopProducts()
// queries. If products still aren't showing up in your shop after this,
// check Firestore Console under 'products' (not 'vendors/{id}/products').

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../gemini_mrp_service.dart';

class ProductSearchScreen extends StatefulWidget {
  final String vendorId;
  const ProductSearchScreen({super.key, required this.vendorId});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _controller = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  String? _error;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });

    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query)}'
        '&search_simple=1&json=1&page_size=15');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _results = data['products'] ?? []; _loading = false; });
      } else {
        setState(() { _error = 'Search failed (${response.statusCode}).'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Something went wrong: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'e.g. Kurkure, Amul Butter, Parle-G',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _search(_controller.text)),
            ),
            onSubmitted: _search,
          ),
        ),
        if (_loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
        if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final product = _results[i];
              final name = (product['product_name'] as String?)?.trim() ?? '';
              final brand = (product['brands'] as String?)?.trim() ?? '';
              final frontImage = (product['image_front_url'] as String?) ?? (product['image_url'] as String?) ?? '';
              final thumbImage = (product['image_front_small_url'] as String?) ?? frontImage;
              final ingredientsImage = (product['image_ingredients_url'] as String?) ?? '';
              final genericName = (product['generic_name'] as String?)?.trim() ?? '';
              final categories = (product['categories'] as String?)?.trim() ?? '';
              // THIS is the real packet size printed on the product — "1 L", "500 g", "68 g" etc.
              final quantity = (product['quantity'] as String?)?.trim() ?? '';

              if (name.isEmpty) return const SizedBox.shrink();

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: thumbImage.isNotEmpty
                      ? Image.network(thumbImage, width: 44, height: 44, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(width: 44, height: 44, color: Colors.grey[200]))
                      : Container(width: 44, height: 44, color: Colors.grey[200]),
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [brand, quantity].where((s) => s.isNotEmpty).join(' • '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => _showAddProductDialog(
                  context, name,
                  images: [frontImage, ingredientsImage].where((u) => u.isNotEmpty).toList(),
                  description: genericName.isNotEmpty ? genericName : categories,
                  quantity: quantity,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddProductDialog(BuildContext context, String name,
      {required List<String> images, required String description, required String quantity}) {
    final priceController = TextEditingController();
    final mrpController = TextEditingController();
    String? errorText;
    bool fetchingMrpSuggestion = false;
    String? mrpSuggestionText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Add "$name"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity is shown but LOCKED — this is exactly what's printed
              // on the real packet per Open Food Facts, a vendor can't edit
              // it to misrepresent pack size (e.g. listing 500ml as 1L).
              if (quantity.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Pack size: $quantity', style: const TextStyle(fontWeight: FontWeight.w600))),
                      const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                const Text('⚠️ Pack size not available from database — double-check the packet before listing.',
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
                const SizedBox(height: 12),
              ],
              TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true, decoration: const InputDecoration(labelText: 'Your Selling Price', prefixText: '₹', hintText: 'e.g. 20')),
              const SizedBox(height: 12),
              TextField(controller: mrpController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'MRP (optional)', prefixText: '₹', hintText: 'Check the packet')),
              TextButton.icon(
                icon: fetchingMrpSuggestion
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(fetchingMrpSuggestion ? 'Checking...' : 'Get AI price estimate'),
                onPressed: fetchingMrpSuggestion ? null : () async {
                  setDialogState(() => fetchingMrpSuggestion = true);
                  final suggestion = await GeminiMrpService.suggestMrp(name);
                  setDialogState(() {
                    fetchingMrpSuggestion = false;
                    mrpSuggestionText = suggestion != null
                        ? 'AI estimate: ₹${suggestion.toStringAsFixed(0)} (unverified — please confirm against the packet)'
                        : 'AI has no reliable estimate for this product';
                  });
                },
              ),
              if (mrpSuggestionText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(mrpSuggestionText!, style: const TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic)),
                ),
              if (errorText != null) ...[const SizedBox(height: 8), Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13))],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final sellingPrice = double.tryParse(priceController.text);
                final mrp = mrpController.text.trim().isEmpty ? null : double.tryParse(mrpController.text);

                if (sellingPrice == null || sellingPrice <= 0) {
                  setDialogState(() => errorText = 'Enter a valid selling price');
                  return;
                }
                if (mrp != null && sellingPrice > mrp) {
                  setDialogState(() => errorText = 'Selling price cannot exceed MRP (₹${mrp.toStringAsFixed(0)})');
                  return;
                }

                // Top-level 'products' collection, sellerId field — matches
                // your real FirestoreService queries. NOT vendors/{id}/products.
                await FirebaseFirestore.instance.collection('products').add({
                  // Required by your real ProductModel schema — missing these
                  // is why packaged items saved but never appeared in My Products.
                  'sellerId': widget.vendorId,
                  'name': name,
                  'price': sellingPrice,
                  'category': 'Grocery & Provisions',
                  'inStock': true,
                  'isVariableStock': false,
                  'lastUpdated': FieldValue.serverTimestamp(),
                  'photoUrl': images.isNotEmpty ? images.first : '',
                  // Extra fields on top of the base schema — safe, ignored by fromMap.
                  'nameLower': name.toLowerCase(),
                  if (mrp != null) 'mrp': mrp,
                  if (quantity.isNotEmpty) 'netQuantity': quantity,
                  'imageUrls': images,
                  'description': description,
                  'source': 'openFoodFacts',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added to your shop')));
                  setState(() { _controller.clear(); _results = []; });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}