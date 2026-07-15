import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/order_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../role_selection_screen.dart';
import 'product_catalog_screen.dart';

class VendorDashboardScreen extends StatefulWidget {
  final UserModel vendor;
  const VendorDashboardScreen({super.key, required this.vendor});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final FirestoreService _fs = FirestoreService();
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.vendor.isOpen ?? false;
  }

  Future<void> _toggleShop(bool val) async {
    await _fs.toggleShopOpen(widget.vendor.uid, val);
    setState(() => _isOpen = val);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new': return const Color(0xFFE85A2B);
      case 'accepted': return const Color(0xFF0F7B6C);
      case 'dispatched': return const Color(0xFFC9A227);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: Text(widget.vendor.businessName ?? widget.vendor.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop status card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome back,',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(
                        widget.vendor.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Switch(
                        value: _isOpen,
                        onChanged: _toggleShop,
                        activeColor: const Color(0xFF0F7B6C),
                      ),
                      Text(
                        _isOpen ? 'Open' : 'Closed',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isOpen
                              ? const Color(0xFF0F7B6C)
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Quick actions
            Row(
              children: [
                _ActionCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Products',
                  color: const Color(0xFFE85A2B),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductCatalogScreen(
                          vendorId: widget.vendor.uid),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _ActionCard(
                  icon: Icons.book_rounded,
                  label: 'Khata',
                  color: const Color(0xFFC9A227),
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _ActionCard(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  color: Colors.grey,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Incoming Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2C2C),
              ),
            ),
            const SizedBox(height: 12),
            // Live orders stream
            StreamBuilder<List<OrderModel>>(
              stream: _fs.vendorOrders(widget.vendor.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                      color: Color(0xFF0F7B6C)));
                }
                final orders = snapshot.data ?? [];
                final active = orders
                    .where((o) =>
                        o.status == 'new' || o.status == 'accepted')
                    .toList();
                if (active.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No active orders',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 15)),
                        Text('New orders will appear here in real time',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return Column(
                  children: active
                      .map((order) => _OrderCard(
                            order: order,
                            onAccept: () => _fs.updateOrderStatus(
                                order.id, 'accepted'),
                            onReject: () => _fs.updateOrderStatus(
                                order.id, 'rejected'),
                            onDispatched: () => _fs.updateOrderStatus(
                                order.id, 'dispatched'),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDispatched;

  const _OrderCard({
    required this.order,
    required this.onAccept,
    required this.onReject,
    required this.onDispatched,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: order.status == 'new'
                ? const Color(0xFFE85A2B)
                : const Color(0xFF0F7B6C),
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.customerName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2C2C2C))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: order.status == 'new'
                      ? const Color(0xFFE85A2B).withValues(alpha: 0.1)
                      : const Color(0xFF0F7B6C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: order.status == 'new'
                        ? const Color(0xFFE85A2B)
                        : const Color(0xFF0F7B6C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.items.map((i) => '${i.name} x${i.qty}').join(', '),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${order.total.toStringAsFixed(0)} • ${order.fulfillmentType} • ${order.paymentMethod}',
            style: const TextStyle(
                color: Color(0xFF0F7B6C), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (order.status == 'new')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F7B6C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85A2B),
                      side: const BorderSide(color: Color(0xFFE85A2B)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          if (order.status == 'accepted')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDispatched,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9A227),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Mark Dispatched'),
              ),
            ),
        ],
      ),
    );
  }
}