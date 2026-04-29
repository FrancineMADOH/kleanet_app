// Écran article FAQ complet (Écran 24).
//
// Reçoit un FaqArticle via GoRouter `extra` — jamais null (le redirect
// dans app_router.dart renvoie sur /faq si extra est absent).
//
// Le champ `answer` est du HTML provenant d'Odoo — rendu via flutter_html.

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/faq_models.dart';

class FaqArticleScreen extends StatelessWidget {
  const FaqArticleScreen({super.key, required this.article});

  final FaqArticle article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Titre tronqué si la question est trop longue pour l'AppBar.
        title: Text(
          article.question,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question en titre de section — répétée pour lisibilité hors AppBar.
            Text(
              article.question,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            // Réponse HTML — rendu via flutter_widget_from_html_core,
            // compatible Dart 3.6 sans conflit de dépendances.
            HtmlWidget(
              article.answer,
              textStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
