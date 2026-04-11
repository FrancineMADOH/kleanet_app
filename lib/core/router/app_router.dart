// Routeur GoRouter central de l'app Kleanet.
//
// Deux choses à retenir :
//   1. Le routeur écoute AuthProvider (refreshListenable) : toute bascule
//      de AuthStatus ré-exécute la fonction redirect ci-dessous.
//   2. La logique de redirect est exhaustive — elle couvre les 3 statuts
//      × les routes splash/auth/protégées. C'est ici que se joue le
//      "qui a le droit d'aller où" de l'app.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/phone_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/orders/models/order_models.dart';
import '../../features/orders/screens/new_order_garments_screen.dart';
import '../../features/orders/screens/new_order_pickup_screen.dart';
import '../../features/orders/screens/new_order_summary_screen.dart';
import '../../features/orders/screens/order_confirmed_screen.dart';

/// Catalogue centralisé des chemins de route. Les chemins littéraux ne
/// devraient jamais apparaître ailleurs dans l'app — toujours passer par
/// une constante ici pour faciliter les renommages.
class Routes {
  Routes._();

  static const splash = '/splash';
  static const auth = '/auth';
  static const authPhone = '/auth/phone';
  static const authOtp = '/auth/otp';
  static const home = '/home';

  // Flux "Nouvelle commande" — 4 étapes, sous-routes sous /order/new.
  // Le brouillon est partagé via OrderDraftProvider injecté au-dessus.
  static const newOrder = '/order/new';
  static const newOrderPickup = '/order/new/pickup';
  static const newOrderSummary = '/order/new/summary';
  static const newOrderDone = '/order/new/done';

  /// Pattern GoRoute (avec placeholder `:id`) — utilisé côté déclaration.
  static const orderDetailPattern = '/order/:id';

  /// Construit une URL concrète vers le détail d'une commande.
  /// Ex: `orderDetail('42')` → `/order/42`. À utiliser côté navigation.
  static String orderDetail(String id) => '/order/$id';
}

/// Builds the app's [GoRouter] bound to [authProvider] for auth-driven
/// redirects. Unauthenticated users are bounced to [Routes.auth], authenticated
/// users are bounced out of splash/auth onto [Routes.home]. The `unknown`
/// status (before bootstrap completes) is pinned on the splash screen.
GoRouter buildAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: authProvider,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final status = authProvider.status;
      final location = state.matchedLocation;
      final isSplash = location == Routes.splash;
      final isAuthRoute =
          location == Routes.auth || location.startsWith('${Routes.auth}/');

      if (status == AuthStatus.unknown) {
        return isSplash ? null : Routes.splash;
      }
      if (isSplash) {
        return status == AuthStatus.authenticated ? Routes.home : Routes.auth;
      }
      if (status == AuthStatus.authenticated && isAuthRoute) {
        return Routes.home;
      }
      if (status == AuthStatus.unauthenticated && !isAuthRoute) {
        return Routes.auth;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.auth,
        builder: (_, __) => const AuthScreen(),
        routes: [
          // Sous-routes : /auth/phone et /auth/otp — elles partagent le
          // même statut "non authentifié" et le même AuthProvider.
          GoRoute(
            path: 'phone',
            builder: (_, __) => const PhoneScreen(),
          ),
          GoRoute(
            path: 'otp',
            builder: (_, __) => const OtpScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      // Flux Nouvelle commande — déclaré en routes "plates" (pas de
      // sous-routes imbriquées) pour que chaque écran puisse utiliser
      // context.go() directement sans gérer de stack parent.
      GoRoute(
        path: Routes.newOrder,
        builder: (_, __) => const NewOrderGarmentsScreen(),
      ),
      GoRoute(
        path: Routes.newOrderPickup,
        builder: (_, __) => const NewOrderPickupScreen(),
      ),
      GoRoute(
        path: Routes.newOrderSummary,
        builder: (_, __) => const NewOrderSummaryScreen(),
      ),
      GoRoute(
        path: Routes.newOrderDone,
        // L'Order complet est passé en `extra`. Si quelqu'un navigue
        // ici directement (deep link, back/forward), extra est null →
        // le redirect ci-dessous renvoie sur /home.
        redirect: (_, state) =>
            state.extra is Order ? null : Routes.home,
        builder: (_, state) =>
            OrderConfirmedScreen(order: state.extra as Order),
      ),
      GoRoute(
        path: Routes.orderDetailPattern,
        builder: (_, state) => _StubScreen(
          title: 'Commande ${state.pathParameters['id']}',
          hint: 'Détail commande — TRACKING-01',
        ),
      ),
    ],
  );
}

class _StubScreen extends StatelessWidget {
  const _StubScreen({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
