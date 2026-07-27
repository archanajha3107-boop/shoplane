import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../role_selection_screen.dart';
import 'my_orders_screen.dart';

class CustomerProfileScreen extends StatelessWidget {
  final UserModel customer;
  const CustomerProfileScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F1EF),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                color: const Color(0xFF0F7B6C),
                child: const Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFF0F7B6C),
                foregroundColor: Colors.white,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                customer.name,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2C2C)),
              ),
              Text(
                customer.email,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _tile(
                      context,
                      Icons.receipt_long_rounded,
                      'My Orders',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyOrdersScreen(
                              customerId: customer.uid),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _tile(
                      context,
                      Icons.person_outline_rounded,
                      'Phone: ${customer.phone}',
                      onTap: null,
                    ),
                    const Divider(height: 1, indent: 56),
                    _tile(
                      context,
                      Icons.home_outlined,
                      customer.address.isNotEmpty
                          ? customer.address
                          : 'No address set',
                      onTap: null,
                    ),
                    const Divider(height: 1, indent: 56),
                    _tile(
                      context,
                      Icons.logout_rounded,
                      'Logout',
                      color: const Color(0xFFE85A2B),
                      onTap: () async {
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
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF0F7B6C)),
      title: Text(
        label,
        style: TextStyle(
            color: color ?? const Color(0xFF2C2C2C),
            fontWeight: FontWeight.w500),
      ),
      trailing: onTap != null
          ? Icon(Icons.chevron_right, color: color ?? Colors.grey)
          : null,
      onTap: onTap,
    );
  }
}