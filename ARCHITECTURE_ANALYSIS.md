# Analyse Architecturale — KultivIA

> **Date** : 2026-09-24  
> **Auteur** : Kilo Code (Assistant IA)  
> **Version projet** : 0.1.0  
> **Note** : Tailles de fichiers corrigées (octets → lignes réelles) suite relecture.

---

## 🎯 Verdict Global

**Projet fonctionnel avec de bons fondements (sécurité Cloud Functions, i18n Wolof/Français, design system), mais dette technique structurelle à adresser pour passer en production maintenable.**

**Peut-il être mis en production ? OUI — après 3 correctifs P0 (DiagnosisRepository, découpage setup_screen, extraction UserSettings/DiagnosisHistory hors AppState).** Ces 3 points lèvent les vrais blocages : couplage Firebase, fichier monolithique restant, rebuilds en cascade. Le reste (go_router, package météo partagé, erreurs structurées, tests intégration, feature-first, Riverpod, CI/CD) sont des améliorations de robustesse/maintenabilité — pas des bloqueurs de mise en prod.

---

## ✅ Points Forts (À Conserver)

| Domaine | Force |
|---------|-------|
| **Sécurité IA** | Clés API **jamais** côté client — tout passe par Cloud Functions (`aiProxy`, `aiSpeech`, `aiTranscribe`). *Meilleure décision architecturale du projet.* |
| **Séparation des responsabilités** | `lib/services/` (Firebase, IA, Voice, Notifications, Météo), `lib/models/` (classes pures), `lib/screens/home_ai/` (composants extraits). |
| **Offline-first** | `AppState` garde l'état local, sync Firestore quand online. `FirebaseService` utilise des getters paresseux → app démarre même sans config Firebase. |
| **Internationalisation native** | `AppState.supportedLanguages` + prompts Wolof côté client **et** Functions. Rare à ce niveau. |
| **Fonctions pures testables** | `parseAiJsonResponse`, `assessRisks`, `alertMessage` exportées et testées unitairement. |
| **Design System naissant** | `KCard`, `StatusChip`, `StatusBanner`, `KSpace`, `KRadius` dans `k_components.dart` + `theme.dart` — langage visuel cohérent. |

---

## ⚠️ Lacunes & Risques Réels (Corrigés)

### 1. `lib/screens/` = Dumping Ground Plat (17 fichiers à la racine)

```
lib/screens/
  auth_screen.dart            (~190 lignes)
  community_screen.dart       (~150 lignes)
  diagnosis_result_screen.dart (~160 lignes)
  gate_screen.dart            (~60 lignes)
  health_dashboard_screen.dart (~100 lignes)
  history_screen.dart         (~35 lignes)
  home_ai_screen.dart         (~350 lignes)  ← déjà découpé (voir home_ai/)
  language_screen.dart        (~80 lignes)
  marketplace_screen.dart     (~150 lignes)
  onboarding_screen.dart      (~130 lignes)
  profile_screen.dart         (~140 lignes)
  setup_screen.dart           (~280 lignes)  ← **plus gros fichier restant**
  vendors_map_screen.dart     (~250 lignes)
  weather_alerts_screen.dart  (~160 lignes)
  home_ai/                    (4 fichiers composants : composer, empty_state, message_view, typing_dots)
```

**Problème** : Pas de regroupement par feature. `setup_screen.dart` (280 lignes) est le fichier le plus dense restant. `home_ai_screen.dart` (350 lignes) a déjà été découpé — la logique est dans `home_ai/`.

---

### 2. State Management = `ChangeNotifier` Global (`AppState`)

- `AppState` = **singleton** portant : langue, réglage voix, profil utilisateur, **historique complet des diagnostics**.
- Écrans font `context.read<AppState>()` / `context.watch<AppState>()` directement → couplage fort, rebuilds non granulaires, tests difficiles.
- Pas de séparation entre **état UI éphémère** (loading, controllers) et **état domaine persisté** (profil, historique).

**Risque** : Si `AppState` grossit encore (notifications, cache météo, préférences), les rebuilds en cascade deviendront un problème de perf.

---

### 3. Logique Métier qui Fuite dans les Widgets

Exemples dans `HomeAiScreen` :
- `_symptomContext()` — logique domaine dans une classe `State`
- `_send()` — ~80 lignes mélangeant : validation input, détection intent caméra, appels IA, écritures Firestore, TTS, navigation
- `looksLikeCameraRequest()` / `cameraReply()` importés de `avatar_intents.dart` mais appelés depuis le widget

**Règle violée** : Un widget ne doit que *rendre* et *dispatcher des intents*. Il ne doit pas *décider* ce qui constitue une demande de diagnostic.

---

### 4. Pas de Couche Repository / Data Layer

`FirebaseService` appelé directement depuis les widgets (`HomeAiScreen`, `SetupScreen`, etc.). Conséquences :
- Impossible d'ajouter du cache local (Hive/SQLite) sans réécrire les widgets
- Impossible de changer de backend sans toucher à l'UI
- Impossible de tester un écran sans Firebase (pas d'interface `DiagnosisRepository`, `UserRepository`, `VendorRepository`)

---

### 5. Backend (Functions) Duplique la Logique Domaine

`functions/weather_rules.js` miroite `lib/services/weather_service.dart` (`WeatherOutlook`). Le commentaire l'admet : *"Miroir de WeatherOutlook : si vous changez un seuil ici, changez-le aussi dans l'app."* → **Violation DRY**. La logique partagée Dart/JS devrait vivre dans un package commun ou être générée.

---

### 6. Tests = Symboliques

```
test/
  avatar_intents_test.dart      (779 octets)
  rodium_ai_service_test.dart   (1k)  ← teste seulement parseAiJsonResponse
  user_profile_test.dart        (1k)
  vendor_links_test.dart        (1.5k)
  voice_service_test.dart       (905 octets)
  weather_outlook_test.dart     (1.2k)
  widget_test.dart              (483 octets)  ← test compteur Flutter par défaut
```

**Aucun test d'intégration. Aucun test widget pour les vrais écrans. Aucun test de contrôleur d'état.** La CI donnera une fausse confiance.

---

### 7. Gestion d'Erreurs = `debugPrint` + SnackBar

```dart
catch (e) { 
  debugPrint('Erreur IA : $e'); 
  _toast('...'); 
}
```
- Pas de types d'erreurs structurés
- Pas de logique de retry
- Pas de file d'attente offline pour diagnostics échoués
- `unawaited(fb.saveDiagnosis(d).catchError(...))` → fire-and-forget avec échec silencieux

---

### 8. Navigation Stringly-Typed

```dart
routes: {
  '/': (_) => const GateScreen(),
  '/onboarding': (_) => const OnboardingScreen(),
  // ...
  '/result': géré dans onGenerateRoute avec argument `Diagnosis`
}
```
Pas de routing type-safe (`go_router`, `auto_route`). Passage de `Diagnosis` via `settings.arguments` = fragile.

---

### 9. Assets/Config

- `assets/images/logo.png` = **334 Ko** (corrigé : était 1,27 Mo, recadré 900×282) — acceptable.
- `firestore.rules` existe mais pas de `firestore.indexes.json` → les requêtes échoueront en prod sans création manuelle d'index.

---

## 🎯 Plan d'Action Réaliste pour Projet en Production

| Priorité | Action | Effort | Impact |
|----------|--------|--------|--------|
| **P0** | **Interface `DiagnosisRepository` mince** (`saveDiagnosis`, `watchDiagnoses`) + implémentation `FirebaseDiagnosisRepository` | ~30 min | Débloque cache offline, tests unitaires écrans, découplage Firebase |
| **P0** | **Découper `setup_screen.dart`** (280 lignes) → extraire composants dans `setup/`, sortir logique dans `SetupController`/`Notifier` | ~2-3h | Fichier le plus dense, même pattern que `home_ai/` déjà fait |
| **P0** | **Extraire `UserSettings` / `DiagnosisHistory` hors de `AppState`** | ~1h | Évite rebuilds en cascade, prépare migration state management future |
| **P1** | **Package partagé météo** (Dart ↔ JS) pour `assessRisks` / `alertMessage` | ~1h | Source unique de vérité, élimine duplication DRY |
| **P1** | **Routing type-safe** (`go_router`) | ~2h | Élimine bugs args, active deep links, guards auth |
| **P2** | **Gestion d'erreurs structurée** (`Result<T, E>`, retry, file offline) | ~3h | Fiabilité production, UX offline |
| **P2** | **Tests d'intégration** (émulateur Firebase + `integration_test`) | ~4h | Confiance déploiement, non-régression auth/sync/IA |
| **P3** | **Structure feature-first** (`lib/features/...`) | ~1 jour | Maintenabilité équipe, onboarding devs |
| **P3** | **Migration Riverpod/Bloc** (si équipe >2, durée >6 mois) | ~2-3 jours | Scalabilité état, testabilité, devtools |
| **P3** | **CI/CD GitHub Actions** (analyze, test, build, deploy functions) | ~2h | Qualité continue, zéro merge cassé |

---

## 📁 Structure Cible Recommandée (Feature-First, Progressive)

```
lib/
  core/
    theme.dart
    constants.dart
    routing/           # go_router config
    errors/            # Failure, Result<T,E>
    di/                # get_it / service locator
  features/
    auth/
      data/            # AuthRepositoryImpl, FirebaseAuthDataSource
      domain/          # AuthRepository, User entity
      presentation/    # AuthScreen, AuthController, widgets/
    diagnosis/
      data/            # DiagnosisRepositoryImpl, FirebaseDiagnosisDataSource, AiDiagnosisDataSource
      domain/          # DiagnosisRepository, Diagnosis entity, DiagnoseUseCase
      presentation/    # HomeAiScreen, DiagnosisController, widgets/
    setup/
      presentation/    # SetupScreen, SetupController, widgets/ (À FAIRE)
    onboarding/
    profile/
    marketplace/
    vendors/
    weather/
    community/
  shared/
    widgets/           # KCard, StatusChip, AppDrawer (vraiment partagés)
    models/            # UserProfile, Diagnosis (cross-features)
    services/          # VoiceService, NotificationService (transverses)
    l10n/              # ARB, AppLocalizations
```

---

## 💡 Résumé Exécutif

> **Ce qui bloque la production aujourd'hui** : pas de Repository (couplage Firebase), `setup_screen.dart` monolithique, `AppState` qui grossit, erreurs non structurées, pas de tests d'intégration.
>
> **Ce qui est déjà bon** : sécurité IA, i18n, design system, `home_ai/` découpé, logo optimisé.
>
> **Ordre de chantier recommandé** :
> 1. `DiagnosisRepository` (30 min, débloque tout)
> 2. Découpage `setup_screen.dart` (2-3h, pattern connu)
> 3. `UserSettings`/`DiagnosisHistory` hors `AppState` (1h, préventif)
> 4. Package météo partagé (1h, élimine bug sync Dart/JS)
> 5. `go_router` (2h, robustesse navigation)
> 6. Erreurs structurées + tests intégration (semaine 1-2 post-lancement)
> 7. Feature-first + Riverpod + CI/CD (quand équipe/projet le justifient)

---

## 📎 Fichiers Clés Analysés (Tailles Réelles)

| Fichier | Rôle | Lignes | Octets | Notes |
|---------|------|--------|--------|-------|
| `pubspec.yaml` | Dépendances | 63 | ~1.5 Ko | Provider, Firebase, Voice, HTTP — complet |
| `lib/main.dart` | Bootstrap + DI + Routes | 85 | ~3 Ko | MultiProvider, routes stringly-typed |
| `lib/services/app_state.dart` | État global (ChangeNotifier) | 83 | ~2.2 Ko | Singleton, tout dedans |
| `lib/services/firebase_service.dart` | Auth + Firestore | 178 | ~7 Ko | Appelé direct depuis UI |
| `lib/models/user_profile.dart` | Modèle utilisateur | 83 | ~2.5 Ko | `copyWith`, `toMap`/`fromMap` |
| `lib/models/diagnosis.dart` | Modèle diagnostic + ChatEntry | 66 | ~1.9 Ko | `fromAiJson` robuste |
| `lib/screens/home_ai_screen.dart` | Écran principal | 348 | ~12 Ko | **Déjà découpé** (home_ai/) |
| `lib/screens/setup_screen.dart` | Écran paramétrage | 284 | ~10.9 Ko | **À découper** (priorité #1) |
| `lib/services/rodium_ai_service.dart` | Client IA (via Functions) | 183 | ~7.2 Ko | Prompts système, parsing JSON |
| `functions/index.js` | Cloud Functions (Node) | 287 | ~11.6 Ko | aiProxy, aiSpeech, aiTranscribe, dailyWeatherRisk, notifyNewReport |
| `functions/weather_rules.js` | Règles météo (dupliquées) | 66 | ~2.3 Ko | Miroir de `weather_service.dart` |
| `lib/widgets/k_components.dart` | Design system | 98 | ~3 Ko | KCard, StatusChip, StatusBanner |

---

*Document mis à jour avec tailles réelles (lignes vs octets) et plan production réaliste. À versionner dans le repo.*