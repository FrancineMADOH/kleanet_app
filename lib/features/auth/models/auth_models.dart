// Modèles de données du module Auth.
//
// Ces classes correspondent 1:1 aux réponses JSON de l'API Fastify,
// endpoints /auth/phone/send et /auth/phone/verify. Pas de logique ici —
// juste le parsing Map<String,dynamic> → objet Dart typé.

/// Réponse de `POST /auth/phone/verify`.
/// Contient les tokens JWT à sauvegarder et deux flags utiles à l'UI :
/// `partnerId` (identifiant Odoo du client) et `isNewUser` pour décider
/// si on affiche l'écran de bienvenue ou on va directement au home.
class VerifyOtpResult {
  const VerifyOtpResult({
    required this.accessToken,
    required this.refreshToken,
    required this.partnerId,
    required this.isNewUser,
  });

  final String accessToken;
  final String refreshToken;
  final int partnerId;
  final bool isNewUser;

  factory VerifyOtpResult.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResult(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      partnerId: (json['partner_id'] as num).toInt(),
      isNewUser: json['is_new_user'] as bool,
    );
  }
}

/// Profil utilisateur renvoyé par `GET /profile/`.
/// Utilisé par le splash pour vérifier que le token stocké est toujours
/// valide (si l'appel passe → session OK). On ne mappe que les champs
/// utilisés pour l'instant — on enrichira au fil des features.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}
