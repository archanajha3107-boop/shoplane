import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import 'order_confirmation_screen.dart';

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
  String _fulfillment = 'delivery';
  String _payment = 'cash';
  bool _isLoading = false;

  double get _subtotal => widget.cart.entries
      .fold(0, (sum, e) => sum + e.key.price * e.value);

  double get _deliveryFee =>
      _fulfillment == 'delivery'
          ? (widget.vendor.deliveryFee ?? 0)
          : 0;

  double get _total => _subtotal + _deliveryFee;

  Future<void> _placeOrder() async {
    setState(() => _isLoading = true);
    try {
      final items = widget.cart.entries
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
        fulfillmentType: _fulfillment,
        paymentMethod: _payment,
        issueFlag: false,
        createdAt: DateTime.now(),
      );

      final orderId =
          await FirestoreService().placeOrder(order);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: orderId,
            total: _total,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Your Cart'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vendor.businessName ?? widget.vendor.name,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  // Items
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: widget.cart.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(e.key.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2C2C2C))),
                              ),
                              Text('x${e.value}',
                                  style: const TextStyle(
                                      color: Colors.grey)),
                              const SizedBox(width: 12),
                              Text(
                                '₹${(e.key.price * e.value).toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C2C2C)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Totals
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _totalRow(
                            'Subtotal',
                            '₹${_subtotal.toStringAsFixed(0)}',
                            false),
                        const SizedBox(height: 8),
                        _totalRow(
                            'Delivery Fee',
                            '₹${_deliveryFee.toStringAsFixed(0)}',
                            false),
                        const Divider(height: 20),
                        _totalRow(
                            'Total',
                            '₹${_total.toStringAsFixed(0)}',
                            true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fulfillment
                  const Text('Fulfillment',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C2C2C))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _togglePill('Delivery', 'delivery'),
                      const SizedBox(width: 8),
                      _togglePill('Pickup', 'pickup'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Payment
                  const Text('Payment',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C2C2C))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _paymentTile('cash', 'Cash',
                            Icons.money_rounded),
                        _paymentTile('upi', 'UPI',
                            Icons.qr_code_rounded),
                        _paymentTile(
                            'khata_credit',
                            'Khata Credit',
                            Icons.book_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Place order button
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85A2B),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : Text(
                        'Place Order • ₹${_total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, bool bold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                color: bold
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey)),
        Text(value,
            style: TextStyle(
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                color: bold
                    ? const Color(0xFF0F7B6C)
                    : const Color(0xFF2C2C2C),
                fontSize: bold ? 16 : 14)),
      ],
    );
  }

  Widget _togglePill(String label, String value) {
    final selected = _fulfillment == value;
    return GestureDetector(
      onTap: () => setState(() => _fulfillment = value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0F7B6C)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF0F7B6C)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF2C2C2C),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _paymentTile(
      String value, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0F7B6C)),
      title: Text(label),
      trailing: Radio<String>(
        value: value,
        groupValue: _payment,
        onChanged: (v) => setState(() => _payment = v!),
        activeColor: const Color(0xFF0F7B6C),
      ),
      onTap: () => setState(() => _payment = value),
    );
  }
}