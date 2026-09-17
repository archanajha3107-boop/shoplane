import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import 'order_confirmation_screen.dart';
import '../../constants/app_colors.dart';

class CartScreen extends StatefulWidget {
  final Map<ProductModel, int> cart;
  final UserModel vendor;
  final UserModel customer;

  const CartScreen({
    super.key,
    required this.cart,
    required this.vendor,
    required this.customer,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Map<ProductModel, int> _cart;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _cart = Map<ProductModel, int>.from(widget.cart);
  }

  double get _subtotal =>
      _cart.entries.fold(0, (sum, e) => sum + (e.key.price * e.value));

  double get _deliveryFee => widget.vendor.deliveryFee ?? 0;
  double get _total => _subtotal + _deliveryFee;

  void _incrementQty(ProductModel p) {
    setState(() => _cart[p] = (_cart[p] ?? 0) + 1);
  }

  void _decrementQty(ProductModel p) {
    setState(() {
      final current = _cart[p] ?? 0;
      if (current <= 1) {
        _cart.remove(p);
      } else {
        _cart[p] = current - 1;
      }
    });
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) return;
    setState(() => _placing = true);

    final items = _cart.entries
        .map((e) => OrderItem(
              productId: e.key.id,
              name: e.key.name,
              price: e.key.price,
              qty: e.value,
            ))
        .toList();

    final order = OrderModel(
      id: '',
      customerId: widget.customer.uid,
      sellerId: widget.vendor.uid,
      customerName: widget.customer.name,
      shopName: widget.vendor.businessName ?? widget.vendor.name,
      items: items,
      total: _total,
      status: 'new',
      fulfillmentType: 'delivery',
      paymentMethod: 'cash',
      issueFlag: false,
      createdAt: DateTime.now(),
    );

    try {
      final orderId = await FirestoreService().placeOrder(order);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: orderId,
            total: _total,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e')),
      );
      setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        title: const Text('Your Cart'),
      ),
      body: _cart.isEmpty
          ? const Center(
              child: Text('Your cart is empty',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            )
          : Column(
              children: [
                // Vendor + ETA banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F7B6C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            color: Color(0xFF0F7B6C)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.vendor.businessName ?? widget.vendor.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF2C2C2C)),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 13, color: Colors.grey),
                                const SizedBox(width: 4),
                                const Text('Est. 20-30 min',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Item list
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _cart.entries.map((entry) {
                      final product = entry.key;
                      final qty = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shopping_basket_outlined,
                                  color: Colors.grey, size: 20),
                            ),
                            const SizedBox(width: 12),
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
                                          color: Color(0xFF0F7B6C),
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _decrementQty(product),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F7B6C)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.remove,
                                        size: 16, color: Color(0xFF0F7B6C)),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('$qty',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                GestureDetector(
                                  onTap: () => _incrementQty(product),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F7B6C)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.add,
                                        size: 16, color: Color(0xFF0F7B6C)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Bottom summary + payment + place order
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(color: Colors.grey)),
                          Text('₹${_subtotal.toStringAsFixed(0)}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Delivery Fee', style: TextStyle(color: Colors.grey)),
                          Text('₹${_deliveryFee.toStringAsFixed(0)}'),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('₹${_total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0F7B6C))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC9A227).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.payments_outlined, color: Color(0xFFC9A227), size: 18),
                            SizedBox(width: 8),
                            Text('Cash on Delivery',
                                style: TextStyle(
                                    color: Color(0xFF2C2C2C), fontWeight: FontWeight.w600)),
                            Spacer(),
                            Text('Only option', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _placing ? null : _placeOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE85A2B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _placing
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text('Place Order · ₹${_total.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}