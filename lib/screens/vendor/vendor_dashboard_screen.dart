import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../models/user_model.dart';
import '../../models/order_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/location_bottom_sheet.dart';
import '../../widgets/order_countdown_badge.dart';
import '../role_selection_screen.dart';
import 'product_catalog_screen.dart';
import 'vendor_settings_screen.dart';
import 'khata_screen.dart';

class VendorDashboardScreen extends StatefulWidget {
  final UserModel vendor;
  const VendorDashboardScreen({super.key, required this.vendor});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final FirestoreService _fs = FirestoreService();
  bool _isOpen = false;
  bool _exporting = false;
  int _selectedTab = 0; // 0=Home, 1=Products, 2=Khata, 3=Settings

  @override
  void initState() {
    super.initState();
    _isOpen = widget.vendor.isOpen ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationBottomSheet.showIfNeeded(context, (lat, lng, address) {
        if (mounted) setState(() {});
      });
    });
  }

  Future<void> _toggleShop(bool val) async {
    setState(() => _isOpen = val);
    await _fs.toggleShopOpen(widget.vendor.uid, val);
  }

  Future<void> _exportMonthCsv(List<QueryDocumentSnapshot> docs) async {
    setState(() => _exporting = true);
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final rows = <List<dynamic>>[
        ['Order ID', 'Date', 'Customer', 'Items', 'Total (₹)', 'Status'],
      ];
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null || createdAt.isBefore(monthStart)) continue;
        final items = (data['items'] as List<dynamic>? ?? [])
            .map((i) => '${i['name']} x${i['qty']}')
            .join('; ');
        rows.add([
          doc.id,
          createdAt.toIso8601String().split('T').first,
          data['customerName'] ?? 'Customer',
          items,
          data['total'] ?? 0,
          data['status'] ?? '',
        ]);
      }
      final csvString = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final fileName =
          'shoplane_orders_${now.year}_${now.month.toString().padLeft(2, '0')}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvString);
      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'ShopLane orders — this month',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('sellerId', isEqualTo: widget.vendor.uid)
              .snapshots(),
          builder: (context, rawSnap) {
            final rawDocs = rawSnap.data?.docs ?? [];
            final now = DateTime.now();

            // Parse all orders for stats
            final allOrders = rawDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _OrderData(
                doc: doc,
                createdAt:
                    (data['createdAt'] as Timestamp?)?.toDate() ?? now,
                total: (data['total'] as num?)?.toDouble() ?? 0,
                status: data['status'] as String? ?? '',
              );
            }).toList();

            final todayOrders = allOrders
                .where((o) =>
                    o.createdAt.year == now.year &&
                    o.createdAt.month == now.month &&
                    o.createdAt.day == now.day)
                .toList();
            final todaySales =
                todayOrders.fold<double>(0, (s, o) => s + o.total);
            final activeCount = allOrders
                .where((o) =>
                    o.status == 'new' || o.status == 'accepted')
                .length;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ─────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Namaste, ${widget.vendor.name} 👋',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C2C2C),
                              ),
                            ),
                            Text(
                              widget.vendor.businessName ?? '',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      // Open/Closed toggle
                      Column(
                        children: [
                          Switch(
                            value: _isOpen,
                            onChanged: _toggleShop,
                            activeThumbColor: const Color(0xFF0F7B6C),
                          ),
                          Text(
                            _isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isOpen
                                  ? const Color(0xFF0F7B6C)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      // Logout
                      IconButton(
                        icon: const Icon(Icons.logout_rounded,
                            color: Color(0xFF2C2C2C)),
                        onPressed: () async {
                          await AuthService().logout();
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const RoleSelectionScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Today's Sales card (Terracotta gradient) ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE85A2B), Color(0xFFC9482A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "TODAY'S SALES",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  letterSpacing: 1),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${todaySales.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${todayOrders.length} orders today',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        // Export CSV button
                        IconButton(
                          onPressed: _exporting
                              ? null
                              : () => _exportMonthCsv(rawDocs),
                          icon: _exporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded,
                                  color: Colors.white70),
                          tooltip: 'Export month CSV',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Stat cards row (Gold icon) ──────────────────
                  Row(
                    children: [
                      Expanded(
                          child: _statCard(
                              'ORDERS',
                              '${allOrders.length}',
                              Icons.shopping_bag_outlined)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard(
                              'ACTIVE',
                              '$activeCount',
                              Icons.access_time_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Quick action grid ───────────────────────────
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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                KhataScreen(vendorId: widget.vendor.uid),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ActionCard(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        color: Colors.grey,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VendorSettingsScreen(
                                vendor: widget.vendor),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Incoming Orders section ─────────────────────
                  const Text(
                    'Incoming Orders',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C2C2C)),
                  ),
                  const SizedBox(height: 12),

                  StreamBuilder<List<OrderModel>>(
                    stream: _fs.vendorOrders(widget.vendor.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF0F7B6C)));
                      }
                      final orders = snapshot.data ?? [];
                      final active = orders
                          .where((o) =>
                              o.status == 'new' ||
                              o.status == 'accepted')
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
                              Text(
                                  'New orders will appear here in real time',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: active
                            .map(
                              (order) => TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration:
                                    const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) =>
                                    Transform.translate(
                                  offset: Offset(0, (1 - value) * 30),
                                  child: Opacity(
                                      opacity: value, child: child),
                                ),
                                child: _OrderCard(
                                  order: order,
                                  onAccept: () => _fs.updateOrderStatus(
                                      order.id, 'accepted'),
                                  onReject: () => _fs.updateOrderStatus(
                                      order.id, 'rejected'),
                                  onDispatched: () =>
                                      _fs.updateOrderStatus(
                                          order.id, 'dispatched'),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFC9A227), size: 20),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  letterSpacing: 0.5)),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C))),
        ],
      ),
    );
  }
}

// ── _ActionCard ────────────────────────────────────────────────
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

// ── _OrderCard ─────────────────────────────────────────────────
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
              Text(
                order.customerName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2C2C2C)),
              ),
              Row(
                children: [
                  if (order.status == 'new')
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OrderCountdownBadge(
                          createdAt: order.createdAt),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
                color: Color(0xFF0F7B6C),
                fontWeight: FontWeight.w600),
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
                      side:
                          const BorderSide(color: Color(0xFFE85A2B)),
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

// ── Internal data class for stats ──────────────────────────────
class _OrderData {
  final QueryDocumentSnapshot doc;
  final DateTime createdAt;
  final double total;
  final String status;
  _OrderData({
    required this.doc,
    required this.createdAt,
    required this.total,
    required this.status,
  });
}