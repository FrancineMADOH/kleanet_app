// Écran liste des commandes.
//
// Structure :
//   - AppBar "Mes commandes" avec bouton retour.
//   - Barre de filtres (chips horizontaux) : Toutes + 5 statuts.
//   - ListView des OrderCard, chacune navigable vers /order/:id.
//   - Pull-to-refresh → relance load().
//   - Empty state si liste vide (message contextuel selon filtre actif).
//   - Spinner plein écran sur premier chargement sans données.
//   - Erreur sans données → empty state avec bouton Réessayer.
//
// Provider scoped : instancié dans le builder de la route /orders
// (ChangeNotifierProvider factory) → pas de leak entre navigations.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/currency_utils.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/order_models.dart';
import '../providers/orders_list_provider.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  @override
  void initState() {
    super.initState();
    // Déclenche le chargement après le premier build pour que le provider
    // soit déjà dans l'arbre et que notifyListeners() soit capturé.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersListProvider>().load();
    });
  }

  Future<void> _refresh() => context.read<OrdersListProvider>().load();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdersListProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes commandes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barre de filtres — toujours visible, même pendant le chargement.
          _FilterBar(
            activeFilter: provider.activeFilter,
            onFilterChanged: context.read<OrdersListProvider>().setFilter,
          ),
          Expanded(child: _buildBody(provider)),
        ],
      ),
    );
  }

  Widget _buildBody(OrdersListProvider provider) {
    // Premier chargement sans données → spinner centré.
    if (provider.isLoading && provider.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Erreur sans aucune données → empty state avec retry.
    if (provider.errorMessage != null && provider.orders.isEmpty) {
      return _ErrorState(
        message: provider.errorMessage!,
        onRetry: _refresh,
      );
    }

    // Liste vide après chargement réussi → empty state contextuel.
    if (provider.isEmpty) {
      return _EmptyState(hasFilter: provider.activeFilter != null);
    }

    // Cas nominal : liste des commandes, avec pull-to-refresh.
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: provider.orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _OrderCard(order: provider.orders[i]),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Barre de filtres
// ----------------------------------------------------------------

/// Filtre sous forme de chips horizontaux défilables.
/// Le chip "Toutes" correspond à [activeFilter] == null.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final OrderStatus? activeFilter;
  final void Function(OrderStatus?) onFilterChanged;

  // Ordre d'affichage des chips — null = "Toutes".
  static const _filters = <OrderStatus?>[
    null,
    OrderStatus.pending,
    OrderStatus.received,
    OrderStatus.readyForPickup,
    OrderStatus.delivered,
    OrderStatus.cancelled,
  ];

  static String _label(OrderStatus? s) => switch (s) {
        null => 'Toutes',
        OrderStatus.pending => 'En attente',
        OrderStatus.received => 'En traitement',
        OrderStatus.readyForPickup => 'Prêtes',
        OrderStatus.delivered => 'Livrées',
        OrderStatus.cancelled => 'Annulées',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _filters.map((status) {
            final isSelected = activeFilter == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_label(status)),
                selected: isSelected,
                onSelected: (_) => onFilterChanged(status),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                side: BorderSide(
                  color:
                      isSelected ? AppColors.primary : AppColors.border,
                ),
                backgroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Carte commande
// ----------------------------------------------------------------

/// Carte cliquable représentant une commande dans la liste.
/// Affiche : référence, badge statut, nb articles, montant total.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(Routes.orderDetail(order.id.toString())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : référence + badge statut.
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.reference,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                StatusBadge(status: order.status, fontSize: 11),
              ],
            ),
            const SizedBox(height: 10),
            // Ligne 2 : nb articles à gauche, montant à droite.
            Row(
              children: [
                const Icon(
                  Icons.local_laundry_service,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${order.totalPieces} article${order.totalPieces > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  CurrencyUtils.formatXAF(order.amountTotal),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// États vides / erreur
// ----------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? 'Aucune commande avec ce statut.'
                  : 'Vous n\'avez pas encore de commandes.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            if (!hasFilter) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(Routes.newOrder),
                icon: const Icon(Icons.add),
                label: const Text('Passer une commande'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
