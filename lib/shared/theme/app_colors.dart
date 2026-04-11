import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF1E3A5F);
  static const accent1 = Color(0xFF06B6D4);
  static const accent2 = Color(0xFF4F46E5);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8FAFC);

  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent1],
  );
}
