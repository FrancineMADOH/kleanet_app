// Écran de confirmation de commande.
//
// Reçoit l'Order créé via `extra` de GoRouter. Affiche un visuel
// "succès" + la référence + un bouton "Retour à l'accueil". Au moment
// où l'utilisateur sort de cet écran, on reset le brouillon pour que
// le flux suivant démarre propre.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/currency_utils.dart';
import '../models/order_models.dart';
import '../providers/order_draft_provider.dart';

class OrderConfirmedScreen extends StatelessWidget {
  const OrderConfirmedScreen({super.key, required this.order});

  final Order order;

  void _backHome(BuildContext context) {
    context.read<OrderDraftProvider>().reset();
    context.go(Routes.home);
  }

  void _viewDetail(BuildContext context) {
    // On reset le brouillon avant de partir sur le détail pour que si
    // l'utilisateur revient en arrière via le système, il ne retombe
    // pas dans l'écran récap avec l'ancien brouillon encore présent.
    context.read<OrderDraftProvider>().reset();
    context.go(Routes.orderDetail(order.id.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Back Android → même comportement que le bouton : home + reset.
        if (!didPop) _backHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Commande confirmée'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(
                  Icons.check_circle,
                  size: 96,
                  color: AppColors.success,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Commande confirmée !',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Référence : ${order.reference}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _Row(
                          label: 'Statut',
                          value: order.status.label,
                        ),
                        const SizedBox(height: 8),
                        _Row(
                          label: 'Total',
                          value: CurrencyUtils.formatXAF(order.amountTotal),
                        ),
                        const SizedBox(height: 8),
                        _Row(
                          label: 'Articles',
                          value: '${order.totalPieces}',
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _viewDetail(context),
                    child: const Text('Voir le détail'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _backHome(context),
                    child: const Text('Retour à l\'accueil'),
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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      );
}
