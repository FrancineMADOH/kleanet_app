import 'package:flutter_test/flutter_test.dart';
import 'package:kleanet_app/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';

void main() {
  test('Kleanet palette exposes brand primary', () {
    expect(AppColors.primary, const Color(0xFF1E3A5F));
    expect(AppColors.accent1, const Color(0xFF06B6D4));
  });
}
