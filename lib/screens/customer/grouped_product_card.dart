// grouped_product_card.dart
// Customer-side: groups a vendor's products by name so "Tomatoes" with two
// price tiers shows as ONE card with a variant selector, not two confusing
// separate entries.

import 'dart:convert';
import 'package:flutter/material.dart';

import 'product_detail_screen.dart';

class ProductVariant {
  final String productId;
  final String? variantLabel;
  final double price;
  final double? mrp;
  final String? description;
  final List<String>? imageUrls;
  final String? imageBase64;
  final String? emoji;

  ProductVariant({
    required this.productId,
    this.variantLabel,
    required this.price,
    this.mrp,
    this.description,
    this.imageUrls,
    this.imageBase64,
    this.emoji,
  });
}

class GroupedProduct {
  final String name;
  final String? imageBase64;
  final String? emoji;
  final List<ProductVariant> variants;

  GroupedProduct({required this.name, this.imageBase64, this.emoji, required this.variants});
}

List<GroupedProduct> groupProductsByName(List<Map<String, dynamic>> rawProducts, List<String> docIds) {
  final Map<String, GroupedProduct> grouped = {};

  for (int i = 0; i < rawProducts.length; i++) {
    final data = rawProducts[i];
    final docId = docIds[i];
    final name = data['name'] as String? ?? '';
    final key = name.toLowerCase();
    final imageUrls = (data['imageUrls'] is List)
        ? (data['imageUrls'] as List).map((e) => e.toString()).toList()
        : null;

    final variant = ProductVariant(
      productId: docId,
      variantLabel: data['variant'] as String?,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      mrp: (data['mrp'] as num?)?.toDouble(),
      description: data['description'] as String?,
      imageUrls: imageUrls,
      imageBase64: data['imageBase64'] as String?,
      emoji: data['emoji'] as String?,
    );

    if (grouped.containsKey(key)) {
      grouped[key]!.variants.add(variant);
    } else {
      grouped[key] = GroupedProduct(
        name: name,
        imageBase64: data['imageBase64'] as String?,
        emoji: data['emoji'] as String?,
        variants: [variant],
      );
    }
  }

  return grouped.values.toList();
}

class GroupedProductCard extends StatefulWidget {
  final GroupedProduct product;
  final void Function(GroupedProduct product, ProductVariant selectedVariant, int quantity) onAddToCart;

  const GroupedProductCard({super.key, required this.product, required this.onAddToCart});

  @override
  State<GroupedProductCard> createState() => _GroupedProductCardState();
}

class _GroupedProductCardState extends State<GroupedProductCard> {
  late ProductVariant _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.product.variants.first;
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleVariants = widget.product.variants.length > 1;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              productId: _selected.productId,
              name: widget.product.name,
              price: _selected.price,
              mrp: _selected.mrp,
              description: _selected.description,
              imageUrls: _selected.imageUrls,
              imageBase64: _selected.imageBase64 ?? widget.product.imageBase64,
              emoji: _selected.emoji ?? widget.product.emoji,
              onAddToCart: (qty) => widget.onAddToCart(widget.product, _selected, qty),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    if (hasMultipleVariants)
                      Wrap(
                        spacing: 8,
                        children: widget.product.variants.map((v) {
                          final isSelected = v == _selected;
                          return ChoiceChip(
                            label: Text('\${v.variantLabel ?? "Standard"} — ₹\${v.price.toStringAsFixed(0)}'),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selected = v),
                            selectedColor: const Color(0xFF0F7B6C).withValues(alpha: 0.15),
                          );
                        }).toList(),
                      )
                    else
                      Text('₹\${_selected.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () => widget.onAddToCart(widget.product, _selected, 1),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                        child: const Text('Add to Cart', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FIX: now checks the SELECTED variant's own image data first (falls back
  // to product-level for backward compatibility), and — the actual missing
  // piece — falls back to imageUrls (Open Food Facts search results) before
  // giving up and showing the fallback icon.
  Widget _buildThumbnail() {
    final imageBase64 = _selected.imageBase64 ?? widget.product.imageBase64;
    final emoji = _selected.emoji ?? widget.product.emoji;
    final imageUrls = _selected.imageUrls;

    if (imageBase64 != null && imageBase64.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(imageBase64),
          width: 56, height: 56, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }
    if (emoji != null && emoji.isNotEmpty) {
      return Container(
        width: 56, height: 56, alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      );
    }
    if (imageUrls != null && imageUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrls.first,
          width: 56, height: 56, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}