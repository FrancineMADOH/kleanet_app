// Écran de détail / tracking d'une commande.
//
// Monté via GoRouter `/order/:id` avec un ChangeNotifierProvider
// factory qui instancie OrderDetailProvider(orderId). L'écran lui-même
// ne construit pas le provider — il le consomme via context.watch.
//
// Comportement :
//   - Premier build : déclenche un load() post-frame.
//   - Pull-to-refresh : appelle load() manuellement.
//   - Si erreur ET pas de données → empty state avec bouton retour Home.
//   - Si données présentes → header + timeline + lignes + notes.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/currency_utils.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/order_models.dart';
import '../providers/order_detail_provider.dart';
import 'widgets/order_status_timeline.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderDetailProvider>().load();
    });
  }

  Future<void> _refresh() => context.read<OrderDetailProvider>().load();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderDetailProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail commande'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(OrderDetailProvider provider) {
    // Premier chargement sans données → spinner plein écran.
    if (provider.isLoading && !provider.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    // Erreur sans données → empty state avec retour home.
    if (provider.errorMessage != null && !provider.hasData) {
      return _EmptyError(
        message: provider.errorMessage!,
        onRetry: _refresh,
      );
    }
    // Données disponibles (potentiellement en refresh en arrière-plan).
    final order = provider.order!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(order: order),
          const SizedBox(height: 16),
          const _SectionTitle('Suivi'),
          const SizedBox(height: 8),
          OrderStatusTimeline(
            currentStatus: order.status,
            dateReceived: order.dateReceived,
            dateReady: order.dateReady,
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Articles'),
          const SizedBox(height: 8),
          ...order.lines.map((l) => _LineTile(line: l)),
          const SizedBox(height: 16),
          _TotalCard(order: order),
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionTitle('Notes'),
            const SizedBox(height: 8),
            _NotesCard(notes: order.notes!),
          ],
          // Bouton "Laisser un avis" — visible uniquement pour les commandes
          // livrées. La référence commande est passée en extra pour l'affichage
          // dans le formulaire.
          if (order.status == OrderStatus.delivered) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  Routes.feedbackForm(order.id.toString()),
                  extra: order.reference,
                ),
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Laisser un avis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent1,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.reference,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          StatusBadge(status: order.status),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});
  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    // Quantité ou poids : on affiche celui qui est non-nul.
    final hasPieces = line.quantity > 0;
    final amountLabel = hasPieces
        ? '${line.quantity.toInt()} × ${CurrencyUtils.formatXAF(line.unitPrice)}'
        : '${line.weightKg.toStringAsFixed(1)} kg × ${CurrencyUtils.formatXAF(line.unitPrice)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.garmentTypeName ?? 'Article',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amountLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyUtils.formatXAF(line.subtotal),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _Row(label: 'Articles', value: '${order.totalPieces}'),
          const SizedBox(height: 8),
          _Row(
            label: 'Total',
            value: CurrencyUtils.formatXAF(order.amountTotal),
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 18 : 14,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      );
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          notes,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

class _EmptyError extends StatelessWidget {
  const _EmptyError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
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
        Center(
          child: ElevatedButton(
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => context.go(Routes.home),
            child: const Text('Retour à l\'accueil'),
          ),
        ),
      ],
    );
  }
}
