# Kleanet — Backlog V2

> Ce fichier liste tout ce qui a été **explicitement reporté** pendant le développement V1.
> Chaque item indique l'origine du report, le fichier concerné, et le contexte.
> À transformer en tickets au démarrage de V2.

---

## Auth

| # | Fonctionnalité | Origine | Fichier(s) |
|---|---------------|---------|-----------|
| A-01 | **Google OAuth + Facebook OAuth** | Déprioritisé en cours de route (AUTH-02 ⏸ P1) | `features/auth/` — screens + repository à créer |
| A-02 | **Révocation du refresh token côté backend au logout** | `signOut()` efface seulement le stockage local pour l'instant | `auth_provider.dart:214` — ajouter `DELETE /auth/logout` + attente UX dans l'écran profil |

---

## Commandes

| # | Fonctionnalité | Origine | Fichier(s) |
|---|---------------|---------|-----------|
| O-01 | **Pagination scroll infini sur la liste** | `limit=50` codé en dur — suffisant V1, insuffisant à l'échelle | `order_repository.dart:25`, `orders_list_provider.dart` — ajouter `page` + `hasMore` + listener scroll |
| O-02 | **Annulation d'une commande depuis la liste / le détail** | Hors périmètre V1 | `orders_list_screen.dart`, `order_detail_screen.dart` — bouton + `PATCH /orders/:id/cancel` |
| O-03 | **Géolocalisation GPS à l'étape pickup** | "sera ajoutée en ORDER-02" | `new_order_pickup_screen.dart:5` — package `geolocator` + `PATCH /profile/location` |
| O-04 | **Re-programmer un pickup depuis l'écran détail** | Commentaire dans le provider | `order_draft_provider.dart:156` — bouton "Modifier le créneau" + POST /appointments |

---

## Abonnements

| # | Fonctionnalité | Origine | Fichier(s) |
|---|---------------|---------|-----------|
| S-01 | **SUBSCRIPTION-01 complet** (hub + comparaison de plans + souscription) | Étape non démarrée | À créer entièrement — `features/subscription/` |
| S-02 | **Annulation / suspension d'abonnement** | Non couvert par SUBSCRIPTION-01 | À définir avec l'API |

---

## Profil & Localisation

| # | Fonctionnalité | Origine | Fichier(s) |
|---|---------------|---------|-----------|
| P-01 | **PROFILE-01/02** — écran profil + édition + rendez-vous | Étape non démarrée | À créer — `features/profile/` |
| P-02 | **Cache catalogue user-scoped** | Cache actuellement global (une seule clé, indépendant du user) | `catalog_cache.dart:54` — préfixer la clé par `partnerId` si multi-compte |

---

## Support

| # | Fonctionnalité | Origine | Fichier(s) |
|---|---------------|---------|-----------|
| SP-01 | **SUPPORT-01** — FAQ catégories + articles | Étape non démarrée | À créer — `features/faq/` |
| SP-02 | **FEEDBACK-01** — formulaire de feedback | Étape non démarrée | À créer — `features/feedback/` |

---

## Notifications

| # | Fonctionnalité | Origine | Fichier(s) |
|---|---------------|---------|-----------|
| N-01 | **NOTIFICATIONS-01** — Push Firebase FCM | Étape non démarrée (dépend de PROFILE-01) | À créer — `features/notifications/` + `firebase_messaging` |

---

## Paiement

| # | Fonctionnalité | Origine | Fichier(s) |
|---|---------------|---------|-----------|
| PAY-01 | **Campay (MTN + Orange MoMo)** via WebView in-app | Phase 0 = cash/MoMo manuel en V1 | Voir `PAIEMENT_INTEGRATION.md` — WebView + webhook Fastify |
| PAY-02 | **Notchpay SDK natif + cartes bancaires** | Phase 2 | Voir `PAIEMENT_INTEGRATION.md` |

---

## Qualité & Infrastructure

| # | Fonctionnalité | Origine | Fichier(s) |
|---|---------------|---------|-----------|
| Q-01 | **QUALITY-01** — suite de tests + release build | Dernière étape du plan, non démarrée | `test/` — widget tests providers + golden tests |
| Q-02 | **Génération de code OpenAPI → Dart** | Décision architecturale documentée mais non appliquée | `FLUTTER_DEV_PLAN.md` section "Note : OpenAPI → Dart" — `build_runner` + `openapi_generator` |
| Q-03 | **Support multi-pays numéros de téléphone** | Préfixe `+237` codé en dur pour le Cameroun | `phone_utils.dart:9` — passer le pays en paramètre |

---

## Odoo bw_kleanet (backend)

| # | Fonctionnalité | Origine | Fichier(s) |
|---|---------------|---------|-----------|
| OD-01 | **Committer les changements 5-états** (working tree non committé) | Fix `eeb5c6f` flutter-side — équivalent Odoo pas encore versionné | `/brightwill/odoo-core/custom_addons/bw_kleanet/` — 8 fichiers |
| OD-02 | **Upgrade module Kleanet dans Odoo** | Requis pour migrer les anciens états `in_progress` en base | Apps → Upgrade → post_init_hook SQL |
| OD-03 | **Modèles V2** (batch, bag, washing rule, consumable, machine, incident) | Exclus du module V1 par décision de découpage | Futur module `franny_laundry_v2` natif Odoo 19 |

---

## API kleanet_api (Fastify)

| # | Fonctionnalité | Origine | Fichier(s) |
|---|---------------|---------|-----------|
| API-01 | **Committer les changements 5-états** (working tree non committé) | Fix alignement OrderStatus — pas encore versionné | `kleanet_api/` — 5 fichiers (types, service, schema, tests, openapi.json) |
| API-02 | **Redémarrer l'API** après commit | Requis pour servir le nouveau schéma enum | `npm run dev` dans `kleanet_api/` |

---

*Dernière mise à jour : 2026-04-23*
