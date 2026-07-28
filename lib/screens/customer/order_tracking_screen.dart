import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Track Order'),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: FirestoreService().customerOrders(''),
        builder: (context, snapshot) {
          return FutureBuilder<OrderModel?>(
            future: _getOrder(orderId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0F7B6C)));
              }
              final order = snap.data;
              if (order == null) {
                return const Center(child: Text('Order not found'));
              }
              return _buildBody(context, order);
            },
          );
        },
      ),
    );
  }

  Future<OrderModel?> _getOrder(String id) async {
    // Uses Firestore directly for single doc fetch
    final fs = FirestoreService();
    try {
      final doc = await fs.getOrder(id);
      return doc;
    } catch (e) {
      return null;
    }
  }

  Widget _buildBody(BuildContext context, OrderModel order) {
    final steps = ['new', 'accepted', 'dispatched', 'delivered'];
    final labels = [
      'Order Placed',
      'Accepted',
      'Dispatched',
      'Delivered'
    ];
    final currentStep = steps.indexOf(order.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Order summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.shopName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C2C2C))),
                const SizedBox(height: 4),
                Text(
                  order.items
                      .map((i) => '${i.name} x${i.qty}')
                      .join(', '),
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${order.total.toStringAsFixed(0)} • ${order.fulfillmentType} • ${order.paymentMethod}',
                  style: const TextStyle(
                      color: Color(0xFF0F7B6C),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Status timeline
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Status',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C2C2C))),
                const SizedBox(height: 20),
                ...List.generate(steps.length, (i) {
                  final done = i <= currentStep;
                  final isLast = i == steps.length - 1;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: done
                                  ? const Color(0xFF0F7B6C)
                                  : Colors.transparent,
                              border: Border.all(
                                color: done
                                    ? const Color(0xFF0F7B6C)
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: done
                                ? const Icon(Icons.check,
                                    color: Colors.white,
                                    size: 14)
                                : null,
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 36,
                              color: done && i < currentStep
                                  ? const Color(0xFF0F7B6C)
                                  : Colors.grey.shade300,
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontWeight: done
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: done
                                ? const Color(0xFF2C2C2C)
                                : Colors.grey,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Report issue
          if (order.status != 'new')
            TextButton(
              onPressed: () =>
                  _showReportDialog(context, order.id),
              child: const Text(
                'Report an issue with this order',
                style: TextStyle(color: Color(0xFFE85A2B)),
              ),
            ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _issueOption(context, orderId, 'Wrong items received'),
            _issueOption(context, orderId, 'Order arrived late'),
            _issueOption(context, orderId, 'Vendor did not respond'),
            _issueOption(context, orderId, 'Other issue'),
          ],
        ),
      ),
    );
  }

  Widget _issueOption(
      BuildContext context, String orderId, String reason) {
    return ListTile(
      title: Text(reason, style: const TextStyle(fontSize: 14)),
      onTap: () async {
        await FirestoreService().flagOrderIssue(orderId, reason);
        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue reported. We will look into it.'),
            backgroundColor: Color(0xFF0F7B6C),
          ),
        );
      },
    );
  }
}
class _AnimatedStatusDot extends StatefulWidget {
  final bool completed;
  final bool isCurrent;
  const _AnimatedStatusDot({required this.completed, required this.isCurrent});

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent) {
      return Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: widget.completed ? const Color(0xFF0F7B6C) : Colors.transparent,
          border: Border.all(color: widget.completed ? const Color(0xFF0F7B6C) : Colors.grey.shade300, width: 2),
          shape: BoxShape.circle,
        ),
        child: widget.completed ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF0F7B6C).withValues(alpha: 0.4 + (_controller.value * 0.6)),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F7B6C).withValues(alpha: 0.3 * _controller.value),
              blurRadius: 8 * _controller.value,
              spreadRadius: 3 * _controller.value,
            ),
          ],
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 14),
      ),
    );
  }
}