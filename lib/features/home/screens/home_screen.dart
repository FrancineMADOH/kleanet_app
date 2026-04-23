// Home shell temporaire — affiche la liste du catalogue récupéré.
//
// C'est UN écran transitoire : CATALOG-01 exige juste "chaque article
// affiche nom + prix". En ORDER-01 on remplacera ce shell par un vrai
// Home avec bottom navigation, sections promos, abonnement, etc. Pour
// l'instant il sert surtout à :
//   1. Valider visuellement le catalog provider (loading / data / error).
//   2. Offrir un bouton logout pour tester la bascule de session.
//   3. Offrir un pull-to-refresh pour tester le forceRefresh.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalog/models/catalog_models.dart';
import '../../catalog/providers/catalog_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Déclenche un load() post-frame — la méthode est idempotente et
    // respecte le cache si déjà peuplé en mémoire par le preload main.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().load();
    });
  }

  Future<void> _refresh() async {
    await context.read<CatalogProvider>().load(forceRefresh: true);
  }

  Future<void> _handleLogout() async {
    final auth = context.read<AuthProvider>();
    final catalog = context.read<CatalogProvider>();
    await auth.signOut();
    await catalog.clear();
    // Pas besoin de context.go — le router redirect listener bascule
    // automatiquement sur /auth quand AuthStatus passe à unauthenticated.
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kleanet'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(catalog),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.newOrder),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle commande'),
      ),
    );
  }

  Widget _buildBody(CatalogProvider catalog) {
    // 1. Chargement initial, aucune donnée en cache → spinner plein écran.
    if (catalog.isLoading && catalog.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Erreur ET pas de cache → empty state avec retry.
    if (catalog.errorMessage != null && catalog.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            catalog.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _refresh,
              child: const Text('Réessayer'),
            ),
          ),
        ],
      );
    }

    // 3. Cas nominal — raccourci "Mes commandes" + liste des types de vêtements.
    final types = catalog.garmentTypes;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: types.length + 3, // +1 tuile commandes, +1 tuile abonnement, +1 header catalogue
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) return const _MyOrdersTile();
        if (index == 1) return const _SubscriptionTile();
        if (index == 2) return _HeaderCard(fetchedAt: catalog.fetchedAt);
        final type = types[index - 3];
        return _GarmentCard(
          type: type,
          priceLabel: catalog.formattedPriceFor(type),
        );
      },
    );
  }
}

/// Tuile d'accès rapide à la liste des commandes — placée en tête du home
/// pour que l'utilisateur puisse consulter ses commandes sans chercher.
class _MyOrdersTile extends StatelessWidget {
  const _MyOrdersTile();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(Routes.orders),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mes commandes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Suivre mes commandes en cours',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Tuile d'accès à l'abonnement — icône premium sur fond cyan.
class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(Routes.subscription),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mon abonnement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Voir mes avantages et ma consommation',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Carte d'en-tête — affiche le timestamp de dernière MAJ du catalogue.
/// Utile en debug pour vérifier que le cache / refresh marchent.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.fetchedAt});

  final DateTime? fetchedAt;

  @override
  Widget build(BuildContext context) {
    final label = fetchedAt == null
        ? 'Catalogue indisponible'
        : 'Mis à jour à ${_formatTime(fetchedAt!)}';
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.local_laundry_service, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nos services',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Ligne catalogue — nom + badge "article spécial" + prix formaté.
class _GarmentCard extends StatelessWidget {
  const _GarmentCard({
    required this.type,
    required this.priceLabel,
  });

  final GarmentType type;
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        title: Text(
          type.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: type.defaultMaterial == null
            ? null
            : Text(
                type.defaultMaterial!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
        trailing: Text(
          priceLabel,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
