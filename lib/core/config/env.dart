import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static const _devFile = 'assets/env/.env.development';
  static const _prodFile = 'assets/env/.env.production';

  static Future<void> load({bool production = false}) async {
    await dotenv.load(fileName: production ? _prodFile : _devFile);
  }

  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static String get envName => dotenv.env['ENV_NAME'] ?? 'unknown';
}
