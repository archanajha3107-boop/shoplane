import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const emerald   = Color(0xFF0F7B6C);
  static const terracotta = Color(0xFFE85A2B);
  static const gold      = Color(0xFFC9A227);
  static const background = Color(0xFFF2F1EF);
  static const charcoal  = Color(0xFF2C2C2C);
  static const white     = Colors.white;

  // Category-specific border colors
  static const vegetable = Color(0xFF4CAF50);
  static const snack = Color(0xFFFF9800);
  static const newspaper = Color(0xFF607D8B);
  static const other = Colors.grey;

  // Order status colors
  static const statusNew = Color(0xFFE85A2B); // Terracotta
  static const statusAccepted = gold;
  static const statusDispatched = Color(0xFF2196F3);
  static const statusDelivered = emerald;
  static const statusRejected = Colors.grey;
}