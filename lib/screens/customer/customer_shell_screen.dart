import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import 'cart_screen.dart';
import 'customer_home_screen.dart';
import 'category_browse_screen.dart';
import 'uncle_screen.dart';
import 'my_orders_screen.dart';

class CustomerShellScreen extends StatefulWidget {
  final UserModel customer;

  const CustomerShellScreen({super.key, required this.customer});

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    final emptyVendor = UserModel(
      uid: widget.customer.uid,
      role: 'vendor',
      name: 'Shop',
      email: '',
      phone: '',
      address: '',
      fcmToken: '',
      createdAt: DateTime.now(),
      businessName: 'Cart',
      category: 'General',
      isOpen: true,
      deliveryFee: 0,
      minOrderValue: 0,
    );

    _screens = [
      CustomerHomeScreen(user: widget.customer),
      CategoryBrowseScreen(customer: widget.customer),
      CartScreen(
        cart: <ProductModel, int>{},
        vendor: emptyVendor,
        customer: widget.customer,
      ),
      UncleScreen(customer: widget.customer),
      MyOrdersScreen(customerId: widget.customer.uid),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Categories'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Uncle'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
        ],
      ),
    );
  }
}