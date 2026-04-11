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
  static const authRequestOtp = '$apiPrefix/auth/request-otp';  // Envoie OTP SMS
  static const authVerifyOtp = '$apiPrefix/auth/verify-otp';    // Vérifie OTP + login
  static const authRefresh = '$apiPrefix/auth/refresh';         // Renouvelle access token
  static const authGoogle = '$apiPrefix/auth/google';           // OAuth Google
  static const authFacebook = '$apiPrefix/auth/facebook';       // OAuth Facebook
  static const authLogout = '$apiPrefix/auth/logout';

  // --- Profil ---
  static const profile = '$apiPrefix/profile/';
  static const profileLocation = '$apiPrefix/profile/location'; // PATCH géolocalisation

  // --- Catalogue garments + tarifs ---
  static const catalog = '$apiPrefix/catalog';
  static const pricingRules = '$apiPrefix/catalog/pricing-rules';

  // --- Commandes ---
  static const orders = '$apiPrefix/orders';
  /// URL détail d'une commande. Ex: orderById('42') → '/api/v1/orders/42'
  static String orderById(String id) => '$apiPrefix/orders/$id';

  // --- Abonnements ---
  static const subscriptionPlans = '$apiPrefix/subscription/plans';
  static const subscriptionMine = '$apiPrefix/subscription/mine';

  // --- FAQ ---
  static const faqCategories = '$apiPrefix/faq/categories';
  static String faqArticle(String id) => '$apiPrefix/faq/$id';

  // --- Feedback ---
  static const feedback = '$apiPrefix/feedback';
}
