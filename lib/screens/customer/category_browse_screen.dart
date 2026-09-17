import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/vendor_matcher.dart'; // Make sure this is imported
import 'vendor_match_results_screen.dart';

class CategoryBrowseScreen extends StatefulWidget {
  final UserModel customer;
  final bool embedded;
  const CategoryBrowseScreen({super.key, required this.customer, this.embedded = false});

  @override
  State<CategoryBrowseScreen> createState() => _CategoryBrowseScreenState();
}

const Map<String, List<String>> categoryItems = {
  'Vegetables & Fruits': ['Tomatoes', 'Onions', 'Potatoes', 'Bananas', 'Apples', 'Spinach', 'Carrots'],
  'Grocery & Provisions': ['Rice', 'Wheat Flour', 'Toor Dal', 'Sugar', 'Cooking Oil', 'Salt'],
  'Milk & Dairy': ['Milk', 'Curd', 'Paneer', 'Butter', 'Cheese'],
  'Meat & Fish': ['Chicken', 'Mutton', 'Fish', 'Eggs'],
  'Snacks & Food Stalls': ['Biscuits', 'Chips', 'Namkeen', 'Chocolate'],
};

class _CategoryBrowseScreenState extends State<CategoryBrowseScreen> {
  String _activeCategory = 'Vegetables & Fruits';
  final Set<String> _wishlist = {};

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: categoryItems.keys.map((cat) {
              final selected = cat == _activeCategory;
              return GestureDetector(
                onTap: () => setState(() => _activeCategory = cat),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF0F7B6C) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? const Color(0xFF0F7B6C) : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF2C2C2C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: categoryItems[_activeCategory]!.length,
            itemBuilder: (context, i) {
              final item = categoryItems[_activeCategory]![i];
              final selected = _wishlist.contains(item);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _wishlist.remove(item);
                  } else {
                    _wishlist.add(item);
                  }
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF0F7B6C).withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? const Color(0xFF0F7B6C) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: selected ? const Color(0xFF0F7B6C) : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    final bottomBar = _wishlist.isEmpty
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // 1. Show loading progress indicator while calculating matches
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      // 2. Fetch active vendors from Firebase
                      final vendorsSnapshot = await FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'vendor')
                          .get();
                          
                      final nearbyVendors = vendorsSnapshot.docs
                          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
                          .toList();

                      // 3. Compute matching result using the Set Cover algorithm
                      final matchResult = await findVendorsForList(
                        _wishlist.toList(),
                        nearbyVendors,
                      );

                      // Dismiss loading dialog
                      if (context.mounted) Navigator.pop(context);

                      // 4. Navigate to results screen passing ALL required arguments
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VendorMatchResultsScreen(
                              matchResult: matchResult, // Fixed: Required parameter added
                              customer: widget.customer,
                              wishlist: _wishlist.toList(),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      // Dismiss loading dialog on error
                      if (context.mounted) Navigator.pop(context);
                      
                      // Show snackbar feedback
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error finding shops: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE85A2B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Find shops · ${_wishlist.length} item${_wishlist.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          );

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF2F1EF),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: const Color(0xFF0F7B6C),
                child: const Text(
                  'What do you need?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: content),
              if (bottomBar != null) bottomBar,
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
        title: const Text('What do you need?'),
      ),
      body: content,
      bottomNavigationBar: bottomBar,
    );
  }
}