// Racine du widget tree de l'app.
//
// Ce fichier a UN seul rôle : câbler ensemble les services construits dans
// main.dart (TokenStorage, ApiClient, AuthProvider, CatalogProvider) via
// MultiProvider, puis monter MaterialApp.router avec le GoRouter. Aucune
// logique métier ici.
//
// C'est un StatefulWidget parce que le GoRouter doit être instancié UNE
// seule fois — si on le recréait à chaque build(), on perdrait l'état de
// navigation à chaque notifyListeners() de AuthProvider.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/auth/token_storage.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/catalog/providers/catalog_provider.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/orders/providers/order_draft_provider.dart';
import 'features/orders/providers/orders_list_provider.dart';
import 'features/orders/repositories/order_repository.dart';
import 'features/subscription/providers/subscription_provider.dart';
import 'shared/theme/app_theme.dart';

/// Widget racine. Reçoit les singletons déjà construits depuis main.dart
/// via `.value` providers — ça évite de recréer les services à chaque
/// rebuild et facilite l'injection dans les tests widget.
class KleanetApp extends StatefulWidget {
  const KleanetApp({
    super.key,
    required this.tokenStorage,
    required this.authProvider,
    required this.apiClient,
    required this.catalogProvider,
    required this.orderDraftProvider,
    required this.orderRepository,
    required this.ordersListProvider,
    required this.subscriptionProvider,
    required this.notificationProvider,
    required this.router,
  });

  final TokenStorage tokenStorage;
  final AuthProvider authProvider;
  final ApiClient apiClient;
  final CatalogProvider catalogProvider;
  final OrderDraftProvider orderDraftProvider;
  final OrderRepository orderRepository;
  final OrdersListProvider ordersListProvider;
  final SubscriptionProvider subscriptionProvider;
  final NotificationProvider notificationProvider;
  // Le router est construit dans main.dart pour que NotificationService
  // puisse y accéder avant runApp (navigation sur tap cold-start).
  final GoRouter router;

  @override
  State<KleanetApp> createState() => _KleanetAppState();
}

class _KleanetAppState extends State<KleanetApp> {

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: widget.tokenStorage),
        Provider<ApiClient>.value(value: widget.apiClient),
        Provider<OrderRepository>.value(value: widget.orderRepository),
        ChangeNotifierProvider<AuthProvider>.value(value: widget.authProvider),
        ChangeNotifierProvider<CatalogProvider>.value(
          value: widget.catalogProvider,
        ),
        ChangeNotifierProvider<OrderDraftProvider>.value(
          value: widget.orderDraftProvider,
        ),
        ChangeNotifierProvider<OrdersListProvider>.value(
          value: widget.ordersListProvider,
        ),
        ChangeNotifierProvider<SubscriptionProvider>.value(
          value: widget.subscriptionProvider,
        ),
        ChangeNotifierProvider<NotificationProvider>.value(
          value: widget.notificationProvider,
        ),
      ],
      child: MaterialApp.router(
        title: 'Kleanet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: widget.router,
      ),
    );
  }
}
