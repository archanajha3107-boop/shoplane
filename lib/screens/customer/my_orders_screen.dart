import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../constants/app_colors.dart';
import '../../services/firestore_service.dart';
import 'order_tracking_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  final String customerId;
  final bool embedded;
  const MyOrdersScreen({super.key, required this.customerId, this.embedded = false});

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return AppColors.statusNew;
      case 'accepted':
        return AppColors.statusAccepted;
      case 'dispatched':
        return AppColors.statusDispatched;
      case 'delivered':
        return AppColors.statusDelivered;
      case 'rejected':
        return AppColors.statusRejected;
      default:
        return Colors.grey;
    }
  }


  @override
  Widget build(BuildContext context) {
    final content = StreamBuilder<List<OrderModel>>(
      stream: FirestoreService().customerOrders(customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF0F7B6C)));
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('No orders yet',
                    style: TextStyle(
                        color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final order = orders[i];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderTrackingScreen(orderId: order.id),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order.shopName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF2C2C2C))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(order.status)
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            order.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _statusColor(order.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.items
                          .map((i) => '${i.name} x${i.qty}')
                          .join(', '),
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${order.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color(0xFF0F7B6C),
                              fontWeight: FontWeight.bold),
                        ),
                        const Text('Tap to track →',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (embedded) {
      return Container(
        color: const Color(0xFFF2F1EF),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: const Color(0xFF0F7B6C),
                child: const Text(
                  'My Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('My Orders'),
      ),
      body: content,
    );
  }
}