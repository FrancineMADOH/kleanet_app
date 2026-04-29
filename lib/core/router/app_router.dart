// Routeur GoRouter central de l'app Kleanet.
//
// Deux choses à retenir :
//   1. Le routeur écoute AuthProvider (refreshListenable) : toute bascule
//      de AuthStatus ré-exécute la fonction redirect ci-dessous.
//   2. La logique de redirect est exhaustive — elle couvre les 3 statuts
//      × les routes splash/auth/protégées. C'est ici que se joue le
//      "qui a le droit d'aller où" de l'app.

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/phone_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/orders/models/order_models.dart';
import '../../features/orders/providers/order_detail_provider.dart';
import '../../features/orders/repositories/order_repository.dart';
import '../../features/orders/providers/orders_list_provider.dart';
import '../../features/orders/screens/new_order_garments_screen.dart';
import '../../features/orders/screens/new_order_pickup_screen.dart';
import '../../features/orders/screens/new_order_summary_screen.dart';
import '../../features/orders/screens/order_confirmed_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/screens/orders_list_screen.dart';
import '../../features/appointments/providers/appointments_provider.dart';
import '../../features/appointments/repositories/appointment_repository.dart';
import '../../features/appointments/screens/appointments_screen.dart';
import '../../features/faq/models/faq_models.dart';
import '../../features/faq/providers/faq_provider.dart';
import '../../features/faq/repositories/faq_repository.dart';
import '../../features/faq/screens/faq_article_screen.dart';
import '../../features/faq/screens/faq_categories_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/subscription/screens/subscription_hub_screen.dart';

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

  // Liste des commandes de l'utilisateur.
  static const orders = '/orders';

  // Abonnement — hub uniquement. Plans et confirmation sont gérés en sous-navigation
  // inline dans HomeScreen (onglet 2) — pas de routes GoRouter dédiées.
  static const subscription = '/subscription';

  // Profil — édition et liste des rendez-vous (routes pushées depuis l'onglet 3).
  static const profileEdit = '/profile/edit';
  static const profileAppointments = '/profile/appointments';

  // FAQ — accessible sans authentification.
  static const faq = '/faq';
  static String faqArticle(String id) => '/faq/$id';
  // Pattern GoRoute (avec placeholder :id) — utilisé côté déclaration.
  static const faqArticlePattern = '/faq/:id';

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
      // La FAQ est accessible sans authentification.
      final isFaqRoute =
          location == Routes.faq || location.startsWith('${Routes.faq}/');
      if (status == AuthStatus.unauthenticated && !isAuthRoute && !isFaqRoute) {
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
      // Liste des commandes — provider factory scoped à cet écran.
      GoRoute(
        path: Routes.orders,
        builder: (context, _) => ChangeNotifierProvider(
          create: (ctx) => OrdersListProvider(
            repository: ctx.read<OrderRepository>(),
          ),
          child: const OrdersListScreen(),
        ),
      ),
      // Abonnement — route hub uniquement (deep-link + fallback).
      // Plans et confirmation sont intégrés dans l'onglet 2 de HomeScreen
      // (sous-navigation inline) — ils n'ont plus de route GoRouter propre.
      GoRoute(
        path: Routes.subscription,
        builder: (_, __) => const SubscriptionHubScreen(),
      ),
      // Édition du profil — pushée depuis l'onglet Profil.
      GoRoute(
        path: Routes.profileEdit,
        builder: (_, __) => const EditProfileScreen(),
      ),
      // Rendez-vous — AppointmentsProvider factory-scopé à cet écran pour
      // éviter de le monter au niveau app alors qu'il n'est utilisé que ici.
      GoRoute(
        path: Routes.profileAppointments,
        builder: (context, _) => ChangeNotifierProvider(
          create: (ctx) => AppointmentsProvider(
            repository: AppointmentRepository(
              apiClient: ctx.read<ApiClient>(),
            ),
          ),
          child: const AppointmentsScreen(),
        ),
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
      // FAQ — accessible sans authentification (voir guard ci-dessus).
      // FaqProvider factory-scopé sur /faq pour éviter de le monter
      // au niveau racine alors qu'il n'est utilisé que depuis cet écran.
      GoRoute(
        path: Routes.faq,
        builder: (context, _) => ChangeNotifierProvider(
          create: (ctx) => FaqProvider(
            repository: FaqRepository(apiClient: ctx.read<ApiClient>()),
          ),
          child: const FaqCategoriesScreen(),
        ),
      ),
      // Article FAQ — l'article complet est passé via `extra` depuis
      // FaqCategoriesScreen. Si extra est null (deep link direct), on
      // renvoie sur /faq pour forcer le chargement des catégories d'abord.
      GoRoute(
        path: Routes.faqArticlePattern,
        redirect: (_, state) =>
            state.extra is FaqArticle ? null : Routes.faq,
        builder: (_, state) =>
            FaqArticleScreen(article: state.extra as FaqArticle),
      ),
      GoRoute(
        path: Routes.orderDetailPattern,
        // Provider factory : on instancie un OrderDetailProvider dédié
        // à cette route (scoped à l'écran). Le repository est résolu
        // via context.read<OrderRepository>() injecté au niveau racine.
        // Si l'id n'est pas un entier valide, on renvoie sur /home.
        redirect: (_, state) {
          final raw = state.pathParameters['id'];
          final id = int.tryParse(raw ?? '');
          return id == null ? Routes.home : null;
        },
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ChangeNotifierProvider<OrderDetailProvider>(
            create: (ctx) => OrderDetailProvider(
              repository: ctx.read<OrderRepository>(),
              orderId: id,
            ),
            child: const OrderDetailScreen(),
          );
        },
      ),
    ],
  );
}
