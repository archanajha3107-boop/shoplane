// add_product_screen.dart
// Vendor-side: single entry point for adding a product.
// Tab 1 = Common Items (EXPANDED seed list, ~100+ items — Bug #5 fix — + "Add Custom Item")
// Tab 2 = Search Packaged (Open Food Facts)
// Supports: image (Camera/Gallery/Emoji), unit-of-measure field (Bug #6 fix),
// optional quality/variant labels for multi-tier pricing.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'product_search_screen.dart';

class AddProductScreen extends StatefulWidget {
  final String vendorId;
  const AddProductScreen({super.key, required this.vendorId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // EXPANDED — Bug #5: was 7/6/5/4/4 items, now genuinely wide-range per category.
  static const Map<String, List<String>> _seedCatalogue = {
    'Vegetables & Fruits': [
      'Tomatoes', 'Onions', 'Potatoes', 'Bananas', 'Apples', 'Spinach', 'Carrots',
      'Cauliflower', 'Cabbage', 'Brinjal', 'Ladyfinger (Bhindi)', 'Green Chilli',
      'Ginger', 'Garlic', 'Capsicum', 'Cucumber', 'Beetroot', 'Peas', 'French Beans',
      'Bottle Gourd (Lauki)', 'Ridge Gourd (Turai)', 'Bitter Gourd (Karela)',
      'Pumpkin', 'Radish', 'Coriander Leaves', 'Mint Leaves', 'Curry Leaves',
      'Fenugreek (Methi)', 'Mango', 'Papaya', 'Watermelon', 'Muskmelon', 'Grapes',
      'Pomegranate', 'Orange', 'Sweet Lime (Mosambi)', 'Guava', 'Pineapple',
      'Chikoo', 'Custard Apple', 'Lemon', 'Coconut', 'Sweet Potato', 'Corn',
      'Drumstick', 'Raw Banana', 'Ash Gourd', 'Colocasia (Arbi)',
    ],
    'Grocery & Provisions': [
      'Rice (Basmati)', 'Rice (Sona Masoori)', 'Wheat Flour (Atta)', 'Toor Dal',
      'Moong Dal', 'Chana Dal', 'Urad Dal', 'Masoor Dal', 'Rajma', 'Chana (Kabuli)',
      'Sugar', 'Jaggery (Gud)', 'Cooking Oil (Sunflower)', 'Cooking Oil (Groundnut)',
      'Mustard Oil', 'Salt', 'Besan (Gram Flour)', 'Maida', 'Suji (Rava)',
      'Poha', 'Vermicelli', 'Tea Leaves', 'Coffee Powder', 'Turmeric Powder',
      'Red Chilli Powder', 'Coriander Powder', 'Cumin Seeds', 'Mustard Seeds',
      'Garam Masala', 'Black Pepper', 'Cloves', 'Cardamom', 'Cinnamon',
      'Bay Leaf', 'Asafoetida (Hing)', 'Tamarind', 'Papad', 'Pickle',
      'Ketchup', 'Soy Sauce', 'Vinegar', 'Baking Powder', 'Baking Soda', 'Honey',
    ],
    'Milk & Dairy': [
      'Milk (Full Cream)', 'Milk (Toned)', 'Curd', 'Paneer', 'Butter', 'Ghee',
      'Cheese Slices', 'Cheese Block', 'Cream', 'Buttermilk (Chaas)', 'Lassi',
      'Flavoured Milk', 'Condensed Milk', 'Milk Powder', 'Khoya', 'Yogurt (Sweetened)',
    ],
    'Meat & Fish': [
      'Chicken (Curry Cut)', 'Chicken (Boneless)', 'Chicken Breast', 'Chicken Wings',
      'Mutton', 'Mutton Keema', 'Fish (Pomfret)', 'Fish (Rohu)', 'Fish (Surmai)',
      'Prawns', 'Crab', 'Eggs', 'Egg White', 'Bacon', 'Sausages',
    ],
    'Snacks & Food Stalls': [
      'Biscuits (Glucose)', 'Biscuits (Cream)', 'Chips (Potato)', 'Chips (Banana)',
      'Namkeen (Mixture)', 'Sev', 'Chakli', 'Chocolate', 'Wafers', 'Popcorn',
      'Bread (White)', 'Bread (Brown)', 'Rusk', 'Cake', 'Cookies', 'Instant Noodles',
      'Instant Soup', 'Papad (Fried)', 'Peanuts', 'Cashews', 'Almonds', 'Dry Fruits Mix',
      'Ice Cream', 'Chewing Gum', 'Candy',
    ],
  };

  static const List<String> _units = ['kg', 'g', 'L', 'ml', 'piece', 'dozen', 'packet', 'bunch'];

  static const List<String> _emojiOptions = [
    '🥦', '🍅', '🥔', '🍌', '🍎', '🥬', '🥕', '🍚', '🌾', '🫘',
    '🧂', '🛢️', '🥛', '🍶', '🧀', '🧈', '🍗', '🐐', '🐟', '🥚',
    '🍪', '🍟', '🍫', '🛒',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: 'Common Items'),
          Tab(text: 'Search Packaged'),
        ]),
      ),
      body: TabBarView(controller: _tabController, children: [
        _buildCommonItemsTab(),
        ProductSearchScreen(vendorId: widget.vendorId),
      ]),
    );
  }

  Widget _buildCommonItemsTab() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          children: _seedCatalogue.entries.map((entry) {
            return ExpansionTile(
              title: Text('${entry.key} (${entry.value.length} items)', style: const TextStyle(fontWeight: FontWeight.bold)),
              children: entry.value.map((itemName) {
                return ListTile(
                  title: Text(itemName),
                  trailing: const Icon(Icons.add_circle_outline, color: Colors.teal),
                  onTap: () => _openAddItemDialog(prefillName: itemName, prefillCategory: entry.key),
                );
              }).toList(),
            );
          }).toList(),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openAddItemDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Item'),
            backgroundColor: const Color(0xFF0F7B6C),
          ),
        ),
      ],
    );
  }

  void _openAddItemDialog({String? prefillName, String? prefillCategory}) {
    final nameController = TextEditingController(text: prefillName ?? '');
    final priceController = TextEditingController();
    final variantController = TextEditingController();
    String selectedCategory = prefillCategory ?? _seedCatalogue.keys.first;
    String selectedUnit = _units.first; // Bug #6 fix — unit of measure, was completely missing
    File? pickedImageFile;
    String? pickedEmoji;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(prefillName != null ? 'Add "$prefillName"' : 'Add Custom Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prefillName == null) ...[
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Product Name')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _seedCatalogue.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCategory = v ?? selectedCategory),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        autofocus: prefillName != null,
                        decoration: const InputDecoration(prefixText: '₹', labelText: 'Price', hintText: 'e.g. 40'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) => setDialogState(() => selectedUnit = v ?? selectedUnit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: variantController,
                  decoration: const InputDecoration(
                    labelText: 'Quality / Variant (optional)',
                    hintText: 'e.g. Premium, Regular — only if you sell more than one kind',
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                const Text('Product Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (pickedImageFile != null)
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(pickedImageFile!, height: 100, width: 100, fit: BoxFit.cover))
                else if (pickedEmoji != null)
                  Container(height: 100, width: 100, alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Text(pickedEmoji!, style: const TextStyle(fontSize: 48)))
                else
                  Container(height: 100, width: 100, alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () async {
                        final file = await _pickImage(ImageSource.camera);
                        if (file != null) setDialogState(() { pickedImageFile = file; pickedEmoji = null; });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: () async {
                        final file = await _pickImage(ImageSource.gallery);
                        if (file != null) setDialogState(() { pickedImageFile = file; pickedEmoji = null; });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      onPressed: () async {
                        final emoji = await _showEmojiPicker(dialogContext);
                        if (emoji != null) setDialogState(() { pickedEmoji = emoji; pickedImageFile = null; });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text);
                final variant = variantController.text.trim();

                if (name.isEmpty) { setDialogState(() => errorText = 'Enter a product name'); return; }
                if (price == null || price <= 0) { setDialogState(() => errorText = 'Enter a valid price'); return; }

                final existing = await FirebaseFirestore.instance
                    .collection('products')
                    .where('sellerId', isEqualTo: widget.vendorId)
                    .where('nameLower', isEqualTo: name.toLowerCase())
                    .get();

                final conflict = existing.docs.any((doc) {
                  final existingVariant = (doc.data()['variant'] as String? ?? '').toLowerCase();
                  return existingVariant == variant.toLowerCase();
                });

                if (conflict) {
                  setDialogState(() => errorText = existing.docs.isNotEmpty && variant.isEmpty
                      ? 'You already have "$name" listed. Add a quality label to add it as a second option.'
                      : 'You already have "$name — $variant" listed.');
                  return;
                }

                String? imageBase64;
                if (pickedImageFile != null) {
                  imageBase64 = base64Encode(await pickedImageFile!.readAsBytes());
                }

                await FirebaseFirestore.instance.collection('products').add({
                  'sellerId': widget.vendorId,
                  'name': name,
                  'nameLower': name.toLowerCase(),
                  'price': price,
                  'unit': selectedUnit, // Bug #6 fix
                  if (variant.isNotEmpty) 'variant': variant,
                  'category': selectedCategory,
                  'inStock': true,
                  'isVariableStock': selectedCategory == 'Meat & Fish',
                  'lastUpdated': FieldValue.serverTimestamp(),
                  'photoUrl': '',
                  'source': prefillName != null ? 'seed' : 'custom',
                  if (imageBase64 != null) 'imageBase64': imageBase64,
                  if (pickedEmoji != null) 'emoji': pickedEmoji,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name added to your shop')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<File?> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 40, maxWidth: 600);
    if (picked == null) return null;
    return File(picked.path);
  }

  Future<String?> _showEmojiPicker(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => GridView.count(
        crossAxisCount: 6,
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: _emojiOptions.map((emoji) {
          return IconButton(
            icon: Text(emoji, style: const TextStyle(fontSize: 28)),
            onPressed: () => Navigator.pop(sheetContext, emoji),
          );
        }).toList(),
      ),
    );
  }
}