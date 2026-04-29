// Catalogue centralisé de toutes les URLs de l'API Kleanet.
//
// Quand tu crées un nouveau repository qui appelle le backend, ajoute d'abord
// l'endpoint ici plutôt que d'écrire l'URL en dur dans l'appel Dio. Ça
// facilite les renommages, évite les typos, et sert de "carte" pour naviguer
// entre le Flutter et la spec OpenAPI (docs/openapi.json).

class ApiEndpoints {
  ApiEndpoints._();

  // Préfixe commun à toutes les routes — versionné pour permettre une v2
  // future sans casser les clients v1 déjà en prod.
  static const apiPrefix = '/api/v1';

  // --- Auth ---
  // Noms alignés sur l'OpenAPI Fastify (docs/openapi.json) — le backend
  // utilise "phone/send" et "phone/verify", pas "request-otp"/"verify-otp".
  static const authPhoneSend = '$apiPrefix/auth/phone/send';     // Envoie OTP SMS
  static const authPhoneVerify = '$apiPrefix/auth/phone/verify'; // Vérifie OTP + login
  static const authRefresh = '$apiPrefix/auth/refresh';          // Renouvelle access token
  static const authGoogle = '$apiPrefix/auth/google';            // OAuth Google
  static const authFacebook = '$apiPrefix/auth/facebook';        // OAuth Facebook
  static const authLogout = '$apiPrefix/auth/logout';

  // --- Profil ---
  static const profile = '$apiPrefix/profile/';
  static const profileLocation = '$apiPrefix/profile/location'; // PATCH géolocalisation

  // --- Catalogue garments + tarifs ---
  // Le contrat réel expose un endpoint unique `catalog/services` qui
  // retourne un payload combiné {garment_types, pricing_rules, cached_at}.
  // Il n'y a pas d'endpoint séparé pour les matières ni les règles de prix.
  static const catalogServices = '$apiPrefix/catalog/services';
  static const catalogPlans = '$apiPrefix/catalog/plans';

  // --- Commandes ---
  // Le slash final est exigé par la route Fastify (`/orders/`) — sans lui
  // le framework renvoie un 404.
  static const orders = '$apiPrefix/orders/';
  /// URL détail d'une commande. Ex: orderById('42') → '/api/v1/orders/42'
  static String orderById(String id) => '$apiPrefix/orders/$id';

  // --- Rendez-vous (pickup + delivery) ---
  // Endpoint séparé pour la prise de rendez-vous. POST /appointments
  // attend `type`, `scheduled_from` (ISO8601, min +2h), `order_ids`.
  static const appointments = '$apiPrefix/appointments/';

  // --- Abonnements ---
  // GET /catalog/plans         → liste des plans disponibles (public)
  // GET /subscription/         → abonnement actif du user (null si aucun)
  // POST /subscription/        → souscrire à un plan (body: {plan_id})
  static const subscription = '$apiPrefix/subscription/';

  // --- FAQ ---
  // L'API retourne une liste plate de FaqItem — le groupement par catégorie
  // est fait côté Flutter dans FaqRepository._groupByCategory().
  static const faqCategories = '$apiPrefix/faq/';
  static String faqArticle(String id) => '$apiPrefix/faq/$id';

  // --- Feedback ---
  static const feedback = '$apiPrefix/feedback';
}
