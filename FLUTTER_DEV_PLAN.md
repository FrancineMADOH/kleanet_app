# Kleanet Flutter — Plan de développement
## kleanet_app · Flutter · Provider · Dio

*Document de specifications — 2026-03-28*
*Base : MOBILE_SCREENS.md · MOBILE_USER_JOURNEY.md · API_DEV_PLAN.md*

---

## Conventions

- **Priorite** : P0 (bloquant) · P1 (important) · P2 (utile) · P3 (nice-to-have)
- **Effort** : S (< 2h) · M (2-8h) · L (1-3 jours) · XL (> 3 jours)
- **Fichiers** : chemins dans `kleanet_app/lib/`
- **Ordre de developpement** : chaque etape depend de la precedente — ne pas sauter
- **Regle d'or** : ne passe jamais a l'etape suivante si le critere de passage n'est pas rempli
- **Prérequis** : l'API Fastify tourne en local (`http://localhost:3000`) avant de commencer l'étape AUTH

---

## Table des matières

1. [FOUNDATION — Fondations](#1-foundation)
2. [AUTH — Authentification](#2-auth)
3. [CATALOG — Catalogue vêtements](#3-catalog)
4. [ORDER — Flux de commande](#4-order)
5. [TRACKING — Suivi commande](#5-tracking)
6. [ORDERS — Mes commandes](#6-orders)
7. [SUBSCRIPTION — Abonnement](#7-subscription)
8. [PROFILE — Profil & Localisation](#8-profile)
9. [SUPPORT — FAQ & Feedback](#9-support)
10. [NOTIFICATIONS — Push FCM](#10-notifications)
11. [QUALITY — Tests & Release](#11-quality)

---

## Note : OpenAPI → Dart (code generation)

> Avant de coder le client API manuellement, tu peux **générer automatiquement** les modèles Dart et les méthodes API depuis le schéma OpenAPI de Fastify.

### Comment ça marche

1. **Exporter le schéma** depuis Fastify (déjà configuré dans FOUNDATION-02 de l'API) :
   ```
   GET http://localhost:3000/docs/json  → OpenAPI JSON
   ```
   Sauvegarder sous `kleanet_app/openapi/kleanet_api.yaml` (convertir avec un outil en ligne si besoin).

2. **Ajouter le générateur** dans `pubspec.yaml` :
   ```yaml
   dev_dependencies:
     openapi_generator_annotations: ^5.0.1
     openapi_generator: ^5.0.1
     build_runner: ^2.4.8
   ```

3. **Configurer** dans `kleanet_app/openapi_generator_config.dart` :
   ```dart
   @AdditionalProperties(pubName: 'kleanet_api_client', pubAuthor: 'Kleanet')
   @Openapi(
     inputSpecFile: 'openapi/kleanet_api.yaml',
     generatorName: Generator.dio,
     outputDirectory: 'lib/core/api/generated',
   )
   ```

4. **Générer** :
   ```bash
   flutter pub run build_runner build
   ```

### Ce que ça génère
- `lib/core/api/generated/lib/api/` — une classe par tag Swagger (`AuthApi`, `OrdersApi`, `SubscriptionApi`…)
- `lib/core/api/generated/lib/model/` — tous les modèles Dart avec `fromJson`/`toJson`
- Le client Dio configuré automatiquement

### Recommendation pour ce projet
**Utilise la génération de code.** Avantages :
- Modèles toujours synchronisés avec l'API (re-générer après chaque changement de schéma)
- Zéro erreur de sérialisation manuelle
- Gain de temps significatif

**Workflow** : à chaque modification de l'API → re-exporter le YAML → re-générer → les erreurs de compilation signalent les breaking changes.

---

## Stack technique

### Dépendances `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  provider: ^6.1.2

  # Navigation
  go_router: ^14.2.0

  # HTTP + API
  dio: ^5.4.3

  # Stockage sécurisé (tokens JWT)
  flutter_secure_storage: ^9.2.2

  # Préférences simples (premier lancement, flags)
  shared_preferences: ^2.2.3

  # Auth sociale
  google_sign_in: ^6.2.1
  flutter_facebook_auth: ^7.0.3

  # Localisation GPS
  geolocator: ^12.0.0
  permission_handler: ^11.3.1

  # Carte statique (OpenStreetMap, gratuit)
  flutter_map: ^7.0.2
  latlong2: ^0.9.1

  # Notifications push
  firebase_messaging: ^15.1.1
  firebase_core: ^3.3.0

  # QR Code
  qr_flutter: ^4.1.0

  # UI utilitaires
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0          # skeleton loading
  intl: ^0.19.0             # formatage dates et montants XAF

  # Variables d'environnement
  flutter_dotenv: ^5.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.8
  # Si tu utilises la génération OpenAPI :
  openapi_generator_annotations: ^5.0.1
  openapi_generator: ^5.0.1
```

### Architecture de dossiers

```
kleanet_app/
├── lib/
│   ├── main.dart                    # bootstrap + dotenv + Firebase
│   ├── app.dart                     # MaterialApp.router + MultiProvider
│   │
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart      # instance Dio + intercepteurs JWT
│   │   │   ├── api_endpoints.dart   # constantes URL
│   │   │   ├── api_exception.dart   # types d'erreur (ApiException)
│   │   │   └── generated/           # ← si génération OpenAPI
│   │   ├── auth/
│   │   │   └── token_storage.dart   # wrapper SecureStorage
│   │   ├── config/
│   │   │   └── env.dart             # wrapper dotenv
│   │   └── router/
│   │       └── app_router.dart      # GoRouter + guards auth
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── models/auth_models.dart
│   │   │   ├── providers/auth_provider.dart
│   │   │   ├── repositories/auth_repository.dart
│   │   │   └── screens/
│   │   │       ├── splash_screen.dart
│   │   │       ├── onboarding_screen.dart
│   │   │       ├── auth_screen.dart
│   │   │       ├── phone_screen.dart
│   │   │       ├── otp_screen.dart
│   │   │       └── welcome_screen.dart
│   │   ├── catalog/
│   │   │   ├── models/catalog_models.dart
│   │   │   ├── providers/catalog_provider.dart
│   │   │   └── repositories/catalog_repository.dart
│   │   ├── orders/
│   │   │   ├── models/order_models.dart
│   │   │   ├── providers/
│   │   │   │   ├── order_provider.dart        # liste commandes
│   │   │   │   └── new_order_provider.dart    # état du flux 3 étapes
│   │   │   ├── repositories/order_repository.dart
│   │   │   └── screens/
│   │   │       ├── orders_list_screen.dart
│   │   │       ├── order_detail_screen.dart
│   │   │       ├── order_confirmed_screen.dart
│   │   │       └── new_order/
│   │   │           ├── step1_garments_screen.dart
│   │   │           ├── step2_pickup_screen.dart
│   │   │           └── step3_summary_screen.dart
│   │   ├── subscription/
│   │   │   ├── models/subscription_models.dart
│   │   │   ├── providers/subscription_provider.dart
│   │   │   ├── repositories/subscription_repository.dart
│   │   │   └── screens/
│   │   │       ├── subscription_hub_screen.dart
│   │   │       ├── plans_screen.dart
│   │   │       └── subscribe_confirm_screen.dart
│   │   ├── profile/
│   │   │   ├── models/profile_models.dart
│   │   │   ├── providers/profile_provider.dart
│   │   │   ├── repositories/profile_repository.dart
│   │   │   └── screens/
│   │   │       ├── profile_screen.dart
│   │   │       ├── edit_profile_screen.dart
│   │   │       └── appointments_screen.dart
│   │   ├── faq/
│   │   │   ├── models/faq_models.dart
│   │   │   ├── providers/faq_provider.dart
│   │   │   ├── repositories/faq_repository.dart
│   │   │   └── screens/
│   │   │       ├── faq_categories_screen.dart
│   │   │       └── faq_article_screen.dart
│   │   ├── feedback/
│   │   │   ├── models/feedback_models.dart
│   │   │   ├── providers/feedback_provider.dart
│   │   │   ├── repositories/feedback_repository.dart
│   │   │   └── screens/
│   │   │       ├── feedback_form_screen.dart
│   │   │       └── feedback_success_screen.dart
│   │   └── notifications/
│   │       ├── models/notification_models.dart
│   │       ├── providers/notification_provider.dart
│   │       └── screens/notifications_screen.dart
│   │
│   └── shared/
│       ├── widgets/
│       │   ├── kleanet_app_bar.dart
│       │   ├── order_status_badge.dart
│       │   ├── order_card.dart
│       │   ├── loading_skeleton.dart
│       │   ├── error_screen.dart
│       │   └── empty_state.dart
│       ├── theme/
│       │   ├── app_colors.dart       # palette Kleanet
│       │   ├── app_text_styles.dart
│       │   └── app_theme.dart        # ThemeData
│       └── utils/
│           ├── phone_utils.dart      # normalisation +237
│           ├── currency_utils.dart   # formatage XAF
│           └── date_utils.dart
│
├── assets/
│   ├── images/                       # logo, illustrations onboarding
│   ├── fonts/                        # Inter (Google Fonts ou local)
│   └── env/
│       ├── .env.development
│       └── .env.production
├── openapi/
│   └── kleanet_api.yaml              # schéma OpenAPI exporté depuis Fastify
└── test/
```

### Pattern Provider — règle d'usage

```
Repository  →  appels API bruts (Dio), retourne des modèles
Provider    →  état de l'UI, appelle le Repository, notifie les widgets
Screen      →  lit le Provider via context.watch<>() ou Consumer<>()
```

---

# 1. Foundation

## FOUNDATION-01 — Initialisation du projet Flutter
**Priorite** : P0 | **Effort** : M

**Description** : Créer le projet Flutter avec la structure de dossiers, configurer l'environnement, le thème Kleanet et le routeur.

**Fichiers a créer** :
```
kleanet_app/
├── lib/main.dart
├── lib/app.dart
├── lib/core/config/env.dart
├── lib/core/router/app_router.dart
├── lib/shared/theme/app_colors.dart
├── lib/shared/theme/app_text_styles.dart
├── lib/shared/theme/app_theme.dart
├── assets/env/.env.development
├── assets/env/.env.production
└── pubspec.yaml
```

**Palette Kleanet** (`app_colors.dart`) :
```dart
class AppColors {
  static const primary    = Color(0xFF1E3A5F); // Bleu nuit
  static const accent1    = Color(0xFF06B6D4); // Cyan
  static const accent2    = Color(0xFF4F46E5); // Violet
  static const success    = Color(0xFF10B981);
  static const warning    = Color(0xFFF59E0B);
  static const error      = Color(0xFFEF4444);
  static const background = Color(0xFFFFFFFF);
  static const surface    = Color(0xFFF8FAFC);
  static const textPrimary   = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
}
```

**Variables d'environnement** (`.env.development`) :
```
API_BASE_URL=http://10.0.2.2:3000   # émulateur Android → localhost
# API_BASE_URL=http://localhost:3000  # décommenter pour iOS simulateur
```

**Critères d'acceptation** :
- [ ] `flutter run` démarre sans erreur sur Android et iOS
- [ ] L'écran par défaut affiche le logo Kleanet sur fond dégradé `#1E3A5F → #06B6D4`
- [ ] `flutter analyze` retourne 0 erreur, 0 warning
- [ ] La palette de couleurs est accessible via `Theme.of(context).colorScheme`
- [ ] `flutter_dotenv` charge `.env.development` au démarrage (log `API_BASE_URL` visible)
- [ ] La police Inter est chargée (via `google_fonts` ou assets locaux)

---

## FOUNDATION-02 — Client Dio + intercepteur JWT
**Priorite** : P0 | **Effort** : L

**Description** : Configurer Dio avec l'intercepteur d'authentification JWT. C'est le module le plus critique : toutes les requêtes API passent par ce client. L'intercepteur gère automatiquement le rafraîchissement du token sans que les screens le voient.

**Fichiers a créer** :
```
lib/core/api/
├── api_client.dart        # instance Dio singleton + intercepteurs
├── api_endpoints.dart     # constantes URL
└── api_exception.dart     # ApiException avec code + message
lib/core/auth/
└── token_storage.dart     # wrapper flutter_secure_storage
```

**Logique de l'intercepteur** (`api_client.dart`) :
```
onRequest  → injecter le header Authorization: Bearer <access_token>
onError    → si 401 :
               1. Lire le refresh_token depuis SecureStorage
               2. POST /api/v1/auth/refresh
               3. Sauvegarder les nouveaux tokens
               4. Rejouer la requête originale
               5. Si refresh échoue → effacer les tokens → émettre un événement "session expirée"
```

**Types d'erreur** (`api_exception.dart`) :
```dart
class ApiException implements Exception {
  final int statusCode;
  final String code;    // ex: "ORDER_NOT_FOUND", "TOO_SOON"
  final String message;
}
```

**Critères d'acceptation** :
- [ ] `GET /api/v1/catalog` (route publique) retourne des données sans token
- [ ] `GET /api/v1/profile` sans token → `ApiException(401)`
- [ ] `GET /api/v1/profile` avec access_token valide → données du profil
- [ ] Simuler un access_token expiré → l'intercepteur rafraîchit silencieusement et renvoie la réponse
- [ ] Simuler un refresh_token expiré → les tokens sont effacés et une exception est levée
- [ ] Une erreur réseau (Odoo coupé) → `ApiException` avec message lisible, pas un crash

---

## FOUNDATION-03 — GoRouter + guards + MultiProvider
**Priorite** : P0 | **Effort** : M

**Description** : Configurer le routeur déclaratif et l'injection de tous les providers. Le guard redirige automatiquement vers `/auth` si l'utilisateur n'est pas connecté.

**Fichiers a créer** :
```
lib/core/router/app_router.dart
lib/app.dart
```

**Routes principales** :
```dart
/splash            → SplashScreen
/onboarding        → OnboardingScreen
/auth              → AuthScreen
/auth/phone        → PhoneScreen
/auth/otp          → OtpScreen
/auth/welcome      → WelcomeScreen
/home              → HomeScreen (ScaffoldWithNavBar)
  /orders          → OrdersListScreen
  /subscription    → SubscriptionHubScreen
  /profile         → ProfileScreen
/order/new         → NewOrderModal (étapes 1→2→3)
/order/:id         → OrderDetailScreen
/order/confirmed   → OrderConfirmedScreen
/subscription/plans    → PlansScreen
/subscription/confirm  → SubscribeConfirmScreen
/profile/edit      → EditProfileScreen
/profile/appointments  → AppointmentsScreen
/profile/feedbacks → FeedbacksScreen
/faq               → FaqCategoriesScreen
/faq/:id           → FaqArticleScreen
/feedback/:orderId → FeedbackFormScreen
/feedback/success  → FeedbackSuccessScreen
/notifications     → NotificationsScreen
```

**Guard auth** :
```dart
redirect: (context, state) {
  final isAuthenticated = context.read<AuthProvider>().isAuthenticated;
  final isAuthRoute = state.matchedLocation.startsWith('/auth')
                   || state.matchedLocation == '/splash'
                   || state.matchedLocation == '/onboarding';
  if (!isAuthenticated && !isAuthRoute) return '/auth';
  if (isAuthenticated && isAuthRoute) return '/home';
  return null;
}
```

**MultiProvider** (`app.dart`) :
```dart
MultiProvider(providers: [
  ChangeNotifierProvider(create: (_) => AuthProvider(authRepo)),
  ChangeNotifierProvider(create: (_) => CatalogProvider(catalogRepo)),
  ChangeNotifierProvider(create: (_) => OrderProvider(orderRepo)),
  ChangeNotifierProvider(create: (_) => NewOrderProvider(catalogRepo)),
  ChangeNotifierProvider(create: (_) => SubscriptionProvider(subRepo)),
  ChangeNotifierProvider(create: (_) => ProfileProvider(profileRepo)),
  ChangeNotifierProvider(create: (_) => FaqProvider(faqRepo)),
  ChangeNotifierProvider(create: (_) => FeedbackProvider(feedbackRepo)),
  ChangeNotifierProvider(create: (_) => NotificationProvider()),
])
```

**Critères d'acceptation** :
- [ ] Naviguer vers `/home` sans token → redirigé vers `/auth` automatiquement
- [ ] Naviguer vers `/auth` avec token valide → redirigé vers `/home`
- [ ] Deep link `/order/42` avec token → ouvre directement le détail commande
- [ ] `flutter analyze` sur `app_router.dart` : 0 erreur
- [ ] Tous les providers sont accessibles depuis n'importe quel widget via `context.read<>()`

---

# 2. Auth

## AUTH-01 — Splash + Onboarding + OTP téléphone
**Priorite** : P0 | **Effort** : L

**Description** : Implémenter le flux complet d'authentification par téléphone : splash → (onboarding au 1er lancement) → saisie numéro → OTP → home.

**Fichiers a créer** :
```
lib/features/auth/
├── models/auth_models.dart
├── providers/auth_provider.dart
├── repositories/auth_repository.dart
└── screens/
    ├── splash_screen.dart
    ├── onboarding_screen.dart
    ├── auth_screen.dart
    ├── phone_screen.dart
    ├── otp_screen.dart
    └── welcome_screen.dart
```

**AuthProvider — état** :
```dart
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  String? userName;

  Future<void> checkSession()       // appelé au splash
  Future<void> requestOtp(String phone)
  Future<void> verifyOtp(String phone, String code)
  Future<void> logout()
}
```

**Logique splash** (max 2 secondes) :
```
1. Tenter GET /api/v1/profile avec le token stocké
2. Succès → status = authenticated → router redirige vers /home
3. Échec 401 → tenter refresh
4. Refresh OK → status = authenticated
5. Refresh KO → status = unauthenticated → /auth ou /onboarding
```

**Écran OTP** :
- 6 cases individuelles (chaque case = 1 chiffre)
- Compteur countdown 5:00 → "Renvoyer le code"
- Après 5 tentatives → timer 10 minutes (stocker expiry en SharedPreferences)

**Critères d'acceptation** :
- [ ] Premier lancement → Onboarding s'affiche (flag `onboarding_done` absent)
- [ ] Lancement suivant → splash vérifie le token, redirige directement
- [ ] Saisir `+237699000000` → OTP envoyé (vérifier via API logs)
- [ ] Saisir un code invalide → message "Code incorrect — X essais restants"
- [ ] Saisir le bon code → navigue vers `/auth/welcome` (nouveau) ou `/home` (existant)
- [ ] Compteur OTP atteint 00:00 → bouton "Renvoyer" s'active
- [ ] Après 5 échecs → écran bloqué avec timer 10 minutes
- [ ] `logout()` → tokens supprimés → redirigé vers `/auth`

---

## AUTH-02 — Google OAuth + Facebook OAuth
**Priorite** : P1 | **Effort** : M

**Description** : Ajouter les boutons Google et Facebook sur l'écran d'auth. Le flow OAuth natif retourne un token social que l'API échange contre un JWT Kleanet.

**Fichiers a modifier** :
```
lib/features/auth/providers/auth_provider.dart  (+loginWithGoogle, +loginWithFacebook)
lib/features/auth/repositories/auth_repository.dart
lib/features/auth/screens/auth_screen.dart
```

**Flow** :
```
1. google_sign_in.signIn() → GoogleSignInAccount
2. account.authentication → idToken
3. POST /api/v1/auth/google  { id_token }
4. API retourne { access_token, refresh_token, is_new_user }
5. Stocker tokens → router redirige (welcome si nouveau, home si existant)
```

**Critères d'acceptation** :
- [ ] Tap "Continuer avec Google" → popup Google de l'OS (pas une webview)
- [ ] Connexion Google réussie → accès à `/home`
- [ ] Tap "Continuer avec Facebook" → flow natif Facebook
- [ ] Connexion Facebook réussie → accès à `/home`
- [ ] Annuler le flow Google/FB → retour à l'écran d'auth sans erreur
- [ ] Compte Google dont l'email est déjà lié à un numéro → même `partner_id` (pas de doublon)

---

# 3. Catalog

## CATALOG-01 — Catalogue vêtements avec cache
**Priorite** : P0 | **Effort** : M

**Description** : Charger le catalogue (types de vêtements + matières + règles de prix) depuis l'API et le mettre en cache local. Le catalogue change rarement — il est chargé une fois au démarrage et rafraîchi en arrière-plan.

**Fichiers a créer** :
```
lib/features/catalog/
├── models/catalog_models.dart
├── providers/catalog_provider.dart
└── repositories/catalog_repository.dart
```

**Modèles** :
```dart
GarmentType { id, name, icon_url, is_special_item, base_price }
Material    { id, name }
PricingRule { id, mode, garment_type_id?, material_id?, price }
```

**Stratégie de cache** :
- Stocker le catalogue en `SharedPreferences` (JSON sérialisé)
- Stocker le timestamp de la dernière mise à jour
- Si `now - lastUpdate < 1 heure` → utiliser le cache, sinon rafraîchir

**Critères d'acceptation** :
- [ ] `GET /api/v1/catalog` retourne la liste des types de vêtements
- [ ] Couper l'API → le catalogue s'affiche depuis le cache
- [ ] Chaque article affiche nom + prix (ex: "Chemise coton — 1 200 XAF/pièce")
- [ ] Le cache est invalidé après 1 heure (re-fetch automatique)
- [ ] `CatalogProvider.isLoading` affiche un skeleton pendant le chargement

---

# 4. Order

## ORDER-01 — Étape 1 : Sélection des vêtements
**Priorite** : P0 | **Effort** : M

**Description** : Implémenter le premier écran du flux de commande (modal). Le client sélectionne les vêtements, choisit la matière si applicable, et voit le total estimé mis à jour en temps réel.

**Fichiers a créer** :
```
lib/features/orders/
├── models/order_models.dart
├── providers/new_order_provider.dart
├── repositories/order_repository.dart
└── screens/new_order/step1_garments_screen.dart
```

**NewOrderProvider — état** :
```dart
class NewOrderProvider extends ChangeNotifier {
  List<OrderLineInput> lines = [];
  String? pickupDate;
  String? pickupTime;
  DeliveryLocation? location;

  double get estimatedTotal        // calculé depuis lines + catalog
  bool get canProceedToStep2       // au moins 1 article
  void addLine(GarmentType, {material, qty, weightKg})
  void removeLine(int index)
  void updateQty(int index, int qty)
  void reset()
}
```

**Bottom sheet matière** :
- S'affiche quand l'article sélectionné a plusieurs matières disponibles
- Selection → prix mis à jour immédiatement

**Critères d'acceptation** :
- [ ] La liste des vêtements vient du `CatalogProvider` (déjà chargé)
- [ ] Ajouter "Chemise coton × 2" → total se met à jour immédiatement
- [ ] Retirer tous les articles → bouton "Suivant" désactivé
- [ ] Total XAF formaté : "2 800 XAF" (espace comme séparateur de milliers)
- [ ] Fermer le modal (✕) → `NewOrderProvider.reset()` appelé

---

## ORDER-02 — Étape 2 : Pickup & Localisation
**Priorite** : P0 | **Effort** : L

**Description** : Permettre au client de choisir la date/heure de pickup et de confirmer ou capturer sa position GPS.

**Fichiers a créer** :
```
lib/features/orders/screens/new_order/step2_pickup_screen.dart
lib/shared/widgets/location_picker_widget.dart
```

**Calendrier** :
- Widget Flutter natif ou `table_calendar` si plus riche
- Minimum : J+1 (pas aujourd'hui)
- Grille d'heures : boutons radio 07h00 → 19h00 par tranches de 2h
- Désactiver les heures < 2h à l'avance

**Localisation** (widget réutilisable) :
```
1. Appeler GET /api/v1/profile → vérifier delivery_location
2. Si position enregistrée → afficher mini-carte flutter_map + 2 options :
   "Utiliser cette adresse" / "Utiliser ma position actuelle"
3. Si aucune position → bouton "Utiliser ma position GPS"
4. Tap GPS → permission_handler demande la permission
5. geolocator.getCurrentPosition() → coordonnées
6. PATCH /api/v1/profile/location → sauvegardé
7. Toast "Position enregistrée ✓"
```

**Critères d'acceptation** :
- [ ] Les jours passés et aujourd'hui sont grisés et non sélectionnables
- [ ] Une heure dans < 2h → désactivée
- [ ] Sélectionner date + heure → résumé visible "Jeudi 26 mars à 09h00"
- [ ] Si position déjà enregistrée → mini-carte `flutter_map` s'affiche (OpenStreetMap)
- [ ] Tap "Ma position GPS" → demande permission si nécessaire → coordonnées capturées
- [ ] Position `(0, 0)` → rejetée, message d'erreur "Position non disponible"
- [ ] PATCH réussi → toast "Position enregistrée" → mini-carte mise à jour

---

## ORDER-03 — Étape 3 : Récapitulatif & Confirmation
**Priorite** : P0 | **Effort** : M

**Description** : Afficher le récapitulatif complet et envoyer la commande à l'API.

**Fichiers a créer** :
```
lib/features/orders/screens/new_order/step3_summary_screen.dart
lib/features/orders/screens/order_confirmed_screen.dart
```

**Appels API** :
```dart
// En parallèle après confirmation :
final order = await orderRepo.createOrder(CreateOrderInput(...));
final appt  = await apptRepo.createAppointment(CreateAppointmentInput(
  type: 'pickup',
  scheduled_from: selectedDateTime.toIso8601String(),
  order_ids: [order.id],
));
```

**Critères d'acceptation** :
- [ ] Écran 3 affiche : lignes de commande, total estimé, date pickup, adresse, mode de paiement
- [ ] Bouton "Modifier les articles" → retour étape 1 sans perdre pickup/adresse
- [ ] Bouton "Modifier le pickup" → retour étape 2 sans perdre les articles
- [ ] Tap "Confirmer" → spinner → POST `/api/v1/orders` + POST `/api/v1/appointments`
- [ ] Succès → navigate replace vers `/order/confirmed` avec numéro de commande
- [ ] Erreur réseau → toast d'erreur, bouton "Réessayer" visible
- [ ] `NewOrderProvider.reset()` appelé après succès

---

# 5. Tracking

## TRACKING-01 — Détail commande & Timeline
**Priorite** : P0 | **Effort** : M

**Description** : Afficher le détail d'une commande avec la timeline animée, le QR code, et le bouton feedback.

**Fichiers a créer** :
```
lib/features/orders/screens/order_detail_screen.dart
lib/shared/widgets/order_status_badge.dart
lib/shared/widgets/order_timeline_widget.dart
```

**Mapping état API → affichage** :
```dart
const statusLabels = {
  'pending':          ('En attente',         Icons.schedule,    Colors.grey),
  'received':         ('Linge reçu',         Icons.check_circle, AppColors.success),
  'processing':       ('En traitement',      Icons.autorenew,   AppColors.accent1),
  'ready_for_pickup': ('Prêt à récupérer',   Icons.star,        AppColors.success),
  'delivered':        ('Livré',              Icons.done_all,    AppColors.primary),
  'cancelled':        ('Annulé',             Icons.cancel,      AppColors.error),
};
```

**Bannière `ready_for_pickup`** :
- Fond vert clair sur tout l'écran
- Pulsation sur le badge de statut (animation `AnimationController`)

**QR code** :
- `QrImageView(data: order.trackingUrl)`
- Tap → Dialog plein écran sur fond blanc (facilite le scan)
- Bouton partager → `Share.share(order.trackingUrl)`

**Pull-to-refresh** : `RefreshIndicator` + `orderProvider.refreshOrder(id)`

**Critères d'acceptation** :
- [ ] Timeline affiche exactement 5 états : En attente → Reçu → En traitement → Prêt → Livré
- [ ] État actuel en pulsation, états passés cochés, états futurs grisés
- [ ] Commande `ready_for_pickup` → bannière verte + pulsation
- [ ] Commande `delivered` → bouton "Laisser un avis" visible en bas
- [ ] QR code tap → plein écran
- [ ] Pull-to-refresh → re-fetch `GET /api/v1/orders/:id`
- [ ] Icône 🔗 AppBar → `Share.share()` avec l'URL de tracking

---

# 6. Orders

## ORDERS-01 — Liste des commandes & Accueil
**Priorite** : P0 | **Effort** : M

**Description** : Implémenter l'onglet "Commandes" (liste paginée avec filtres) et les cards commandes actives sur l'accueil.

**Fichiers a créer** :
```
lib/features/orders/screens/orders_list_screen.dart
lib/features/orders/providers/order_provider.dart
lib/shared/widgets/order_card.dart
```

**OrderProvider** :
```dart
class OrderProvider extends ChangeNotifier {
  List<OrderSummary> orders = [];
  bool isLoading = false;
  bool hasMore = true;
  int page = 1;

  List<OrderSummary> get activeOrders   // status != delivered + cancelled
  List<OrderSummary> get completedOrders
  bool get hasPendingPickup             // badge bottom nav

  Future<void> loadOrders({int page, String? status})
  Future<void> loadMore()
  Future<OrderDetail> getOrderDetail(int id)
}
```

**Tri des commandes actives** (accueil) :
`ready_for_pickup` → `processing` → `received` → `pending`

**Critères d'acceptation** :
- [ ] Onglet "Commandes" charge les 10 premières commandes
- [ ] Scroll jusqu'en bas → charge les 10 suivantes (pagination infinie)
- [ ] Filtre "En cours" → uniquement `pending/received/processing/ready_for_pickup`
- [ ] Filtre "Terminées" → uniquement `delivered/cancelled`
- [ ] Badge rouge sur l'onglet "Commandes" si une commande est `ready_for_pickup`
- [ ] Card `ready_for_pickup` → fond vert clair + badge "PRÊT"
- [ ] Skeleton affiché pendant le premier chargement

---

# 7. Subscription

## SUBSCRIPTION-01 — Hub & Comparaison des plans
**Priorite** : P1 | **Effort** : M

**Description** : Onglet Abonnement — afficher le tableau de bord si abonné, la page de vente sinon. Permettre de comparer et souscrire à un plan.

**Fichiers a créer** :
```
lib/features/subscription/
├── models/subscription_models.dart
├── providers/subscription_provider.dart
├── repositories/subscription_repository.dart
└── screens/
    ├── subscription_hub_screen.dart   # Écran 16 + 16-B
    ├── plans_screen.dart              # Écran 17
    └── subscribe_confirm_screen.dart  # Écran 18
```

**SubscriptionProvider** :
```dart
class SubscriptionProvider extends ChangeNotifier {
  ActiveSubscription? subscription;  // null si pas d'abonnement
  List<SubscriptionPlan> plans = [];

  bool get isSubscribed => subscription != null;
  Future<void> loadSubscription()
  Future<void> loadPlans()
  Future<void> subscribe(int planId)
}
```

**Dashboard (Écran 16-B)** :
- Barres de progression : `LinearProgressIndicator` pour poids + pièces + pickups
- `usage.remaining_weight_kg` calculé côté API → afficher "X kg restants"
- `overage_price_per_kg` → note "Au-delà : X XAF/kg"

**Critères d'acceptation** :
- [ ] Sans abonnement → page de vente avec bouton "Voir les plans"
- [ ] Plans chargés depuis `GET /api/v1/catalog/subscription-plans`
- [ ] Chaque plan affiche : prix, kg inclus, pièces, pickups/semaine, overage
- [ ] Bouton "Choisir" → Écran 18 avec récapitulatif
- [ ] Confirmation → `POST /api/v1/subscription` → animation bienvenue
- [ ] Avec abonnement → dashboard avec barres de progression
- [ ] `POST /api/v1/subscription` alors qu'actif → `409 ALREADY_SUBSCRIBED` → toast d'erreur

---

# 8. Profile

## PROFILE-01 — Profil, modification et localisation
**Priorite** : P1 | **Effort** : M

**Description** : Onglet Profil — afficher les informations du client, permettre la modification, et gérer la position GPS.

**Fichiers a créer** :
```
lib/features/profile/
├── models/profile_models.dart
├── providers/profile_provider.dart
├── repositories/profile_repository.dart
└── screens/
    ├── profile_screen.dart
    ├── edit_profile_screen.dart
    └── appointments_screen.dart
```

**Critères d'acceptation** :
- [ ] Profil charge `GET /api/v1/profile` au montage du widget
- [ ] Modifier le nom → `PATCH /api/v1/profile` → snackbar "Profil mis à jour"
- [ ] Numéro de téléphone affiché mais non modifiable
- [ ] "Mes rendez-vous" → liste des appointments `GET /api/v1/appointments`
- [ ] Chaque RDV affiche : type (pickup/livraison), date, heure, statut avec badge coloré
- [ ] Bouton "Se déconnecter" → dialog de confirmation → `AuthProvider.logout()`

---

# 9. Support

## SUPPORT-01 — FAQ
**Priorite** : P2 | **Effort** : S

**Description** : Afficher la FAQ par catégories. Accessible sans authentification.

**Fichiers a créer** :
```
lib/features/faq/
├── models/faq_models.dart
├── providers/faq_provider.dart
├── repositories/faq_repository.dart
└── screens/
    ├── faq_categories_screen.dart
    └── faq_article_screen.dart
```

**Critères d'acceptation** :
- [ ] FAQ accessible sans token (guard désactivé pour `/faq`)
- [ ] Catégories chargées depuis `GET /api/v1/faq`
- [ ] Tap catégorie → liste des articles de la catégorie
- [ ] Tap article → page complète avec rendu HTML/Markdown
- [ ] Recherche par mot-clé (filtre local sur les articles déjà chargés)
- [ ] 0 résultats → "Contactez-nous" avec lien WhatsApp

---

## SUPPORT-02 — Formulaire de Feedback
**Priorite** : P1 | **Effort** : M

**Description** : Permettre au client de laisser un avis après livraison. Accessible uniquement depuis une commande `delivered`.

**Fichiers a créer** :
```
lib/features/feedback/
├── models/feedback_models.dart
├── providers/feedback_provider.dart
├── repositories/feedback_repository.dart
└── screens/
    ├── feedback_form_screen.dart
    └── feedback_success_screen.dart
```

**Critères d'acceptation** :
- [ ] Formulaire accessible uniquement depuis une commande `delivered`
- [ ] Étoiles (1→5) obligatoires avant de pouvoir soumettre
- [ ] Label contextuel dynamique (1⭐ "Mauvaise", … 5⭐ "Excellent ! 🎉")
- [ ] Commentaire texte optionnel
- [ ] Question "Recommanderiez-vous Kleanet ?" — bouton 👍 / 👎
- [ ] `POST /api/v1/feedback` → navigate replace vers `/feedback/success`
- [ ] Tentative double feedback sur la même commande → `409` → message "Déjà noté"

---

# 10. Notifications

## NOTIF-01 — Push notifications FCM
**Priorite** : P1 | **Effort** : L

**Description** : Configurer Firebase Cloud Messaging pour recevoir les notifications de changement d'état des commandes. Implémenter le centre de notifications.

**Fichiers a créer** :
```
lib/features/notifications/
├── models/notification_models.dart
├── providers/notification_provider.dart
└── screens/notifications_screen.dart
lib/main.dart  (modifier pour init Firebase)
```

**Configuration** :
- `firebase_messaging` initialisé dans `main()` avant `runApp()`
- Demander la permission iOS/Android au premier login
- Envoyer le FCM token à l'API : `PATCH /api/v1/profile` avec `{ fcm_token }`
- Gérer les 3 cas : app en foreground, background, terminée

**Payload de notification attendu** (depuis l'API) :
```json
{
  "title": "🎉 Votre linge est prêt !",
  "body": "Commande LORD/00156 — cliquez pour voir",
  "data": { "type": "order_status", "order_id": "156" }
}
```

**Tap notification → navigation** :
```dart
// data.type == "order_status" → GoRouter.go('/order/${data.order_id}')
```

**Centre de notifications** (Écran 27) :
- Liste des notifications stockées localement (SQLite ou SharedPreferences JSON)
- Badge sur l'icône 🔔 si notifications non lues

**Critères d'acceptation** :
- [ ] FCM token envoyé à l'API au login
- [ ] App en foreground → notification affichée en overlay (snackbar ou dialog)
- [ ] App en background → notification système → tap → ouvre la bonne commande
- [ ] App fermée → notification système → tap → ouvre l'app sur la bonne commande
- [ ] Badge 🔔 sur l'AppBar si notifications non lues
- [ ] Entrer dans le centre → marquer toutes comme lues → badge disparaît

---

# 11. Quality

## QUALITY-01 — Tests, polish & Release
**Priorite** : P1 | **Effort** : XL

**Description** : Tests unitaires des providers et repositories, tests widget des écrans critiques, optimisation des performances, et préparation du build de release.

**Tests prioritaires** :

```dart
// Providers
AuthProvider   → checkSession(), verifyOtp(), logout()
OrderProvider  → tri des commandes actives, hasPendingPickup
NewOrderProvider → estimatedTotal, canProceedToStep2

// Widgets
OrderCard      → affiche le bon badge selon le status
OrderTimeline  → états corrects, état actuel en évidence
OtpScreen      → 5 échecs → timer affiché
```

**Polish visuel** :
- Skeleton loading sur toutes les listes (shimmer)
- Empty states sur : commandes, abonnements, FAQ, notifications
- Écran d'erreur réseau avec bouton "Réessayer"
- Transitions de navigation fluides

**Build release** :
```bash
# Android
flutter build appbundle --release --dart-define=ENV=production

# iOS
flutter build ipa --release --dart-define=ENV=production
```

**Critères d'acceptation** :
- [ ] `flutter test` → 0 échec
- [ ] `flutter analyze` → 0 erreur, 0 warning
- [ ] Pas de `print()` en production (utiliser un logger)
- [ ] Build release Android (`.aab`) sans erreur
- [ ] Build release iOS (`.ipa`) sans erreur
- [ ] Temps de démarrage cold start < 3 secondes sur un Android milieu de gamme
- [ ] Pas de fuite mémoire sur le flux commande (dispose() appelé sur les controllers)

---

## Récapitulatif

| # | Étape | Priorité | Effort | Écrans couverts |
|---|-------|----------|--------|-----------------|
| 1 | FOUNDATION-01 | P0 | M | Splash (design) |
| 2 | FOUNDATION-02 | P0 | L | — |
| 3 | FOUNDATION-03 | P0 | M | — |
| 4 | AUTH-01 | P0 | L | 1, 2, 3, 4, 5, 6 |
| 5 | AUTH-02 | P1 | M | 3 |
| 6 | CATALOG-01 | P0 | M | — |
| 7 | ORDER-01 | P0 | M | 9 |
| 8 | ORDER-02 | P0 | L | 10 |
| 9 | ORDER-03 | P0 | M | 11, 12 |
| 10 | TRACKING-01 | P0 | M | 14 |
| 11 | ORDERS-01 | P0 | M | 8, 15 |
| 12 | SUBSCRIPTION-01 | P1 | M | 16, 16-B, 17, 18 |
| 13 | PROFILE-01 | P1 | M | 19, 20, 21 |
| 14 | SUPPORT-01 | P2 | S | 23, 24 |
| 15 | SUPPORT-02 | P1 | M | 25, 26 |
| 16 | NOTIF-01 | P1 | L | 22, 27 |
| 17 | QUALITY-01 | P1 | XL | — |

**Total P0 (bloquant)** : étapes 1 → 11 (fondations + commande complète)
**Total P1 (important)** : étapes 5, 12 → 13, 15 → 17
**Total P2 (utile)** : étape 14

---

*Document de développement Flutter — Kleanet Mobile — 2026-03-28*
*Prochaine étape : finaliser l'API (franny-api), puis initier le projet Flutter*
