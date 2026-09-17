import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import 'cart_screen.dart';
import 'grouped_product_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopDetailScreen extends StatefulWidget {
  final UserModel vendor;
  final UserModel customer;
  const ShopDetailScreen(
      {super.key, required this.vendor, required this.customer});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  final Map<ProductModel, int> _cart = {};
  OrderModel? _lastOrder;

  double get _cartTotal => _cart.entries
      .fold(0, (total, e) => total + e.key.price * e.value);

  int get _cartCount =>
      _cart.values.fold(0, (total, qty) => total + qty);

  @override
  void initState() {
    super.initState();
    _loadLastOrder();
  }

  Future<void> _loadLastOrder() async {
    final order = await FirestoreService().getLastOrderFromShop(
      widget.customer.uid,
      widget.vendor.uid,
    );
    if (mounted) setState(() => _lastOrder = order);
  }

  void _addGroupedVariantToCart(GroupedProduct product, ProductVariant selectedVariant, int quantity) {
    final variantProduct = ProductModel(
      id: selectedVariant.productId,
      sellerId: widget.vendor.uid,
      name: product.name,
      price: selectedVariant.price,
      category: widget.vendor.category ?? 'General',
      inStock: true,
      isVariableStock: product.variants.length > 1,
      lastUpdated: DateTime.now(),
    );

    setState(() {
      _cart[variantProduct] = (_cart[variantProduct] ?? 0) + quantity;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: Text(widget.vendor.businessName ?? widget.vendor.name),
      ),
      body: Column(
        children: [
          // Shop info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A227).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.vendor.category ?? 'General',
                    style: const TextStyle(
                        color: Color(0xFFC9A227),
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Delivery ₹${widget.vendor.deliveryFee?.toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_lastOrder != null)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Last order: ${_lastOrder!.items.map((i) => '${i.name} x${i.qty}').join(', ')}'),
                    action: SnackBarAction(
                      label: 'Add to cart',
                      onPressed: () {
                        // Items are added — user can adjust quantities
                      },
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F7B6C).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF0F7B6C).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.replay_rounded,
                        color: Color(0xFF0F7B6C), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last order: ${_lastOrder!.items.map((i) => i.name).take(2).join(', ')}${_lastOrder!.items.length > 2 ? '...' : ''}',
                        style: const TextStyle(
                            color: Color(0xFF0F7B6C),
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text('Repeat →',
                        style: TextStyle(
                            color: Color(0xFF0F7B6C),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('sellerId', isEqualTo: widget.vendor.uid)
                  .where('inStock', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0F7B6C)),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No products available', style: TextStyle(color: Colors.grey)),
                  );
                }

                final rawProductMaps = docs.map((doc) => doc.data()).toList();
                final docIds = docs.map((doc) => doc.id).toList();
                final grouped = groupProductsByName(rawProductMaps, docIds);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, i) {
                    final product = grouped[i];
                    return GroupedProductCard(
                      product: product,
                      onAddToCart: (groupedProduct, selectedVariant, qty) =>
                          _addGroupedVariantToCart(groupedProduct, selectedVariant, qty),
                    );
                  },
                );
              },
            ),
          ),
          // Sticky cart bar
          if (_cartCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, -2))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_cartCount items • ₹${_cartTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C2C2C)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartScreen(
                          cart: _cart,
                          vendor: widget.vendor,
                          customer: widget.customer,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE85A2B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('View Cart'),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.favorite_border),
                    label: const Text('Add to Uncle'),
                    onPressed: () async {
                      await FirestoreService().saveShop(widget.customer.uid, widget.vendor.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved to Uncle')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}