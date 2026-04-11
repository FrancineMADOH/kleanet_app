import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/auth/token_storage.dart';
import 'core/config/env.dart';
import 'features/auth/providers/auth_provider.dart';

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
