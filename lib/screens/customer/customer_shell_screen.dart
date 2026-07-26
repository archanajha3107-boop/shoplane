import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'customer_home_screen.dart';
import 'category_browse_screen.dart';
import 'my_orders_screen.dart';
import 'customer_profile_screen.dart';

class CustomerShellScreen extends StatefulWidget {
  final UserModel customer;
  const CustomerShellScreen({super.key, required this.customer});

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      CustomerHomeScreen(user: widget.customer),
      CategoryBrowseScreen(customer: widget.customer),
      MyOrdersScreen(customerId: widget.customer.uid),
      CustomerProfileScreen(customer: widget.customer),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF0F7B6C).withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF0F7B6C)), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded, color: Color(0xFF0F7B6C)), label: 'Categories'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFF0F7B6C)), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF0F7B6C)), label: 'Profile'),
        ],
      ),
    );
  }
}