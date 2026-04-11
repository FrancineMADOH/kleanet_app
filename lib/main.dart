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

/// Entrée de l'app. Tout démarre ici — ne pas ajouter de logique métier
/// dans ce fichier, seulement du câblage d'initialisation.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  if (kDebugMode) {
    debugPrint('[Kleanet] env=${Env.envName} apiBaseUrl=${Env.apiBaseUrl}');
  }

  final tokenStorage = TokenStorage();
  final authProvider = AuthProvider(tokenStorage: tokenStorage);
  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onSessionExpired: authProvider.signOut,
  );

  unawaited(
    authProvider.bootstrap().catchError((Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('[Kleanet] bootstrap failed: $error\n$stack');
      }
      return authProvider.signOut();
    }),
  );

  runApp(KleanetApp(
    tokenStorage: tokenStorage,
    authProvider: authProvider,
    apiClient: apiClient,
  ));
}
