// Étape 1/3 du flux Nouvelle commande — sélection des articles.
//
// Layout : Column avec Expanded(liste) + barre basse fixe. On n'utilise
// PAS Scaffold.bottomNavigationBar pour éviter un bug de layout observé
// où la barre se rendait mal sur certains devices.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/currency_utils.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../catalog/models/catalog_models.dart';
import '../../catalog/providers/catalog_provider.dart';
import '../providers/order_draft_provider.dart';

class NewOrderGarmentsScreen extends StatefulWidget {
  const NewOrderGarmentsScreen({super.key});

  @override
  State<NewOrderGarmentsScreen> createState() => _NewOrderGarmentsScreenState();
}

class _NewOrderGarmentsScreenState extends State<NewOrderGarmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderDraftProvider>().reset();
      context.read<CatalogProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final draft = context.watch<OrderDraftProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle commande'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildContent(catalog, draft)),
            _BottomBar(
              lineCount: draft.lineCount,
              estimatedTotal: draft.estimatedTotal,
              onContinue: draft.hasLines
                  ? () => context.push(Routes.newOrderPickup)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(CatalogProvider catalog, OrderDraftProvider draft) {
    if (catalog.isEmpty && catalog.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final types = catalog.garmentTypes;
    if (types.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Catalogue indisponible. Réessayez plus tard.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: types.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final type = types[index];
        return _GarmentPickerCard(
          type: type,
          priceLabel: catalog.formattedPriceFor(type),
          quantity: draft.quantityFor(type),
          onAdd: () => draft.addItem(type),
          onRemove: () => draft.removeItem(type),
        );
      },
    );
  }
}

class _GarmentPickerCard extends StatelessWidget {
  const _GarmentPickerCard({
    required this.type,
    required this.priceLabel,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final GarmentType type;
  final String priceLabel;
  final double quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isInCart = quantity > 0;
    // Container avec border au lieu de Card — garantit un rendu visible
    // indépendamment du CardTheme Material 3.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  type.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  priceLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _QtyStepper(
            quantity: quantity,
            showRemove: isInCart,
            onAdd: onAdd,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.showRemove,
    required this.onAdd,
    required this.onRemove,
  });

  final double quantity;
  final bool showRemove;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showRemove)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.primary,
            onPressed: onRemove,
          ),
        if (showRemove)
          SizedBox(
            width: 24,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.add_circle),
          color: AppColors.primary,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.lineCount,
    required this.estimatedTotal,
    required this.onContinue,
  });

  final int lineCount;
  final double estimatedTotal;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$lineCount article${lineCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '≈ ${CurrencyUtils.formatXAF(estimatedTotal)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: const Text('Continuer'),
            ),
          ),
        ],
      ),
    );
  }
}
