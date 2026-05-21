# Kleanet — Application Mobile

> **"Propre à temps"** — Service de blanchisserie à domicile, Yaoundé, Cameroun.

Application Flutter de l'écosystème Kleanet.  
Stack complète : **Odoo 19** (back-office) + **API Fastify/TypeScript** (middleware) + **ce dépôt Flutter** (app mobile).

---

## Fonctionnalités

| Module | Statut |
|--------|--------|
| Authentification OTP (SMS via Africa's Talking) | ✅ |
| Catalogue de services (vêtements + tarifs) | ✅ |
| Création de commande (3 étapes : articles → pickup → récapitulatif) | ✅ |
| Suivi de commande — timeline de statut | ✅ |
| Liste des commandes | ✅ |
| Abonnements (hub + comparaison de plans + souscription) | ✅ |
| Profil utilisateur + édition + rendez-vous | ✅ |
| FAQ (catégories + articles) | ✅ |
| Formulaire de feedback | ✅ |
| Notifications push Firebase FCM | ✅ |
| Tests unitaires + release build Android | ⏭ Prochain |

---

## Stack technique

```
Flutter 3.27.1 / Dart 3.6.0
├── État          : Provider (ChangeNotifier)
├── Navigation    : GoRouter
├── HTTP          : Dio + intercepteur JWT (refresh automatique)
├── Tokens        : flutter_secure_storage
├── Env           : flutter_dotenv (.env.development / .env.production)
├── Push notifs   : firebase_messaging + firebase_core
└── Icône app     : flutter_launcher_icons
```

---

## Architecture

Découpe par feature sous `lib/` :

```
lib/
├── main.dart                   # Bootstrap : Firebase → dotenv → router → runApp
├── app.dart                    # MaterialApp.router + MultiProvider
├── core/
│   ├── api/
│   │   ├── api_client.dart     # Dio singleton + intercepteur JWT
│   │   ├── api_endpoints.dart  # Constantes URL
│   │   ├── api_exception.dart  # ApiException(statusCode, code, message)
│   │   └── generated/          # Modèles générés depuis openapi.json
│   ├── auth/token_storage.dart # Wrapper flutter_secure_storage
│   ├── config/env.dart         # Wrapper flutter_dotenv
│   └── router/app_router.dart  # GoRouter + garde d'authentification
├── features/
│   ├── auth/
│   ├── catalog/
│   ├── orders/
│   ├── subscription/
│   ├── profile/
│   ├── faq/
│   ├── feedback/
│   └── notifications/
└── shared/
    ├── widgets/                # Composants UI réutilisables
    ├── theme/                  # AppColors, AppTextStyles, AppTheme
    └── utils/                  # phone_utils, currency_utils, date_utils
```

**Flux de données** : `Écran` → `Provider` (via `context.watch<>()`) → `Repository` → `ApiClient` (Dio).

---

## Démarrage rapide

### Prérequis

- Flutter 3.27.1 stable
- Android SDK (platform android-36, build-tools 36.1.0)
- Node.js 20+ (pour l'API Fastify locale)
- Un émulateur Android ou un appareil physique

### Installation

```bash
# Cloner le dépôt
git clone <url>
cd kleanet_app

# Installer les dépendances
flutter pub get

# Lancer l'application (émulateur Android)
flutter run
```

### Configuration de l'environnement

Créer `assets/env/.env.development` :

```env
# Émulateur Android (10.0.2.2 = localhost de la machine hôte)
API_BASE_URL=http://10.0.2.2:3000

# Appareil physique avec USB (après adb reverse tcp:3000 tcp:3000)
# API_BASE_URL=http://localhost:3000
```

Pour un appareil physique connecté par USB :

```bash
adb reverse tcp:3000 tcp:3000
```

### Commandes utiles

```bash
# Analyse statique — doit retourner 0 erreurs avant tout commit
flutter analyze

# Tests
flutter test

# Régénérer les modèles Dart depuis le schéma OpenAPI
flutter pub run build_runner build

# Rebuild complet
flutter pub run build_runner clean && flutter pub run build_runner build
```

---

## Notifications push (Firebase FCM)

L'app est connectée à Firebase Cloud Messaging.  
Le flux complet est : **Odoo** (changement de statut commande) → **Fastify** (webhook) → **Firebase Admin SDK** → **téléphone**.

### Configuration requise

1. **Firebase** — générer une clé de service (Firebase Console → Paramètres → Comptes de service) et ajouter dans `kleanet_api/.env` :
   ```
   FIREBASE_PROJECT_ID=...
   FIREBASE_CLIENT_EMAIL=...
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   WEBHOOK_SECRET=<secret_min_16_chars>
   ```

2. **Odoo** — paramètres système (mode dev requis) :
   - `kleanet.fastify_url` → `http://localhost:3000`
   - `kleanet.webhook_secret` → même valeur que `WEBHOOK_SECRET`

3. **Module Odoo** — Upgrade `bw_kleanet` dans Odoo → Applications.

4. **API Fastify** — `npm run dev` dans `kleanet_api/`, vérifier `Firebase Admin initialisé.` dans les logs.

---

## Branding

| Élément | Valeur |
|---------|--------|
| Couleur primaire | `#1E3A5F` (Bleu nuit) |
| Accent cyan | `#06B6D4` |
| Accent violet | `#4F46E5` |
| Police | Poppins (Bold / Regular / Light) |
| Tagline | **Propre à temps** |

---

## Dépôts liés

| Dépôt | Rôle |
|-------|------|
| `kleanet_api/` | API Fastify/TypeScript — middleware Odoo ↔ app |
| `bw_kleanet/` | Module Odoo 19 — back-office commandes, abonnements, tarifs |

---

## Paiement (phases)

- **Phase 0 (actuelle)** : règlement à la livraison — cash ou MoMo manuel
- **Phase 1** : Campay (MTN + Orange) via WebView in-app
- **Phase 2** : Notchpay SDK natif + cartes bancaires

---

*Dernière mise à jour : 2026-05-21*
