// product_detail_screen.dart
// Customer-side: Zepto/Blinkit-style product page — swipeable image gallery,
// description, price with struck-through MRP, quantity stepper, fixed
// Add to Cart bar. Handles all 3 image sources your catalogue can produce:
// real OFF image URLs, a single base64 photo, or an emoji fallback.

import 'dart:convert';
import 'package:flutter/material.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final String name;
  final double price;
  final double? mrp;
  final String? description;
  final List<String>? imageUrls;   // from Open Food Facts (front + ingredients)
  final String? imageBase64;       // from vendor's own camera/gallery photo
  final String? emoji;             // fallback for produce/local items
  final void Function(int quantity) onAddToCart;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.name,
    required this.price,
    this.mrp,
    this.description,
    this.imageUrls,
    this.imageBase64,
    this.emoji,
    required this.onAddToCart,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _currentImageIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> _buildGalleryPages() {
    if (widget.imageUrls != null && widget.imageUrls!.isNotEmpty) {
      return widget.imageUrls!.map((url) {
        return Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[100],
            child: const Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey)),
          ),
        );
      }).toList();
    }
    if (widget.imageBase64 != null) {
      return [Image.memory(base64Decode(widget.imageBase64!), fit: BoxFit.contain)];
    }
    if (widget.emoji != null) {
      return [Container(color: Colors.grey[50], child: Center(child: Text(widget.emoji!, style: const TextStyle(fontSize: 96))))];
    }
    return [Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey)))];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildGalleryPages();
    final hasDiscount = widget.mrp != null && widget.mrp! > widget.price;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: const Color(0xFFEFF6F4), // soft green-tinted background, matches your brand palette
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      children: pages.map((img) => Padding(padding: const EdgeInsets.all(24), child: img)).toList(),
                    ),
                  ),
                  Positioned(
                    top: 8, left: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
                    ),
                  ),
                  if (pages.length > 1)
                    Positioned(
                      bottom: 12, left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(pages.length, (i) {
                          final isActive = i == _currentImageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF0F7B6C) : Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (widget.description != null && widget.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(widget.description!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF0F7B6C), borderRadius: BorderRadius.circular(6)),
                        child: Text('₹${widget.price.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 8),
                        Text('₹${widget.mrp!.toStringAsFixed(0)}',
                            style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey[500], fontSize: 14)),
                      ],
                    ],
                  ),
                  if (hasDiscount) ...[
                    const SizedBox(height: 2),
                    const Text('MRP (incl. of all taxes)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, -2))]),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.remove, size: 18),
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null),
                    Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => setState(() => _quantity++)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE85A2B), // terracotta CTA per your brand palette
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    widget.onAddToCart(_quantity);
                    Navigator.pop(context);
                  },
                  child: const Text('Add to Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}