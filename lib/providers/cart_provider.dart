import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';

class CartProvider extends ChangeNotifier {
  final Map<ProductModel, int> _items = {};
  UserModel? _vendor;

  Map<ProductModel, int> get items => Map.unmodifiable(_items);
  UserModel? get vendor => _vendor;
  int get itemCount => _items.values.fold(0, (a, b) => a + b);
  double get subtotal =>
      _items.entries.fold(0, (s, e) => s + (e.key.price * e.value));

  void addItem(ProductModel product, UserModel vendor) {
    if (_vendor != null && _vendor!.uid != vendor.uid) {
      _items.clear();
    }
    _vendor = vendor;
    _items[product] = (_items[product] ?? 0) + 1;
    notifyListeners();
  }

  void removeItem(ProductModel product) {
    if (_items.containsKey(product)) {
      if (_items[product]! <= 1) {
        _items.remove(product);
      } else {
        _items[product] = _items[product]! - 1;
      }
      if (_items.isEmpty) _vendor = null;
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _vendor = null;
    notifyListeners();
  }
}
