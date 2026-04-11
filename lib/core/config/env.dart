// Accès aux variables d'environnement chargées par flutter_dotenv.
//
// Les fichiers .env sont dans assets/env/ et sont déclarés comme assets
// dans pubspec.yaml. L'app charge .env.development par défaut au démarrage
// (voir main.dart) ; en build release on passera `production: true` pour
// charger .env.production.

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  // Chemins relatifs aux assets déclarés dans pubspec.yaml.
  static const _devFile = 'assets/env/.env.development';
  static const _prodFile = 'assets/env/.env.production';

  /// Charge le bon fichier .env en mémoire. À appeler une seule fois,
  /// avant `runApp()`, après `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<void> load({bool production = false}) async {
    await dotenv.load(fileName: production ? _prodFile : _devFile);
  }

  /// URL de base de l'API Fastify. En dev sur émulateur Android,
  /// c'est `http://10.0.2.2:3000` (10.0.2.2 est l'alias de localhost
  /// côté hôte). En prod, c'est l'URL publique du backend.
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';

  /// Nom de l'environnement courant (`development` ou `production`).
  /// Utile pour afficher un badge de debug, filtrer des logs, etc.
  static String get envName => dotenv.env['ENV_NAME'] ?? 'unknown';
}
