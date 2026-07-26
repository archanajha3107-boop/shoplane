import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedMasterCatalog() async {
  final db = FirebaseFirestore.instance;
  final products = [
    {'name': 'Kurkure Masala Munch', 'brand': 'Kurkure', 'category': 'Snacks & Food Stalls', 'mrp': 20.0, 'unit': '90g'},
    {'name': 'Lays Classic Salted', 'brand': "Lay's", 'category': 'Snacks & Food Stalls', 'mrp': 20.0, 'unit': '52g'},
    {'name': 'Parle-G Biscuits', 'brand': 'Parle', 'category': 'Snacks & Food Stalls', 'mrp': 10.0, 'unit': '100g'},
    {'name': 'Amul Toned Milk', 'brand': 'Amul', 'category': 'Milk & Dairy', 'mrp': 28.0, 'unit': '500ml'},
    {'name': 'Amul Butter', 'brand': 'Amul', 'category': 'Milk & Dairy', 'mrp': 56.0, 'unit': '100g'},
    {'name': 'Mother Dairy Curd', 'brand': 'Mother Dairy', 'category': 'Milk & Dairy', 'mrp': 30.0, 'unit': '400g'},
    {'name': 'Tata Salt', 'brand': 'Tata', 'category': 'Grocery & Provisions', 'mrp': 25.0, 'unit': '1kg'},
    {'name': 'Fortune Sunflower Oil', 'brand': 'Fortune', 'category': 'Grocery & Provisions', 'mrp': 145.0, 'unit': '1L'},
    {'name': 'Toor Dal', 'brand': 'Generic', 'category': 'Grocery & Provisions', 'mrp': 140.0, 'unit': '1kg'},
    {'name': 'India Gate Basmati Rice', 'brand': 'India Gate', 'category': 'Grocery & Provisions', 'mrp': 180.0, 'unit': '1kg'},
    {'name': 'Tomatoes', 'brand': 'Fresh', 'category': 'Vegetables & Fruits', 'mrp': 40.0, 'unit': '1kg'},
    {'name': 'Onions', 'brand': 'Fresh', 'category': 'Vegetables & Fruits', 'mrp': 35.0, 'unit': '1kg'},
    {'name': 'Potatoes', 'brand': 'Fresh', 'category': 'Vegetables & Fruits', 'mrp': 30.0, 'unit': '1kg'},
    {'name': 'Bananas', 'brand': 'Fresh', 'category': 'Vegetables & Fruits', 'mrp': 50.0, 'unit': '1 dozen'},
    {'name': 'Farm Eggs', 'brand': 'Fresh', 'category': 'Meat & Fish', 'mrp': 90.0, 'unit': '12 pcs'},
    {'name': 'Chicken (broiler)', 'brand': 'Fresh', 'category': 'Meat & Fish', 'mrp': 220.0, 'unit': '1kg'},
  ];
  for (final p in products) {
    await db.collection('masterProducts').add(p);
  }
}