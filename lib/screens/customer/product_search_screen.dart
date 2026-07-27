import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/product_lookup_service.dart';

class ProductSearchScreen extends StatefulWidget {
  final Function(String productName, String category) onAddToWishlist;
  const ProductSearchScreen({super.key, required this.onAddToWishlist});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _controller = TextEditingController();
  List<RemoteProduct> _results = [];
  bool _loading = false;
  final Set<String> _added = {};

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final results = await ProductLookupService().search(query);
    if (mounted) setState(() { _results = results; _loading = false; });
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
              controller: _controller,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search e.g. Kurkure, Amul Milk...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F7B6C)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Color(0xFFE85A2B)),
                  onPressed: () => _search(_controller.text),
                ),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (_loading) const CircularProgressIndicator(color: Color(0xFF0F7B6C)),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('Search for a product to add to your list', style: TextStyle(color: Colors.grey)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75,
                    ),
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final p = _results[i];
                      final added = _added.contains(p.name);
                      return Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: p.imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: p.imageUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (c, u) => Container(color: Colors.grey.shade100),
                                        errorWidget: (c, u, e) => Container(
                                          color: Colors.grey.shade100,
                                          child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey.shade100,
                                        child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2C2C2C))),
                            Text(p.brand, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: added ? null : () {
                                  widget.onAddToWishlist(p.name, p.category);
                                  setState(() => _added.add(p.name));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: added ? Colors.grey.shade300 : const Color(0xFFE85A2B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(added ? 'Added ✓' : 'Add', style: const TextStyle(fontSize: 11)),
                              ),
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