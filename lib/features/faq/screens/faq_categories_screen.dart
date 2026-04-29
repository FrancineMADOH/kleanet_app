// Écran FAQ — liste des catégories avec articles en accordéon (Écran 23).
//
// Monté via GoRouter /faq avec un FaqProvider factory-scopé à cette route.
// Accessible sans authentification (guard désactivé sur /faq dans app_router.dart).
//
// Comportements :
//   - Chargement initial post-frame → FaqProvider.load()
//   - Barre de recherche → filtre local via FaqProvider.setSearch()
//   - Si recherche active → liste plate des articles filtrés
//   - Si recherche vide  → ExpansionTile par catégorie
//   - 0 résultat recherche → bouton "Contacter Kleanet" (WhatsApp + fallback web)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/faq_models.dart';
import '../providers/faq_provider.dart';

class FaqCategoriesScreen extends StatefulWidget {
  const FaqCategoriesScreen({super.key});

  @override
  State<FaqCategoriesScreen> createState() => _FaqCategoriesScreenState();
}

class _FaqCategoriesScreenState extends State<FaqCategoriesScreen> {
  final _searchController = TextEditingController();

  // Numéro WhatsApp de la société Kleanet (674 011 983 → format international).
  static const _whatsappPhone = '237674011983';
  static const _whatsappText = 'Bonjour, j\'ai une question sur Kleanet';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FaqProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FaqProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide / FAQ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            onChanged: (q) => context.read<FaqProvider>().setSearch(q),
          ),
          Expanded(child: _buildBody(provider)),
        ],
      ),
    );
  }

  Widget _buildBody(FaqProvider provider) {
    if (provider.isLoading && provider.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.categories.isEmpty) {
      return _buildError(provider.error!);
    }
    if (provider.searchQuery.isNotEmpty) {
      return _buildSearchResults(provider.filteredArticles);
    }
    if (provider.categories.isEmpty) {
      return _buildEmptyState();
    }
    return _buildCategoryList(provider.categories);
  }

  Widget _buildCategoryList(List<FaqCategory> categories) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: categories.length,
      itemBuilder: (_, i) => _CategoryTile(
        category: categories[i],
        onArticleTap: (article) =>
            context.push(Routes.faqArticle(article.id.toString()), extra: article),
      ),
    );
  }

  Widget _buildSearchResults(List<FaqArticle> articles) {
    if (articles.isEmpty) {
      return _buildNoResults();
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      itemCount: articles.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) => _ArticleListTile(
        article: articles[i],
        onTap: () => context.push(
          Routes.faqArticle(articles[i].id.toString()),
          extra: articles[i],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.cloud_off, size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: () => context.read<FaqProvider>().load(),
            child: const Text('Réessayer'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Aucune question disponible pour l\'instant.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.search_off, size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        const Text(
          'Aucun résultat',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Essayez d\'autres mots-clés ou contactez-nous directement.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _openWhatsApp(context),
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('Contacter Kleanet sur WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366), // vert WhatsApp
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  /// Ouvre WhatsApp natif si installé, sinon bascule sur wa.me dans le navigateur.
  Future<void> _openWhatsApp(BuildContext context) async {
    final encoded = Uri.encodeComponent(_whatsappText);
    final nativeUri = Uri.parse('whatsapp://send?phone=$_whatsappPhone&text=$encoded');
    final webUri = Uri.parse('https://wa.me/$_whatsappPhone?text=$encoded');

    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}

// ----------------------------------------------------------------
// Barre de recherche
// ----------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Rechercher une question…',
          hintStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Tuile catégorie avec accordéon
// ----------------------------------------------------------------

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onArticleTap});
  final FaqCategory category;
  final ValueChanged<FaqArticle> onArticleTap;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: EdgeInsets.zero,
      title: Text(
        category.name,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      leading: const Icon(Icons.folder_outlined, color: AppColors.accent1),
      children: category.articles.isEmpty
          ? [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Aucun article dans cette catégorie.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ]
          : category.articles
              .map((art) => _ArticleListTile(
                    article: art,
                    onTap: () => onArticleTap(art),
                    indent: true,
                  ))
              .toList(),
    );
  }
}

// ----------------------------------------------------------------
// Tuile article (réutilisée en accordéon et en résultats de recherche)
// ----------------------------------------------------------------

class _ArticleListTile extends StatelessWidget {
  const _ArticleListTile({
    required this.article,
    required this.onTap,
    this.indent = false,
  });
  final FaqArticle article;
  final VoidCallback onTap;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: indent ? 56 : 16,
        right: 16,
      ),
      leading: const Icon(
        Icons.help_outline,
        size: 18,
        color: AppColors.textSecondary,
      ),
      title: Text(
        article.question,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}
