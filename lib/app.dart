import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/auth/token_storage.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'shared/theme/app_theme.dart';

class KleanetApp extends StatefulWidget {
  const KleanetApp({
    super.key,
    required this.tokenStorage,
    required this.authProvider,
    required this.apiClient,
  });

  final TokenStorage tokenStorage;
  final AuthProvider authProvider;
  final ApiClient apiClient;

  @override
  State<KleanetApp> createState() => _KleanetAppState();
}

class _KleanetAppState extends State<KleanetApp> {
  late final _router = buildAppRouter(widget.authProvider);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: widget.tokenStorage),
        Provider<ApiClient>.value(value: widget.apiClient),
        ChangeNotifierProvider<AuthProvider>.value(value: widget.authProvider),
      ],
      child: MaterialApp.router(
        title: 'Kleanet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
