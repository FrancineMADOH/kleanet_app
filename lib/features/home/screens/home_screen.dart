// Shell de navigation principale — 4 onglets via BottomNavigationBar.
//
// Remplace l'ancien écran transitoire (CATALOG-01) par la vraie architecture
// de navigation de l'app. L'IndexedStack garantit que l'état de chaque onglet
// est préservé lors des changements de tab (OrdersListScreen ne recharge pas
// en quittant puis revenant sur l'onglet Commandes).
//
// Structure des onglets :
//   0 — Accueil     : catalogue de vêtements (pull-to-refresh)
//   1 — Commandes   : OrdersListScreen (filtre + liste)
//   2 — Abonnement  : hub + plans + confirmation (sous-navigation inline)
//   3 — Profil      : placeholder "Bientôt disponible"
//
// FAB "Nouvelle commande" visible uniquement sur l'onglet Accueil (index 0).
//
// Sous-navigation de l'onglet Abonnement :
//   _SubTab.hub     → SubscriptionHubScreen (page de vente / dashboard)
//   _SubTab.plans   → PlansScreen (comparaison des plans)
//   _SubTab.confirm → SubscribeConfirmScreen (récapitulatif + CTA)
// La BottomNavigationBar reste visible sur les 3 sous-états.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../catalog/models/catalog_models.dart';
import '../../catalog/providers/catalog_provider.dart';
import '../../orders/screens/orders_list_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../subscription/models/subscription_models.dart';
import '../../subscription/screens/subscribe_confirm_screen.dart';
import '../../subscription/screens/plans_screen.dart';
import '../../subscription/screens/subscription_hub_screen.dart';

// Sous-états de l'onglet Abonnement — hub (défaut), liste des plans, confirmation.
enum _SubTab { hub, plans, confirm }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Onglet courant — 0 = Accueil, 1 = Commandes, 2 = Abonnement, 3 = Profil.
  int _currentIndex = 0;

  // Sous-état de l'onglet Abonnement (index 2).
  // Réinitialisé à hub quand l'utilisateur quitte puis revient sur l'onglet.
  _SubTab _subTab = _SubTab.hub;

  // Plan sélectionné sur PlansScreen — transmis à SubscribeConfirmScreen.
  SubscriptionPlan? _selectedPlan;

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

  // Titre de l'AppBar selon l'onglet actif.
  String get _appBarTitle => switch (_currentIndex) {
        0 => 'Kleanet',
        1 => 'Mes commandes',
        2 => 'Mon abonnement',
        3 => 'Profil',
        _ => 'Kleanet',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Pas de bouton retour — ce sont des onglets racine.
        automaticallyImplyLeading: false,
        title: Text(_appBarTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // Déconnexion déplacée dans l'onglet Profil (tab 3).
      ),
      // IndexedStack conserve l'état de chaque onglet en mémoire —
      // OrdersListScreen ne recharge pas ses données lors d'un retour sur l'onglet.
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Onglet 0 — Catalogue (RefreshIndicator sur la liste seulement).
          RefreshIndicator(
            onRefresh: _refresh,
            child: _CatalogTab(),
          ),
          // Onglet 1 — Liste des commandes.
          // embedded: true → pas de Scaffold interne, le Scaffold parent suffit.
          // OrdersListProvider injecté dans le MultiProvider racine (app.dart).
          const OrdersListScreen(embedded: true),
          // Onglet 2 — IndexedStack interne pour préserver l'état de chaque
          // sous-écran. Les 3 enfants sont fixes — seul l'index change selon
          // _subTab. IndexedStack garde les widgets en mémoire entre les
          // changements d'onglet → SubscriptionHubScreen ne se remonte plus.
          IndexedStack(
            index: _subTab.index,
            children: [
              // Sous-écran 0 — Hub (page de vente / dashboard / pending).
              SubscriptionHubScreen(
                embedded: true,
                onShowPlans: () => setState(() => _subTab = _SubTab.plans),
              ),
              // Sous-écran 1 — Comparaison des plans.
              PlansScreen(
                onPlanSelected: (plan) => setState(() {
                  _selectedPlan = plan;
                  _subTab = _SubTab.confirm;
                }),
                onBack: () => setState(() => _subTab = _SubTab.hub),
              ),
              // Sous-écran 2 — Confirmation. Nécessite un plan non-null.
              // SizedBox.shrink quand aucun plan n'est encore sélectionné
              // (index != 2) pour éviter un accès null avant la sélection.
              if (_selectedPlan != null)
                SubscribeConfirmScreen(
                  plan: _selectedPlan!,
                  onSuccess: () => setState(() {
                    _subTab = _SubTab.hub;
                    _selectedPlan = null;
                  }),
                  onBack: () => setState(() => _subTab = _SubTab.plans),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
          // Onglet 3 — Profil (PROFILE-01). Déconnexion dans ProfileScreen.
          const ProfileScreen(),
        ],
      ),
      // FAB uniquement sur l'onglet Accueil — context.push pour conserver
      // la capacité à revenir sur /home via le bouton retour Android.
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.newOrder),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle commande'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        // Pas de reset de _subTab ici — l'IndexedStack interne préserve
        // l'état du sous-écran actif. Le hub affiche le bon état (pending,
        // actif, vente) car le provider est watché en continu.
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.accent1,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Commandes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.workspace_premium_outlined),
            activeIcon: Icon(Icons.workspace_premium),
            label: 'Abonnement',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Onglet 0 — Catalogue
// ----------------------------------------------------------------

/// Contenu de l'onglet Accueil : header + liste des types de vêtements.
/// Les tuiles "Mes commandes" et "Mon abonnement" ont été retirées car
/// ces fonctions sont maintenant accessibles via la barre de navigation.
class _CatalogTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();

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
              // onPressed accède à CatalogProvider via un Builder pour éviter
              // un context capturé trop haut dans l'arbre (StatelessWidget).
              onPressed: () =>
                  context.read<CatalogProvider>().load(forceRefresh: true),
              child: const Text('Réessayer'),
            ),
          ),
        ],
      );
    }

    // 3. Cas nominal — header catalogue + liste des types de vêtements.
    final types = catalog.garmentTypes;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      // +1 pour le header catalogue (index 0), puis les types à partir de index 1.
      itemCount: types.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) return _HeaderCard(fetchedAt: catalog.fetchedAt);
        final type = types[index - 1];
        return _GarmentCard(
          type: type,
          priceLabel: catalog.formattedPriceFor(type),
        );
      },
    );
  }
}

// ----------------------------------------------------------------
// Widgets partagés du catalogue (inchangés depuis CATALOG-01)
// ----------------------------------------------------------------

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
