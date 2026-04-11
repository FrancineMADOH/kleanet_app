// Point d'entrée de l'app Kleanet.
//
// Ordre d'initialisation strict :
//   1. WidgetsFlutterBinding — requis avant tout appel async côté Flutter.
//   2. Env.load()              — charge .env.development (ou .production).
//   3. Construction des singletons : TokenStorage → AuthProvider → ApiClient.
//      L'ordre compte : ApiClient a besoin de TokenStorage, et son callback
//      onSessionExpired pointe vers AuthProvider.signOut.
//   4. bootstrap() en fire-and-forget — pendant qu'il s'exécute, le router
//      reste sur le splash (AuthStatus.unknown). Le .catchError garantit
//      qu'on ne reste jamais bloqué si le secure storage throw.
//   5. runApp() — l'UI démarre immédiatement, le splash s'auto-résout.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/auth/token_storage.dart';
import 'core/config/env.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/catalog/providers/catalog_provider.dart';
import 'features/catalog/repositories/catalog_cache.dart';
import 'features/catalog/repositories/catalog_repository.dart';

/// Entrée de l'app. Tout démarre ici — ne pas ajouter de logique métier
/// dans ce fichier, seulement du câblage d'initialisation.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  if (kDebugMode) {
    debugPrint('[Kleanet] env=${Env.envName} apiBaseUrl=${Env.apiBaseUrl}');
  }

  // Ordre de construction important : ApiClient dépend de TokenStorage,
  // AuthRepository dépend de ApiClient, AuthProvider dépend des deux.
  // Le chaînage "apiClient.onSessionExpired = authProvider.signOut" ne peut
  // se faire qu'après construction → on passe par un late final.
  late final AuthProvider authProvider;
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onSessionExpired: () => authProvider.signOut(),
  );
  final authRepository = AuthRepository(apiClient: apiClient);
  authProvider = AuthProvider(
    tokenStorage: tokenStorage,
    authRepository: authRepository,
  );

  // Catalogue public (no auth) — peut se charger en parallèle du bootstrap
  // auth. Gain : au moment où l'utilisateur arrive sur /home, les données
  // sont déjà là (ou au moins le cache).
  final catalogRepository = CatalogRepository(apiClient: apiClient);
  final catalogCache = CatalogCache();
  final catalogProvider = CatalogProvider(
    repository: catalogRepository,
    cache: catalogCache,
  );

  unawaited(
    authProvider.bootstrap().catchError((Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('[Kleanet] bootstrap failed: $error\n$stack');
      }
      return authProvider.signOut();
    }),
  );

  // Preload catalog en fire-and-forget — les erreurs métier sont déjà
  // capturées dans le provider (errorMessage). Le catchError ici est un
  // garde-fou pour toute exception inattendue qui remonterait au zone.
  unawaited(
    catalogProvider.load().catchError((Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('[Kleanet] catalog preload failed: $error');
      }
    }),
  );

  runApp(KleanetApp(
    tokenStorage: tokenStorage,
    authProvider: authProvider,
    apiClient: apiClient,
    catalogProvider: catalogProvider,
  ));
}
