import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  if (kDebugMode) {
    debugPrint('[Kleanet] env=${Env.envName} apiBaseUrl=${Env.apiBaseUrl}');
  }
  runApp(const KleanetApp());
}
