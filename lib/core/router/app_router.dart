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
import '../../features/auth/screens/splash_screen.dart';

/// Catalogue centralisé des chemins de route. Les chemins littéraux ne
/// devraient jamais apparaître ailleurs dans l'app — toujours passer par
/// une constante ici pour faciliter les renommages.
class Routes {
  Routes._();

  static const splash = '/splash';
  static const auth = '/auth';
  static const home = '/home';

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
        builder: (_, __) => const _StubScreen(
          title: 'Auth',
          hint: 'Flux OTP — AUTH-01',
        ),
      ),
      GoRoute(
        path: Routes.home,
        builder: (_, __) => const _StubScreen(
          title: 'Accueil',
          hint: 'Home shell — à venir',
        ),
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
