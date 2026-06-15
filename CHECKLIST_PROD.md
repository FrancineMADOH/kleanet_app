# Checklist avant APK de production — Kleanet App

> Dernière mise à jour : 2026-06-15
> À compléter dans l'ordre avant de générer l'APK release et de passer en prod.

---

## 1. Configuration & Secrets

- [ ] **`assets/env/.env.production`** créé avec `API_BASE_URL` pointant vers le vrai serveur (pas `localhost`)
- [ ] **Clés Firebase** renseignées dans `kleanet_api/.env` :
  - `FIREBASE_PROJECT_ID`
  - `FIREBASE_CLIENT_EMAIL`
  - `FIREBASE_PRIVATE_KEY` (les `\n` littéraux doivent être restaurés avec `.replace(/\\n/g, '\n')`)
  - `WEBHOOK_SECRET`
- [ ] **Paramètres Odoo** configurés dans `ir.config_parameter` (Paramètres → Technique) :
  - `kleanet.fastify_url` → URL publique de l'API (ex: `https://api.kleanet.cm`)
  - `kleanet.webhook_secret` → même valeur que `WEBHOOK_SECRET` dans `kleanet_api/.env`
- [ ] Module `bw_kleanet` upgradé dans Odoo (Apps → Mettre à jour) après config
- [ ] API `kleanet_api` redémarrée après ajout des clés Firebase
- [ ] `google-services.json` présent dans `android/app/` (Firebase Android — hors git, à copier manuellement depuis la console Firebase)

---

## 2. Signature APK

- [ ] Keystore de release créé et **sauvegardé en dehors du repo git** (ex: sur un drive sécurisé) :
  ```bash
  keytool -genkey -v -keystore kleanet-release.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias kleanet
  ```
- [ ] `android/key.properties` créé (ce fichier est dans `.gitignore`) :
  ```
  storePassword=<mot de passe keystore>
  keyPassword=<mot de passe clé>
  keyAlias=kleanet
  storeFile=<chemin absolu vers kleanet-release.jks>
  ```
- [ ] `android/app/build.gradle` — bloc `signingConfigs { release { ... } }` configuré et référencé dans `buildTypes { release { ... } }`
- [ ] `flutter build apk --release` passe sans erreur de signature

---

## 3. Tests & Qualité

- [ ] **QUALITY-01** — `flutter test` passe (0 échec)
- [ ] `flutter analyze` — 0 erreur, 0 warning
- [ ] Test bout-en-bout sur build **release** (pas debug) :
  - Auth OTP → accueil → commande → détail commande → abonnement
- [ ] Tester sur connexion **3G** (simuler latence terrain Yaoundé) — pas uniquement en WiFi
- [ ] Vérifier qu'aucun écran n'affiche `localhost` ou une URL de dev dans les messages d'erreur visibles à l'utilisateur
- [ ] Vérifier que tous les messages d'erreur réseau sont en **français** (pas de raw exception anglaise)

---

## 4. Expérience utilisateur

- [x] Nom launcher = **Kleanet** ✅ (corrigé 2026-06-15 — `AndroidManifest.xml`)
- [x] Icône launcher = logo goutte ✅
- [x] Splash screen correct ✅
- [x] `debugShowCheckedModeBanner: false` ✅
- [ ] Tester sur un device Redmi / Samsung entrée de gamme (cible Yaoundé) — pas uniquement sur le device de dev
- [ ] Vérifier la lisibilité des textes sur petits écrans (5 pouces)

---

## 5. Build release

- [ ] Générer l'APK release par ABI (taille réduite) :
  ```bash
  flutter build apk --release --split-per-abi
  # Génère : arm64-v8a (Androids récents), armeabi-v7a (Androids < 2018)
  ```
  *Ou pour le Play Store :*
  ```bash
  flutter build appbundle --release
  ```
- [ ] Taille APK vérifiée (objectif < 50 MB pour le marché camerounais)
- [ ] APK installé sur un **device propre** (sans flutter run préalable) et testé de A à Z
- [ ] Numéro de version et `versionCode` mis à jour dans `pubspec.yaml` :
  ```yaml
  version: 1.0.0+1   # format: version_name+version_code
  ```

---

## 6. V2 — Backlog post-lancement

Ces points ne bloquent pas la beta mais doivent être planifiés :

| Priorité | Item | Description |
|----------|------|-------------|
| P1 | **BUG-12** — Changement de plan | Ajouter `PATCH /subscription/` (3 couches : Odoo + API + Flutter) |
| P1 | **BUG-07** — Nom profil placeholder | Afficher "Ajouter un prénom" quand le nom est vide |
| P1 | **BUG-08** — Logo fond blanc JPG | Remplacer `logo.jpg` par SVG transparent via `flutter_svg` |
| P2 | **BUG-03/04** — QR code + partage | Page de suivi publique + `qr_flutter` + `share_plus` |
| P2 | **AUTH-02** — Google + Facebook OAuth | Boutons déjà présents, callbacks `TODO` à implémenter |
| P2 | **Multi-abonnements** | **Non retenu** — créer des plans à quotas supérieurs plutôt que d'empiler des abonnements |

---

## Verdict

| Statut | Condition |
|--------|-----------|
| ✅ **Beta fermée possible** | Sections 1 (env prod) + 2 (keystore) + FCM complétées |
| ✅ **Lancement public possible** | Toutes les sections 1 à 5 complétées |

*Généré le 2026-06-15 · Kleanet App v1.0 pre-release*
