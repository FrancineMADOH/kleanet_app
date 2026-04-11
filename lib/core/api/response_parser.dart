// Helper partagé pour convertir une réponse JSON en modèle Dart typé.
//
// Raison d'être : tous les repositories ont le même besoin — prendre un
// `Map<String, dynamic>?` retourné par Dio et le passer à un `.fromJson`
// sans laisser un TypeError/NullCheckError remonter jusqu'à l'UI. Cette
// fonction encapsule ce pattern une bonne fois pour toutes : si le JSON
// est null ou si le parser échoue (TypeError, cast, champ manquant),
// on lève une `ApiException(BAD_RESPONSE)` que les couches supérieures
// savent déjà gérer (message lisible, pas de crash).

import 'api_exception.dart';

/// Convertit `data` en `T` via `parser`, ou lève `ApiException(BAD_RESPONSE)`
/// si `data` est null ou si le parser throw quoi que ce soit.
///
/// - [data] : payload brut retourné par Dio (`response.data`).
/// - [parser] : factory `T.fromJson` du modèle cible.
/// - [label] : libellé court utilisé dans le message d'erreur pour
///   identifier l'endpoint ("verify response", "catalog", …).
T parseOrThrow<T>(
  Map<String, dynamic>? data,
  T Function(Map<String, dynamic>) parser,
  String label,
) {
  if (data == null) {
    throw ApiException(
      statusCode: 0,
      code: 'BAD_RESPONSE',
      message: 'Réponse serveur invalide ($label).',
    );
  }
  try {
    return parser(data);
  } catch (_) {
    throw ApiException(
      statusCode: 0,
      code: 'BAD_RESPONSE',
      message: 'Réponse serveur invalide ($label).',
    );
  }
}
