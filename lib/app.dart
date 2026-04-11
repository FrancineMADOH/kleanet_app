import 'package:flutter/material.dart';

import 'shared/theme/app_colors.dart';
import 'shared/theme/app_text_styles.dart';
import 'shared/theme/app_theme.dart';

class KleanetApp extends StatelessWidget {
  const KleanetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kleanet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _SplashPlaceholder(),
    );
  }
}

class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo/logo_complet.png',
                  width: 220,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  'Laverie à domicile à Yaoundé',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
