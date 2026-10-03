# KultivIA : Issues du projet

37 issues réparties en 5 lots (un lot par personne). Chaque issue est autonome : elle décrit ce qu'il faut construire, dans quels fichiers, avec les signatures et les règles, pour qu'on puisse la réaliser sans avoir vu l'ancien code.

## Note sur l'authentification

**Firebase est la seule source d'identité.** Les utilisateurs se connectent avec Firebase Auth, et tous les jetons de l'application sont des jetons Firebase.

Supabase (Postgres) est utilisé comme **réplique en lecture-écriture** de deux
collections Firestore, `users` et `diagnoses` : chaque écriture Firestore est
copiée par l'Edge Function `sync-write`, qui vérifie lui-même le jeton Firebase.
Aucune lecture de l'application ne va vers Supabase. Voir
[ARCHITECTURE.md](../ARCHITECTURE.md) pour le détail des règles de conflit.

`lib/services/auth/supabase_service.dart` existe mais n'est appelé par aucun
écran : il ne fait pas partie du chemin actif.

## Comment ça évite les conflits

Chaque fichier a un seul propriétaire (tableau ci-dessous). Personne ne modifie le fichier d'un autre lot : on commente l'issue de son propriétaire.
Les fichiers partagés sont réduits au minimum : pubspec.yaml et main.dart sont au lot A ; functions/index.js ne contient que des lignes de ré-export (chaque fonction a son propre fichier) ; le design system, les modèles et l'interface du repository sont gelés.
Les signatures sont des contrats : le squelette contient déjà chaque classe et méthode publique, donc chacun code contre les stubs des autres sans les attendre.
Pull request relue par une autre personne, une branche par issue (feature/a3-main).
Les ajouts de langues passent par un fichier par langue (issue D6) : c'est ce qui permet à chaque membre d'ajouter la sienne sans conflit.

## Propriété des fichiers

| Lot | Fichiers dont il est le seul propriétaire |
|-----|-------------------------------------------|
| A | pubspec.yaml, pubspec.lock, android/, ios/, firebase.json, .firebaserc, firestore.rules, firestore.indexes.json, functions/package.json, functions/index.js, lib/main.dart, lib/firebase_options.dart, lib/services/auth/, lib/screens/auth/, lib/screens/gate/, lib/screens/onboarding/, lib/repositories/conversation_repository.dart, lib/repositories/firebase_conversation_repository.dart, test/widget_test.dart, README.md, .github/ |
| B | lib/services/ai/, lib/screens/home_ai/, lib/screens/health/diagnosis_result_screen.dart, functions/src/aiProxy.js, test/rodium_ai_service_test.dart, test/avatar_intents_test.dart |
| C | lib/services/system/app_state.dart, lib/services/system/user_settings.dart, lib/services/system/connectivity_service.dart, lib/services/data/, lib/repositories/firebase_diagnosis_repository.dart, lib/screens/setup/, lib/screens/settings/, lib/screens/history/, lib/screens/health/health_dashboard_screen.dart, lib/widgets/app_drawer.dart, lib/widgets/offline_banner.dart, test/user_profile_test.dart, test/health_score_test.dart, test/conversation_history_test.dart |
| D | lib/services/ui/voice_service.dart, lib/screens/market/marketplace_screen.dart, lib/screens/community/, lib/languages/, lib/l10n/, functions/src/aiSpeech.js, functions/src/aiTranscribe.js, functions/src/notifyReport.js, test/voice_service_test.dart |
| E | lib/services/external/, lib/services/system/notification_service.dart, lib/screens/weather/, lib/screens/market/vendors_map_screen.dart, lib/data/vendors_seed.dart, functions/src/weatherAlerts.js, functions/src/weatherRules.js, test/weather_outlook_test.dart, test/vendor_links_test.dart |

**Fondation gelée** (personne n'y touche sans en parler) : lib/core/**, lib/models/**, lib/widgets/k_components.dart, lib/repositories/diagnosis_repository.dart : propriétaire = lot A. Pour un changement, ouvrir une issue « Demande de changement ».

## Ordre de travail

- **Phase 0**, d'abord, une seule personne (lot A) : A1, A2, A3, A4. Tant que ce n'est pas fait, personne ne peut lancer l'app, mais tout le monde peut déjà écrire son code contre les stubs.
- **Phase 1**, tous en parallèle : chaque lot travaille dans ses fichiers. Gros chemins critiques : B1 → B3, C1 → C2/C3/C4, E3 → E4/D4, D1 → D2.
- **Phase 2**, finitions : mode hors-ligne (C6), registre de langues (D6), traduction (D7), langues (F1), validations (D8, E7), recette (G1), publication (G2).

## Point d'étape phase 2 - 3 octobre 2026

Où en est la phase 2, et ce qui a été fait en dehors des issues listées plus bas.

### Travaux réalisés, hors périmètre des issues

- **Double écriture Firestore → Supabase** (`users`, `diagnoses`) -
  `lib/services/sync/supabase_mirror.dart`,
  `lib/repositories/mirrored_diagnosis_repository.dart`,
  `supabase/migrations/`, `supabase/functions/sync-write/`,
  `tools/backfill.mjs`. Fait : `SIMULTANEOUS_WRITES=true`, backfill passé,
  `sync_gap` vide.
- **Migration des fonctions IA de Firebase Cloud Functions vers Supabase Edge
  Functions** - `supabase/functions/ai-proxy/`, `ai-speech/`, `ai-transcribe/`,
  `_shared/rodium.ts`. Déployé et vérifié. `functions/` n'est plus utilisé.
- **Historique des discussions** (demandé par l'utilisateur) -
  `lib/models/conversation.dart`,
  `lib/repositories/conversation_repository.dart`,
  `lib/repositories/firebase_conversation_repository.dart`,
  `lib/services/data/conversation_history.dart`,
  `test/conversation_history_test.dart`. Fait le 3 octobre 2026.
- **Mode hors-ligne** (issue C6) - `lib/services/system/connectivity_service.dart`,
  `lib/widgets/offline_banner.dart`, `test/connectivity_service_test.dart`,
  plus la persistance Firestore dans `lib/main.dart`. Fait le 3 octobre 2026.
- **Partage WhatsApp d'un diagnostic** (issue B7) -
  `lib/services/external/share_links.dart`,
  `lib/screens/health/diagnosis_result_screen.dart`,
  `test/share_links_test.dart`. Fait le 3 octobre 2026.

### Bugs trouvés et corrigés

Ces bugs ne figuraient dans aucune issue. Ils sont apparus en faisant tourner
l'application, pas en relisant le code - c'est le meilleur argument pour faire
tourner l'application.

- **« Connexion requise » sur tous les appels IA.** `_accessToken()` ne lisait que
  la session Supabase, alors que les utilisateurs se connectent avec Firebase :
  le jeton était toujours nul et la requête partait sans jeton.
- **Vérification du jeton Firebase qui échouait silencieusement.** L'import de la
  clé JWK écrit à la main ne fonctionnait pas sur le runtime Deno de Supabase.
  Remplacé par `jose`, qui gère aussi la rotation des clés.
- **HTTP 401 sur le miroir.** `sync-write` manquait dans `supabase/config.toml` :
  `verify_jwt` valait `true` par défaut alors que la fonction vérifie le jeton
  elle-même.
- **JSON brut affiché à l'agriculteur.** Le fournisseur coupait la réponse en
  cours de génération (`finish_reason: length`) ; l'analyseur rejetait le JSON
  tronqué et laissait passer le texte brut. Corrigé des deux côtés.
- **Lingala cassé en production.** `functions/index.js` redéfinissait les fonctions
  en ligne au lieu de réexporter `src/`, et la copie inline n'autorisait que le
  wolof. Les tests passaient, la production non.

### Ce qui reste, et qui dépend d'un humain

- **D8, E7** - validation par des locuteurs natifs et un agronome : ce sont des
  personnes, pas du code.
- **G1** - recette sur les 13 écrans, en clair et en sombre.
- **G2** - comptes développeur, builds et soumission aux stores.
- **C6** - mode hors-ligne. La double écriture ne réplique pas le hors-ligne ;
  le défaut est documenté dans ARCHITECTURE.md.
- **B7** - **fait le 3 octobre 2026** (partage d'un diagnostic par WhatsApp).

## Dépendances entre lots (à connaître)

| Ton issue | Utilise | Donc |
|-----------|---------|------|
| B3 HomeAiScreen | B1, B4, B5, C1, D1 | coder contre les stubs, brancher à la fin |
| C2 Setup, C3 Profil | A4, C1, D1, E5 | idem |
| D4 Marketplace | E3 vendorTelUri / vendorWhatsAppUri | signatures déjà figées |
| D2 Voix cloud | B1, D3 | après D1 |
| E6 weatherAlerts | E5 (jeton), C2 (localité) | seuils identiques à E1 |

## Attribution des lots

| Lot | Responsable | GitHub Username | Description |
|-----|-------------|------------------|-------------|
| A | @madshinee | Fondation, Firebase et compte |
| B | @Katsuki2000 | IA, conversation, diagnostic |
| C | @MEKA-Marie | Données, profil, santé |
| D | @ParkerDieuveil | Voix, langues, marché, communauté |
| E | @TODO_GITHUB_USERNAME | Météo, points de vente, notifications |

**Remarque** : @madshinee a déjà commencé le Lot A (pubspec.yaml, main.dart, design system, stubs). Les autres lots sont à assigner.

---

## Lot A : Fondation, Firebase et compte

### [A1] Initialiser le projet Flutter, les dépendances et les réglages natifs

**Labels** : lot-a, phase-0, taille-M, bloquant · **Phase 0 - Fondation**

**Contexte**
Sans projet exécutable personne ne peut tester. Cette issue rend le squelette lançable sur émulateur. Tout le monde attend A1 pour tester : à faire en premier.

**Fichiers que tu modifies (et seulement ceux-là)**
- pubspec.yaml
- pubspec.lock
- analysis_options.yaml
- .gitignore
- android/**
- ios/**
- assets/images/

**À implémenter**
- Lancer `flutter create --platforms=android,ios --org com.kultivia .` à la racine du dépôt. Le nom du package dans pubspec.yaml doit être kultivia.
- Déclarer toutes les dépendances du projet dès maintenant : provider, firebase_core, firebase_auth, cloud_firestore, cloud_functions, firebase_messaging, google_sign_in, sign_in_with_apple, image_picker, geolocator, url_launcher, http, speech_to_text, flutter_tts, audioplayers, record, path_provider, connectivity_plus, flutter_localizations (sdk) et intl.
- Déclarer l'asset assets/images/logo.png.
- Android : minSdkVersion 23. Permissions dans AndroidManifest.xml : INTERNET, CAMERA, RECORD_AUDIO, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, POST_NOTIFICATIONS. Bloc <queries> pour url_launcher et pour la reconnaissance vocale.
- iOS : dans Info.plist, NSCameraUsageDescription, NSPhotoLibraryUsageDescription, NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription, NSLocationWhenInUseUsageDescription, et LSApplicationQueriesSchemes (whatsapp, tel). Activer Sign in with Apple et Push Notifications.

**Critères d'acceptation**
- [ ] flutter pub get et flutter analyze passent sans erreur
- [ ] flutter test passe (les tests non implémentés sont en skip)
- [ ] L'app se lance sur un émulateur Android
- [ ] Personne d'autre que le lot A n'a besoin de modifier pubspec.yaml

**Dépendances**
Aucune. Débloque tous les autres tests sur téléphone.

**Règles de travail**
Branche : feature/a1-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [A2] Firebase : projet, règles Firestore, index et squelette des Cloud Functions

**Labels** : lot-a, phase-0, taille-M, bloquant · **Phase 0 - Fondation**

**Contexte**
Toute l'app dépend de Firebase (auth, Firestore, notifications, Cloud Functions). Cette issue prépare le terrain.

**Fichiers que tu modifies (et seulement ceux-là)**
- firebase.json
- .firebaserc
- firestore.rules
- firestore.indexes.json
- functions/package.json
- functions/index.js
- functions/src/*.js (uniquement les stubs)
- lib/firebase_options.dart

**À implémenter**
- Créer le projet Firebase (plan Blaze pour Cloud Functions).
- Lancer flutterfire configure (génère lib/firebase_options.dart).
- Activer les fournisseurs d'authentification : Email/mot de passe, Google, Apple, Téléphone.
- Activer Cloud Messaging.
- functions/index.js ne contient QUE des ré-exports :
  ```javascript
  exports.aiProxy = require('./src/aiProxy').aiProxy;
  exports.aiSpeech = require('./src/aiSpeech').aiSpeech;
  exports.aiTranscribe = require('./src/aiTranscribe').aiTranscribe;
  exports.notifyReport = require('./src/notifyReport').notifyReport;
  exports.weatherAlerts = require('./src/weatherAlerts').weatherAlerts;
  ```
- Créer les 5 fichiers functions/src/*.js comme stubs qui lèvent HttpsError('unimplemented').
- Poser le secret : firebase functions:secrets:set RODIUMAI_API_KEY.
- Règles Firestore : users/{uid} et users/{uid}/diagnoses/{id} : lecture/écriture si request.auth.uid == uid. signalements/{id} : lecture pour connecté, création si authorId == request.auth.uid. marketplace/{id} : lecture pour connecté, création si sellerId == request.auth.uid. points_de_vente/{id} : lecture pour connecté, écriture interdite.
- Index : marketplace avec status (croissant) + createdAt (décroissant).

**Critères d'acceptation**
- [ ] firebase deploy --only firestore,functions réussit
- [ ] Un utilisateur non connecté ne peut rien lire ni écrire
- [ ] Chaque lot peut modifier son fichier de fonction sans toucher à functions/index.js

**Dépendances**
Débloque B2, D3, D5, E6 et l'auth réelle (A4).

**Règles de travail**
Branche : feature/a2-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [A3] main.dart : providers dans le bon ordre, routes nommées et thème

**Labels** : lot-a, phase-0, taille-S, bloquant · **Phase 0 - Fondation**

**Contexte**
main.dart est le fichier le plus partagé : seul le lot A le modifie. Bug connu à éviter : dans un MultiProvider, un provider ne peut lire que ceux déclarés au-dessus.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/main.dart

**À implémenter**
- Démarrage : WidgetsFlutterBinding.ensureInitialized(), Firebase.initializeApp() dans un try/catch.
- Activer la persistance Firestore (persistenceEnabled: true).
- Providers, dans cet ordre exact :
  1. ChangeNotifierProvider<UserSettings>
  2. Provider<FirebaseService>
  3. Provider<NotificationService>
  4. Provider<RodiumAiService>
  5. Provider<DiagnosisRepository> (FirebaseDiagnosisRepository)
  6. ChangeNotifierProvider<DiagnosisHistory>
  7. ChangeNotifierProvider<AppState>
  8. ChangeNotifierProvider<SetupController>
- MaterialApp : titre KultivIA, debugShowCheckedModeBanner: false, theme: KultivTheme.light(), darkTheme: KultivTheme.dark(), themeMode: ThemeMode.system, initialRoute: '/'.
- Routes nommées : / GateScreen, /onboarding OnboardingScreen, /auth AuthScreen, /setup SetupScreen, /language LanguageScreen, /home HomeAiScreen, /history HistoryScreen, /profile ProfileScreen, /vendors VendorsMapScreen, /weather WeatherAlertsScreen, /community CommunityScreen, /marketplace MarketplaceScreen, /health-dashboard HealthDashboardScreen.
- /result via onGenerateRoute : settings.arguments est un Diagnosis.
- builder: place OfflineBanner() au-dessus de l'écran courant.

**Critères d'acceptation**
- [ ] Toutes les routes ouvrent leur écran sans exception ProviderNotFoundException
- [ ] L'app démarre sans configuration Firebase (mode dégradé)
- [ ] Aucun autre lot n'a besoin de modifier main.dart

**Dépendances**
Dépend des stubs du squelette. Débloque le test de tous les écrans.

**Règles de travail**
Branche : feature/a3-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [A4] FirebaseService : authentification et profil utilisateur

**Labels** : lot-a, phase-0, taille-M, bloquant · **Phase 0 - Fondation**

**Contexte**
Service utilisé par presque tous les écrans. Son interface publique est le contrat : ne pas renommer les méthodes.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/services/auth/firebase_service.dart
- supprimer lib/services/auth/mock_auth_service.dart s'il existe

**À implémenter**
- Classe FirebaseService({FirebaseAuth? auth, FirebaseFirestore? firestore}).
- Interface publique :
  - bool get isReady : Firebase.apps.isNotEmpty
  - User? get currentUser, Stream<User?> get authState
  - Future<UserCredential> signInWithEmail(String email, String password)
  - Future<UserCredential> registerWithEmail(String email, String password)
  - Future<UserCredential> signInWithGoogle() (lève FirebaseAuthException(code: 'cancelled') si annulé)
  - Future<UserCredential> signInWithApple()
  - verifyPhoneNumber({required String phoneNumber, required void Function(String) onCodeSent, required void Function(FirebaseAuthException) onError})
  - confirmPhoneCode({required String verificationId, required String smsCode})
  - Future<void> signOut()
  - Future<UserProfile?> fetchProfile()
  - Future<void> saveProfile(UserProfile profile)
  - Future<List<Map<String, dynamic>>> fetchNearbyVendors()
- **Important** : ne PAS inclure saveDiagnosis et watchDiagnoses (c'est le rôle du DiagnosisRepository).

**Critères d'acceptation**
- [ ] Test unitaire avec des faux FirebaseAuth/FirebaseFirestore
- [ ] signInWithGoogle annulé lève l'exception cancelled
- [ ] Aucune référence à MockAuthService
- [ ] flutter analyze sans erreur

**Dépendances**
Dépend de A2 pour tester en réel. Débloque A5, A6, C2, C3, E4.

**Règles de travail**
Branche : feature/a4-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [A5] AuthScreen : connexion et inscription (email, Google, Apple, téléphone)

**Labels** : lot-a, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Écran de connexion présenté après l'onboarding. Il utilise uniquement FirebaseService (A4).

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/auth/auth_screen.dart

**À implémenter**
- Titre KultivIA et logo en haut.
- Formulaire email + mot de passe avec bouton principal (connexion/inscription).
- Séparateur « ou », puis 3 boutons : Google, Apple (iOS uniquement), Téléphone.
- Flux téléphone : boîte de dialogue numéro, puis code SMS.
- Après succès : Navigator.pushNamedAndRemoveUntil('/', (r) => false).
- Erreurs : SnackBar en français (user-not-found, wrong-password, invalid-credential, email-already-in-use, weak-password, invalid-email, network-request-failed, invalid-verification-code, cancelled).
- Si !FirebaseService.isReady : bandeau « Connexion indisponible : Firebase n'est pas configuré. »

**Critères d'acceptation**
- [ ] Les 4 méthodes de connexion fonctionnent sur un vrai téléphone
- [ ] Chaque code d'erreur produit un message français lisible
- [ ] Après connexion l'utilisateur arrive au GateScreen puis au bon écran

**Dépendances**
Dépend de A1-A4.

**Règles de travail**
Branche : feature/a5-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [A6] GateScreen (routage au démarrage) et OnboardingScreen

**Labels** : lot-a, phase-1, taille-S · **Phase 1 - Fonctionnalités**

**Contexte**
Premiers écrans vus par l'utilisateur. Le Gate décide où l'envoyer selon son état.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/gate/gate_screen.dart
- lib/screens/onboarding/onboarding_screen.dart
- test/widget_test.dart

**À implémenter**
- GateScreen (route /) :
  - Au premier frame, lire FirebaseService.currentUser :
    - non connecté : accueil avec logo + bouton « Commencer » → /onboarding
    - connecté : fetchProfile()
      - profil existe et completed == true : AppState.setProfile(profile), AppState.bindHistory(), pushReplacementNamed('/home')
      - sinon : pushReplacementNamed('/setup')
    - exception réseau : pushReplacementNamed('/home')
  - Toujours tester mounted avant de naviguer.
- OnboardingScreen (route /onboarding) :
  - PageView de 3 diapositives : « Vos cultures, en bonne santé », « Un diagnostic en une photo », « Toujours prévenu ».
  - Indicateurs de page et bouton « Suivant » qui devient « Commencer » sur la dernière page.
  - « Commencer » ouvre /auth avec pushReplacementNamed.
- Test : mettre à jour test/widget_test.dart.

**Critères d'acceptation**
- [ ] Non connecté : accueil puis onboarding puis auth
- [ ] Connecté avec profil complet : arrive directement sur /home
- [ ] Connecté sans profil : arrive sur /setup
- [ ] flutter test test/widget_test.dart passe

**Dépendances**
Dépend de A3, A4. Le test de bout en bout demande C1.

**Règles de travail**
Branche : feature/a6-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [G1] Essai complet sur téléphone : les 13 écrans en clair et en sombre

**Labels** : lot-a, phase-2, taille-M, qualité · **Phase 2 - Finitions**

**Contexte**
Le code n'a jamais été validé sur un vrai téléphone. Cette issue est la recette finale.

**Fichiers que tu modifies (et seulement ceux-là)**
- aucun (corrections ouvertes en issues dans les lots concernés)

**À implémenter**
Parcourir sur un vrai téléphone Android (et iOS si disponible), thèmes clair puis sombre :
- onboarding, inscription, déconnexion, reconnexion (email, Google, téléphone, Apple sur iOS)
- paramétrage complet, modification du profil, changement de langue
- conversation texte, photo (caméra et galerie), diagnostic par texte, diagnostic par photo, écran de résultat, historique
- voix : dicter, réponse lue, réponses parlées en continu, langue choisie à l'oreille
- météo, points de vente (appel, WhatsApp, itinéraire), communauté, marketplace, score de santé
- mode avion, notification reçue, refus de chaque permission

Ouvrir une issue de bug par problème, avec capture d'écran, étiquetée du lot concerné.

**Critères d'acceptation**
- [ ] Liste de recette complétée dans l'issue
- [ ] Tous les bugs bloquants ouverts sont corrigés

**Dépendances**
Dépend de toutes les issues de phase 1. Phase 2.

**Règles de travail**
Branche : feature/g1-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [G2] Publication : comptes développeur, builds et soumission aux stores

**Labels** : lot-a, phase-2, taille-M, publication · **Phase 2 - Finitions**

**Contexte**
À faire quand les validations (D8, E7, G1) sont terminées.

**Fichiers que tu modifies (et seulement ceux-là)**
- android/app/build.gradle
- ios/Runner.xcodeproj
- README.md

**À implémenter**
- Créer les comptes Google Play Console et Apple Developer.
- Signature Android (keystore non commité), flutter build appbundle --release.
- iOS : profil de provisionnement, flutter build ipa.
- Fiche de la boutique : description simple, captures d'écran, politique de confidentialité.
- Vérifier que firestore.rules est en mode production et que la clé RodiumAI n'est que dans les secrets Firebase.

**Critères d'acceptation**
- [ ] Build de production installé et testé sur un téléphone
- [ ] Fiches boutiques prêtes

**Dépendances**
Dépend de G1. Phase 2.

**Règles de travail**
Branche : feature/g2-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

## Lot B : IA, conversation et diagnostic

### [B1] RodiumAiService : diagnostic (photo, texte) et chat avec l'avatar

**Labels** : lot-b, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Toute l'intelligence de l'app passe par cette classe. Elle n'appelle jamais RodiumAI directement : uniquement les Cloud Functions aiProxy, aiSpeech, aiTranscribe.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/services/ai/rodium_ai_service.dart
- test/rodium_ai_service_test.dart

**À implémenter**
- Classe RodiumAiService({FirebaseFunctions? functions}).
- Méthodes publiques (contrat) :
  - Future<Map<String, dynamic>> diagnoseFromImage({required File imageFile, String description = '', String languageCode = 'fr'})
  - Future<Map<String, dynamic>> diagnoseFromText({required String description, String languageCode = 'fr'})
  - Future<String> chatWithAvatar({required List<Map<String,String>> history, String languageCode = 'fr'})
  - Future<Uint8List> synthesizeSpeech({required String text, String languageCode = 'fr'})
  - Future<String> transcribeAudio({required Uint8List bytes, String mime = 'audio/mp4', String languageCode = 'fr'})
- Fonction de module : Map<String, dynamic> parseAiJsonResponse(String raw).
- Appel du proxy (méthode privée _callProxy) : httpsCallable('aiProxy').call({messages, temperature, maxTokens, language}).
- parseAiJsonResponse : retire les balises ```json et ```, jsonDecode. Si le résultat est une Map, la renvoyer. Si c'est un autre type JSON, renvoyer {'reponse_avatar': raw}. Si le JSON est invalide, renvoyer {'reponse_avatar': raw, 'maladie': 'Indéterminé', 'confiance': 0.0}.
- Prompt de diagnostic : impose de répondre uniquement par un objet JSON avec les clés maladie, confiance, traitement, reponse_avatar.
- Prompt de chat : avatar de KultivIA, 3 phrases simples et chaleureuses au maximum, sans markdown.
- Consigne de style parlé : phrases courtes, mots simples, pas de symboles, pas de listes, pas de markdown, pas d'émoji, unités en toutes lettres.

**Critères d'acceptation**
- [ ] Tests unitaires de parseAiJsonResponse : JSON propre, JSON entouré de balises markdown, texte libre, JSON invalide, tableau JSON
- [ ] Test avec un faux FirebaseFunctions : diagnoseFromText envoie bien le message system puis le message user
- [ ] Aucune clé API ni URL RodiumAI dans le code de l'app

**Dépendances**
Dépend de B2 pour le test réel. Débloque B3, D2.

**Règles de travail**
Branche : feature/b1-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [B2] Cloud Function aiProxy : relais sécurisé vers RodiumAI

**Labels** : lot-b, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Fonction appelable (onCall) qui garde la clé RodiumAI côté serveur.

**Fichiers que tu modifies (et seulement ceux-là)**
- functions/src/aiProxy.js
- functions/test/aiProxy.test.js

**À implémenter**
- Contrat : entrée { messages: [...], temperature?: number, maxTokens?: number, language?: string }, sortie { content: "<texte de la réponse>" }.
- Utiliser le secret RODIUMAI_API_KEY (defineSecret).
- URL de base et modèle de vision/chat lus dans des variables d'environnement (RODIUMAI_BASE_URL, RODIUMAI_CHAT_MODEL).
- Refuser (HttpsError('unauthenticated')) si request.auth est vide.
- Valider l'entrée (HttpsError('invalid-argument')) : messages est un tableau non vide de 20 éléments maximum ; temperature entre 0 et 1 ; maxTokens entre 1 et 800 ; une image data: ne dépasse pas ~5 Mo.
- Timeout 60 s, mémoire 512 Mo. Ne jamais journaliser le contenu des messages ni les images.
- Erreur du fournisseur : HttpsError('internal', 'Service IA indisponible').

**Critères d'acceptation**
- [ ] Appel sans être connecté : unauthenticated
- [ ] Appel valide (avec la vraie clé) : renvoie un texte
- [ ] Entrée invalide (0 message, 50 messages, image géante) : invalid-argument
- [ ] La clé n'apparaît nulle part dans le dépôt

**Dépendances**
Dépend de A2. Débloque le test réel de B1, B3.

**Règles de travail**
Branche : feature/b2-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [B3] HomeAiScreen : écran principal de conversation avec l'avatar

**Labels** : lot-b, phase-1, taille-L · **Phase 1 - Fonctionnalités**

**Contexte**
Écran principal (route /home). Il porte l'état et la logique de la conversation.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/home_ai/home_ai_screen.dart

**À implémenter**
- État : List<ChatEntry> _messages, String? _pendingImagePath, bool _thinking, bool _listening, TextEditingController, ScrollController, VoiceService(), ImagePicker.
- Barre du haut : titre « KultivIA » ; bouton haut-parleur qui inverse AppState.setVoiceReplies ; bouton « Nouvelle conversation » ; drawer: AppDrawer(onNewChat: _newChat).
- Corps : si aucun message, EmptyState ; sinon ListView des MessageView (+ TypingDots pendant _thinking) ; en bas le Composer.
- Choix d'une photo : ImagePicker.pickImage(source, imageQuality: 80, maxWidth: 1280).
- Envoi (_send) :
  - Si pas d'image ET looksLikeCameraRequest(text) : ajouter message utilisateur + réponse cameraReply(langue), puis ouvrir la caméra.
  - Sinon ajouter message utilisateur (avec l'image), _thinking = true.
  - Diagnostic si une image est jointe OU si le texte contient « diagnosti » : appeler diagnoseFromImage ou diagnoseFromText ; construire Diagnosis.fromAiJson ; AppState.addDiagnosis ; DiagnosisRepository.saveDiagnosis.
  - Chat sinon : historique = les 12 derniers messages puis chatWithAvatar.
  - Erreur : message « Je n'ai pas pu joindre l'IA. Vérifiez votre connexion, puis réessayez. »
- Voix : _maybeSpeak(texte, viaVoice) lit la réponse si la question était orale OU si AppState.voiceReplies est actif.
- Micro : _toggleListening : si on écoute déjà, arrêter ; sinon arrêter la voix, listenOnce(languageCode), et si un texte est reconnu le mettre dans le champ et appeler _send(viaVoice: true).
- Notifications au premier plan : s'abonner à NotificationService.foregroundTexts et afficher chaque texte dans un SnackBar.

**Critères d'acceptation**
- [ ] Conversation texte : question puis réponse de l'avatar
- [ ] Photo + envoi : diagnostic avec carte cliquable vers /result
- [ ] Écrire « diagnostiquer » après une description : diagnostic sur les symptômes cumulés
- [ ] Écrire « photo » ou « caméra » ouvre l'appareil photo sans appeler l'IA
- [ ] Micro : la question dite à voix haute reçoit une réponse lue
- [ ] Coupure réseau : message d'erreur, pas de crash

**Dépendances**
Dépend de B1, B4, B5, D1 et C1. Peut être développé contre les stubs avant.

**Règles de travail**
Branche : feature/b3-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [B4] Widgets de conversation : Composer, EmptyState, MessageView, TypingDots, feuille de pièce jointe

**Labels** : lot-b, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Composants visuels utilisés par B3. Ils ne contiennent aucune logique métier.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/home_ai/composer.dart
- lib/screens/home_ai/empty_state.dart
- lib/screens/home_ai/message_view.dart
- lib/screens/home_ai/typing_dots.dart

**À implémenter**
- Composer : paramètres controller, imagePath, listening, canSend, thinking, onAttach, onRemoveImage, onMic, onSend. Champ arrondi, indication « Décrivez le problème de votre culture… », bouton « + », miniature de l'image avec croix, bouton micro, bouton envoyer.
- showAttachSheet(BuildContext context, {required VoidCallback onCamera, required VoidCallback onGallery}) : feuille modale avec « Appareil photo » et « Galerie ».
- EmptyState : paramètres name, listening, onMic, onCamera, onPrompt, onWeather. Contenu : « Bonjour » ou « Bonjour, {name} », sous-titre « Que voulez-vous vérifier aujourd'hui ? », gros bouton micro central, trois suggestions.
- MessageView : paramètres entry, onCopy, onSpeak. Message de l'utilisateur : bulle arrondie, image en miniature si entry.imagePath != null. Message de l'avatar : sans bulle, SelectableText, puis ligne d'actions (icône, bouton copier, bouton haut-parleur). Si entry.diagnosis != null : carte cliquable qui ouvre Navigator.pushNamed('/result', arguments: diagnosis).
- TypingDots : trois points animés en boucle.

**Critères d'acceptation**
- [ ] Chaque widget s'affiche correctement en clair et en sombre
- [ ] Les signatures correspondent exactement à celles décrites
- [ ] Petit écran (320 px) : aucun débordement
- [ ] Test widget : MessageView avec un Diagnosis affiche la carte et navigue vers /result

**Dépendances**
Aucune dépendance bloquante. Débloque B3.

**Règles de travail**
Branche : feature/b4-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [B5] AvatarIntents : l'avatar comprend « photo » / « caméra » sans appeler l'IA

**Labels** : lot-b, phase-1, taille-S · **Phase 1 - Fonctionnalités**

**Contexte**
Fonctions pures et testables. Elles évitent un appel IA quand l'utilisateur demande simplement d'ouvrir l'appareil photo.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/services/ai/avatar_intents.dart
- test/avatar_intents_test.dart

**À implémenter**
- bool looksLikeCameraRequest(String text) : vrai si le texte contient un des mots photo, photos, foto, caméra / camera, kamera, nataal, picture(s) comme mot entier (insensible à la casse, avec les lettres accentuées Unicode). « photosynthèse » ne doit PAS déclencher.
- String cameraReply(String languageCode) : phrase dite avant d'ouvrir l'appareil.
  - fr (défaut) : « D'accord, j'ouvre l'appareil photo. Prenez la feuille ou la plante malade en photo. »
  - en : « Okay, opening the camera. Take a picture of the sick leaf or plant. »
  - wo : « Waaw, dinaa ubbi kamera bi. Jël foto ci xob wi. »

**Critères d'acceptation**
- [ ] Tests : « photo », « Photo ! », « je veux une foto », « caméra » : vrai ; « photosynthèse », « telephoto » : faux
- [ ] cameraReply renvoie la bonne phrase pour fr, en, wo et le français pour un code inconnu

**Dépendances**
Aucune. Débloque B3.

**Règles de travail**
Branche : feature/b5-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [B6] DiagnosisResultScreen : résultat du diagnostic et actions

**Labels** : lot-b, phase-1, taille-S · **Phase 1 - Fonctionnalités**

**Contexte**
Écran ouvert par pushNamed('/result', arguments: diagnosis).

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/health/diagnosis_result_screen.dart

**À implémenter**
- Écran DiagnosisResultScreen({required Diagnosis diagnosis}), titre « Résultat du diagnostic ».
- Photo (si imagePath != null et le fichier existe : hauteur 220, BoxFit.cover, coins arrondis).
- Nom de la maladie en grand et en gras.
- Pastille StatusChip « Confiance : {n} % » avec la couleur KultivTheme.status(context).forConfidence(confidence).
- Carte « Traitement conseillé » avec diagnosis.advice.
- Bouton « Écouter le conseil » : VoiceService().speak(advice ou, à défaut, la maladie, languageCode: langue de AppState).
- Section « Aller plus loin » : cinq lignes cliquables (KCard + ListTile + chevron) :
  - « Points de vente d'intrants à proximité » : pushNamed('/vendors')
  - « Alertes météo pour cette maladie » : pushNamed('/weather')
  - « Signalements proches de chez vous » : ouvre CommunityScreen(prefillDisease: diagnosis.disease)
  - « Vendre ma récolte » : ouvre MarketplaceScreen
  - « Score de santé de l'exploitation » : ouvre HealthDashboardScreen

**Critères d'acceptation**
- [ ] Résultat sans photo, sans conseil, confiance 0 % et 100 % : affichage correct
- [ ] Chaque ligne d'action ouvre le bon écran ; la maladie est pré-remplie dans la communauté
- [ ] Le bouton d'écoute lit le conseil

**Dépendances**
Dépend de D1 (voix) pour le bouton d'écoute.

**Règles de travail**
Branche : feature/b6-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [B7] (Optionnel) Partager un diagnostic par WhatsApp - **FAIT le 3 octobre 2026**

**Labels** : lot-b, phase-2, taille-S, optionnel · **Phase 2 - Finitions**

**Contexte**
Les agriculteurs partagent beaucoup par WhatsApp. Idée à faire si le temps le permet.

**Fichiers réellement modifiés**
- lib/services/external/share_links.dart (nouveau)
- lib/screens/health/diagnosis_result_screen.dart
- test/share_links_test.dart (nouveau, 16 tests)

**Ce qui a été fait**
- `diagnosisShareText(d)` construit le message, `diagnosisWhatsAppUri(d)` le
  lien. Deux fonctions pures dans `services/external/`, sur le modèle de
  `vendor_links.dart` : testables sans téléphone et sans plugin, et
  `url_launcher` était déjà une dépendance - **aucune dépendance ajoutée**.
- Le bouton est placé avec les autres actions sur le résultat, pas dans
  « Aller plus loin » : ce n'est pas une navigation, c'est transmettre le
  diagnostic qu'on vient d'obtenir.
- Échec d'ouverture ⇒ `SnackBar`, jamais une exception. `url_launcher` lève
  si aucun navigateur ne sait traiter le lien, et le paysan doit apprendre
  l'échec.

**Écarts assumés avec l'énoncé**
- La troncature du traitement n'était pas demandée. Elle est nécessaire : l'IA
  peut répondre sur un paragraphe entier, et un message de 2 000 caractères
  n'est plus partageable dans une discussion de groupe. Bornes : maladie 120,
  traitement 600 ⇒ total < 900 caractères, très sous le plafond de 4 096 de
  WhatsApp. Un test verrouille cet invariant.
- **Pas de date** dans le message. Le paysan partage le diagnostic du jour, et
  un format de date devrait être traduit (issue D7).
- Le message reste en français, comme le reste de l'interface aujourd'hui.
  C'est **volontaire** : B7 est traitée avant D7 précisément pour que D7
  extraie ces chaînes une seule fois, avec le reste.

**Critères d'acceptation**
- [x] Le message s'ouvre dans WhatsApp avec le bon texte - *le texte et le lien sont couverts par 16 tests ; l'ouverture réelle reste à confirmer sur appareil*

**Vérifications**
- `flutter analyze` : 0 erreur, 41 issues préexistantes (inchangé)
- `flutter test` : 139 passent, 1 ignoré

**Dépendances**
Dépend de B6. Optionnel.

**Règles de travail**
Branche : feature/b7-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

## Lot C : Données, profil et santé

### [C1] DiagnosisRepository : sauvegarde et lecture des diagnostics

**Labels** : lot-c, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Le repository centralise la persistance des diagnostics. L'interface est déjà définie (gelée), cette issue implémente FirebaseDiagnosisRepository.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/repositories/firebase_diagnosis_repository.dart
- lib/services/data/diagnosis_history.dart
- test/user_profile_test.dart

**À implémenter**
- FirebaseDiagnosisRepository : implémenter saveDiagnosis, watchDiagnoses, deleteDiagnosis, dispose.
- saveDiagnosis : set en merge dans users/{uid}/diagnoses/{id} avec createdAt: FieldValue.serverTimestamp().
- watchDiagnoses : stream trié par createdAt décroissant, vide si non connecté.
- deleteDiagnosis : supprime le document.
- DiagnosisHistory : implémenter addDiagnosis, bindHistory, removeDiagnosis, clear, dispose.
- bindHistory : s'abonne au stream du repository et met à jour _history.

**Critères d'acceptation**
- [ ] Test : saveDiagnosis puis watchDiagnoses rendent le même diagnostic
- [ ] deleteDiagnosis retire le diagnostic de l'historique
- [ ] flutter analyze sans erreur

**Dépendances**
Aucune. Débloque C2, C3, C4, B3.

**Règles de travail**
Branche : feature/c1-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [C2] SetupScreen et SetupController : configuration initiale du profil

**Labels** : lot-c, phase-1, taille-L · **Phase 1 - Fonctionnalités**

**Contexte**
Écran de configuration en 3 étapes après l'inscription. C'est le seul endroit où l'utilisateur peut créer son profil.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/setup/setup_screen.dart
- lib/screens/setup/setup_controller.dart
- lib/screens/setup/step_identity.dart
- lib/screens/setup/step_exploitation.dart
- lib/screens/setup/step_preferences.dart
- lib/screens/setup/setup_bottom_bar.dart

**À implémenter**
- SetupController : état (currentStep, profil partiel), validation de chaque étape, méthode submit() qui appelle FirebaseService.saveProfile puis AppState.setProfile et AppState.bindHistory.
- SetupScreen : PageView avec 3 étapes, SetupBottomBar en bas.
- StepIdentity : formulaire nom + rôle (sélecteur : agriculteur, conseiller, chercheur, autre).
- StepExploitation : localité (champ texte), cultures (liste de tags avec bouton +).
- StepPreferences : langue (sélecteur UserSettings.supportedLanguages), notifications (interrupteur), voix (interrupteur).
- SetupBottomBar : bouton « Précédent » (désactivé étape 1), « Suivant » (désactivé si invalide), « Terminer » (étape 3).
- À la soumission : FirebaseService.saveProfile, NotificationService.enable(uid) si notifications activé, puis pushReplacementNamed('/home').

**Critères d'acceptation**
- [ ] Les 3 étapes s'enchaînent correctement
- [ ] Validation : bouton « Suivant » désactivé si champ vide
- [ ] Profil sauvegardé dans Firestore avec completed: true
- [ ] Notifications activées si l'interrupteur est on

**Dépendances**
Dépend de A4, C1, D1, E5.

**Règles de travail**
Branche : feature/c2-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [C3] ProfileScreen et LanguageScreen : modification du profil et de la langue

**Labels** : lot-c, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Écrans de modification du profil (/profile) et de la langue (/language).

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/settings/profile_screen.dart
- lib/screens/settings/language_screen.dart

**À implémenter**
- ProfileScreen (titre « Profil ») :
  - Pastille avec l'initiale du nom, nom en titre, sous-titre : libellé du rôle et localité.
  - Ligne « Modifier mon profil » : pushNamed('/setup').
  - Ligne « Langue » (sous-titre : nom de la langue courante) : pushNamed('/language').
  - Interrupteur « Notifications » : à l'activation, NotificationService.enable(uid) ; à la désactivation, disable(). Mettre à jour le profil.
  - Ligne « Déconnexion » : FirebaseService.signOut(), AppState.clear(), puis pushNamedAndRemoveUntil('/auth', (r) => false).
- LanguageScreen (titre « Langue ») :
  - Liste des langues de UserSettings.supportedLanguages, une sélection possible (radio).
  - Chaque ligne a un bouton haut-parleur qui lit VoiceService().speak(VoiceService.greetings[code], languageCode: code).
  - Au choix : AppState.setLanguage(code) et enregistrement du profil sans bloquer.
  - Petit texte d'aide et bouton « Terminer » qui ferme l'écran.

**Critères d'acceptation**
- [ ] Changer de langue met à jour l'écran et persiste au redémarrage
- [ ] Déconnexion : retour à /auth, plus aucune donnée de l'ancien compte visible
- [ ] Refus de notification géré sans crash

**Dépendances**
Dépend de A4, C1, E5, D1.

**Règles de travail**
Branche : feature/c3-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [C4] HistoryScreen et HealthDashboardScreen (score de santé)

**Labels** : lot-c, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Deux écrans qui lisent AppState.historyList, sans aucun appel réseau supplémentaire.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/history/history_screen.dart
- lib/screens/health/health_dashboard_screen.dart
- test/health_score_test.dart

**À implémenter**
- HistoryScreen (route /history, titre « Historique des diagnostics ») :
  - Liste des diagnostics (plus récents en premier) : titre = maladie, sous-titre = jj/m/aaaa · confiance N% ; toucher ouvre pushNamed('/result', arguments: diagnostic).
  - Liste vide : « Aucun diagnostic pour le moment. »
  - Bonus : glisser pour supprimer avec confirmation.
- HealthDashboardScreen (route /health-dashboard, titre « Score de santé de l'exploitation ») :
  - Extraire le calcul dans une fonction pure testable (computeHealthScore).
  - Règle : un diagnostic est « sain » si la maladie contient « indéterminé » OU si la confiance est < 0.3 ; les autres sont « malades ». score = 100 × (1 − malades / total) arrondi, et 100 s'il n'y a aucun diagnostic.
  - Libellé du score : ≥ 80 « Bon état », ≥ 50 « À surveiller », sinon « Critique ».
  - Carte principale : « {score} / 100 », pastille du libellé, texte « {total} diagnostic(s) au total, dont {malades} avec une maladie identifiée ».
  - Section « Maladies les plus fréquentes » : les 5 maladies (confiance ≥ 0.3) les plus fréquentes avec leur nombre.
  - Aucun diagnostic : « Pas encore de diagnostic enregistré. »

**Critères d'acceptation**
- [ ] Tests de computeHealthScore : liste vide (100), tous sains (100), tous malades (0), mélange, seuil de confiance 0.3
- [ ] L'historique se met à jour sans recharger l'écran
- [ ] Thèmes clair et sombre

**Dépendances**
Dépend de C1.

**Règles de travail**
Branche : feature/c4-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [C5] AppDrawer : menu latéral

**Labels** : lot-c, phase-1, taille-S · **Phase 1 - Fonctionnalités**

**Contexte**
Menu latéral de l'écran principal. Point d'entrée vers toutes les fonctionnalités.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/widgets/app_drawer.dart

**À implémenter**
- AppDrawer({required VoidCallback onNewChat}).
- En-tête : logo/icône et nom KultivIA.
- Entrées, dans cet ordre (icône + libellé, ferme le menu puis pushNamed) :
  - « Nouvelle conversation » (appelle onNewChat et ferme le menu)
  - « Historique » /history
  - « Santé de l'exploitation » /health-dashboard
  - « Alertes météo » /weather
  - « Points de vente d'intrants » /vendors
  - « Communauté » /community
  - « Marketplace » /marketplace
- Pied de menu : pastille avec l'initiale, nom (ou « Mon profil »), localité en sous-titre ; toucher ouvre /profile.

**Critères d'acceptation**
- [ ] Chaque entrée ouvre le bon écran
- [ ] Le nom et la localité viennent de AppState.profile
- [ ] Thèmes clair et sombre

**Dépendances**
Dépend de A3 (routes).

**Règles de travail**
Branche : feature/c5-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [C6] Mode hors-ligne : bandeau de connexion et données en cache - **FAIT le 3 octobre 2026**

**Labels** : lot-c, phase-2, taille-M, hors-ligne · **Phase 2 - Finitions**

**Contexte**
Les agriculteurs ont souvent une connexion instable. L'app doit rester utilisable pour consulter ses derniers diagnostics.

**Fichiers réellement modifiés**
- pubspec.yaml (ajout de `connectivity_plus: ^6.1.0`)
- lib/services/system/connectivity_service.dart (nouveau)
- lib/widgets/offline_banner.dart (nouveau)
- lib/main.dart (persistance Firestore, provider, `MaterialApp.builder`)
- lib/services/data/diagnosis_history.dart (`onError` + `bindHistory` idempotent)
- lib/screens/history/history_screen.dart (état « hors ligne » distinct de « vide »)
- test/connectivity_service_test.dart (nouveau, 12 tests)

> La liste de fichiers prévue par l'issue était incomplète : sans `pubspec.yaml`
> et `main.dart` (où poser la persistance et le `builder`), le bandeau n'a nulle part
> où vivre. Aucune modification d'`AndroidManifest.xml` n'a été nécessaire,
> `connectivity_plus` déclarant lui-même `ACCESS_NETWORK_STATE`.

**Ce qui a été fait**
- `ConnectivityService` est un `ChangeNotifier` (et non un `Stream<bool>`) :
  le bandeau n'a ainsi qu'un `context.select` à écrire. `isKnown` distingue
  « pas encore lu » de « hors connexion », ce qui évite un clignotement au
  démarrage. L'état initial est optimiste : un échec de lecture ne déclare
  pas de panne.
- `OfflineHost` enveloppe le `Navigator` via `MaterialApp.builder` : les 13
  routes sont couvertes sans qu'un écran ait à importer le bandeau. Les
  couleurs viennent du jeton `KStatus.warning`, jamais en dur.
- `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true)`
  posé dans `main()`. **L'issue affirmait que c'était déjà fait (A3) : c'était
  faux**, et c'était le point bloquant - sans lui le cache reste vide et le
  mode avion ne sert à rien.
- `DiagnosisHistory.bindHistory` absorbe les erreurs de flux sans vider
  l'historique affiché, et annule l'abonnement précédent (idempotent).
- `HistoryScreen` ne dit plus « aucun diagnostic » quand il ne sait simplement
  pas encore (hors connexion) : mentir au paysan sur son propre travail est
  le pire des deux mondes.

**Écart assumé avec l'énoncé**
L'issue demande `Stream<bool> onlineChanges`. C'est l'API de
`connectivity_plus` v3-v5 ; depuis la **v6** le flux émet
`Stream<List<ConnectivityResult>>` (un téléphone peut être en WiFi et en 4G
simultanément). L'énoncé ne compilait donc pas tel quel.

**Critères d'acceptation**
- [x] Mode avion : bandeau visible, historique consultable - *vérifié sur appareil par le mainteneur, à confirmer*
- [x] Retour du réseau : bandeau disparaît sans redémarrer - *couvert par test automatisé*

**Vérifications**
- `flutter analyze` : 0 erreur, 41 issues préexistantes (inchangé)
- `flutter test` : 123 passent, 1 ignoré

**Dépendances**
Dépend de A3, C1, C4. Phase 2.

---

## Lot D : Voix, langues, marché et communauté

### [D1] VoiceService (1/2) : écoute et voix avec les moteurs du téléphone

**Labels** : lot-d, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
L'avatar écoute et parle pour les utilisateurs qui ne savent pas lire. Cette issue fait le socle du service pour le français et l'anglais (moteurs gratuits du téléphone).

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/services/ui/voice_service.dart
- test/voice_service_test.dart

**À implémenter**
- Singleton : factory VoiceService() => _instance.
- Constantes et fonctions publiques :
  - const maxSpeechChars = 600.
  - String prepareSpeechText(String text) : remplace les caractères markdown, réduit les espaces multiples, trim ; si le texte dépasse 600 caractères, le couper à la dernière fin de phrase située avant 600 si elle est après le caractère 200.
  - static const greetings = {'fr': 'Bonjour, je suis Kultivia. Je vous aide à soigner vos cultures.', 'en': "Hello, I'm Kultivia. I help you take care of your crops.", 'wo': 'Nanga def ! Maa ngi tudd Kultivia. Dinaa la dimbali ci sa toolu.'}
  - static const cloudLanguages = {'wo'}
- Méthodes publiques (contrat) :
  - Future<String?> listenOnce({String languageCode = 'fr'}) : renvoie ce que l'utilisateur a dit, ou null si rien n'est compris. Locale en_US pour en, fr_FR sinon.
  - Future<void> stopListening().
  - bool get isListening.
  - Future<void> speak(String text, {String languageCode = 'fr'}) : nettoie avec prepareSpeechText, ne fait rien si vide, arrête la voix en cours, puis lit avec flutter_tts (langue en-US ou fr-FR, vitesse 0.45).
  - Future<void> stopSpeaking() : arrête flutter_tts et le lecteur audio.

**Critères d'acceptation**
- [ ] Tests de prepareSpeechText : markdown retiré, texte long coupé proprement, texte vide
- [ ] Sur téléphone : « bonjour » dit au micro est reconnu ; une réponse est lue en français puis en anglais
- [ ] speak pendant une lecture remplace la lecture en cours

**Dépendances**
Dépend de A1 (permissions). Débloque B3, B6, C2, C3.

**Règles de travail**
Branche : feature/d1-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [D2] VoiceService (2/2) : langues locales (wolof) via RodiumAI, avec repli

**Labels** : lot-d, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Le téléphone ne sait ni écouter ni parler wolof. Pour les langues de cloudLanguages, on passe par les Cloud Functions aiTranscribe et aiSpeech.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/services/ui/voice_service.dart (même fichier que D1)

**À implémenter**
- Écoute cloud (listenOnce pour une langue de cloudLanguages) : vérifier la permission du micro (record), enregistrer dans un fichier temporaire .m4a. Boucle toutes les 200 ms : lire l'amplitude ; on considère que l'utilisateur parle quand amp.current > -35 ; fin après 1,6 s de silence suivant la parole, ou 20 s maximum. Si aucune parole n'a été entendue : null. Sinon envoyer les octets à RodiumAiService.transcribeAudio(mime: 'audio/mp4') et renvoyer le texte nettoyé. Toujours supprimer le fichier temporaire.
- Voix cloud (speak) : RodiumAiService.synthesizeSpeech renvoie des octets mp3 ; les jouer avec audioplayers et attendre la fin de la lecture. Audio vide : lever une erreur.
- Repli : si la synthèse cloud échoue, lire le texte avec la voix française du téléphone plutôt que de rester muet.
- stopSpeaking doit aussi débloquer une lecture cloud en cours.

**Critères d'acceptation**
- [ ] Avec la vraie clé : dicter une phrase en wolof renvoie du texte ; une réponse en wolof est lue
- [ ] Coupure réseau : la lecture bascule sur la voix du téléphone, sans crash
- [ ] Le fichier temporaire est toujours supprimé

**Dépendances**
Dépend de D1, B1, D3.

**Règles de travail**
Branche : feature/d2-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [D3] Cloud Functions aiSpeech (synthèse vocale) et aiTranscribe (reconnaissance vocale)

**Labels** : lot-d, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Deux fonctions appelables qui relaient les requêtes audio vers RodiumAI, avec la clé côté serveur.

**Fichiers que tu modifies (et seulement ceux-là)**
- functions/src/aiSpeech.js
- functions/src/aiTranscribe.js
- functions/test/*.test.js

**À implémenter**
- aiSpeech : entrée { text: string, language: string }, sortie { audio: "<mp3 en base64>" }. Refuser si non connecté, si text est vide ou dépasse 600 caractères. Choix du modèle de synthèse : variable RODIUMAI_TTS_MODEL_<CODE> avec repli sur RODIUMAI_TTS_MODEL. Timeout 45 s.
- aiTranscribe : entrée { audio: "<base64>", mime: string, language: string }, sortie { text: string }. Refuser si non connecté, si l'audio est vide ou > ~10 Mo, si mime n'est pas de la forme audio/.... Modèle de transcription : variable RODIUMAI_STT_MODEL.
- Liste PROMPT_ONLY_LANGUAGES : pour ces codes de langue, le modèle ne reconnaît pas le code ISO ; ne pas passer le paramètre language mais indiquer la langue dans le prompt.
- Commun : secret RODIUMAI_API_KEY, URL de base RODIUMAI_BASE_URL. Ne jamais journaliser l'audio ni le texte. Erreur du fournisseur : HttpsError('internal', ...) sans détail.

**Critères d'acceptation**
- [ ] Non connecté : unauthenticated. Texte de 601 caractères : invalid-argument
- [ ] Avec la vraie clé : aiSpeech renvoie un mp3 lisible, aiTranscribe renvoie le texte dit
- [ ] Changer de modèle se fait uniquement par variable d'environnement

**Dépendances**
Dépend de A2. Débloque D2 et D8.

**Règles de travail**
Branche : feature/d3-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [D4] MarketplaceScreen : annonces de récolte avec contact du vendeur

**Labels** : lot-d, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Met en relation un agriculteur qui vend sa récolte et des acheteurs.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/market/marketplace_screen.dart

**À implémenter**
- Collection Firestore marketplace : sellerId, cropName, quantityKg, pricePerKg, location, sellerPhone, status (disponible), createdAt (timestamp serveur).
- Liste (titre « Marketplace ») : flux temps réel des annonces status == 'disponible' triées par createdAt décroissant.
- Chaque annonce est une KCard : « {culture} · {quantité} kg », « {prix} FCFA / kg », localité, et deux boutons « Appeler » et « WhatsApp » (ouverture avec url_launcher). Utiliser vendorTelUri(phone) et vendorWhatsAppUri(phone, message: ...) du fichier lib/services/external/vendor_links.dart (lot E, issue E3).
- Publier une annonce : bouton flottant « Vendre » qui ouvre une feuille modale avec les champs Culture, Quantité (kg), Prix au kg (FCFA), Téléphone (prérempli avec le numéro du compte si connu), bouton « Publier l'annonce ». Validation : culture non vide, quantité et prix supérieurs à 0, téléphone valide. Refuser si non connecté.
- Bonus : le vendeur peut marquer son annonce « vendue » (status passe à vendue).

**Critères d'acceptation**
- [ ] Une annonce publiée apparaît en direct chez les autres utilisateurs
- [ ] « Appeler » ouvre le numéro ; « WhatsApp » ouvre la conversation
- [ ] Champs invalides refusés avec un message

**Dépendances**
Dépend de A2 (règles + index), E3 (vendor_links).

**Règles de travail**
Branche : feature/d4-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [D5] Communauté : signalements géolocalisés et notification aux voisins

**Labels** : lot-d, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Un agriculteur voit si d'autres ont signalé la même maladie près de chez lui et publie son propre signalement.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/community/community_screen.dart
- functions/src/notifyReport.js

**À implémenter**
- Collection Firestore signalements : authorId, disease, description, latitude, longitude, locality, createdAt.
- Écran CommunityScreen({String? prefillDisease}) (titre « Signalements de la communauté ») :
  - Liste temps réel des 50 derniers signalements (createdAt décroissant) en KCard : maladie, description, et distance en km depuis l'utilisateur quand la position est connue.
  - Filtre « Proches de chez moi » (interrupteur, rayon par défaut 50 km) qui masque les signalements plus lointains.
  - Formulaire en bas : « Maladie observée » (prérempli avec prefillDisease), « Détails (optionnel) », bouton « Publier ». À la publication : demander la permission de localisation, enregistrer latitude et longitude (si refusée, publier sans coordonnées), vider le formulaire. Refuser si non connecté.
- Cloud Function notifyReport : déclenchée à la création d'un document signalements/{id} (onDocumentCreated). Envoie une notification push : titre « Nouveau signalement », texte « {maladie} signalée près de {localité} ». Version minimale : au topic alerts. Version cible : envoyer seulement aux utilisateurs dont la localité/position est dans le rayon ; ne pas notifier l'auteur.

**Critères d'acceptation**
- [ ] Publier avec la position enregistre latitude et longitude
- [ ] Le filtre « Proches de chez moi » masque un signalement à plus de 50 km
- [ ] Un signalement déclenche une notification chez un autre appareil abonné
- [ ] Le champ maladie est prérempli depuis l'écran de résultat

**Dépendances**
Dépend de A2, E5.

**Règles de travail**
Branche : feature/d5-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [D6] Registre de langues : un fichier par langue (évite les conflits)

**Labels** : lot-d, phase-2, taille-M, langue · **Phase 2 - Finitions**

**Contexte**
Aujourd'hui, ajouter une langue oblige à modifier 4 fichiers de code. Ce refactoring donne un fichier par langue.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/languages/*.dart (nouveau dossier)
- adaptation minimale de user_settings.dart, voice_service.dart, avatar_intents.dart, rodium_ai_service.dart

**À implémenter**
- Créer lib/languages/language_pack.dart : classe LanguagePack avec code, name, greeting, cameraWords, cameraReply, spokenStyleHint, usesCloudVoice.
- Un fichier par langue : fr.dart, en.dart, wo.dart, et registry.dart qui expose const languagePacks = [...].
- Adapter les 4 fichiers pour lire le registre au lieu de leurs tables internes.
- Après ce refactoring, ajouter une langue = créer un fichier + une ligne dans registry.dart.
- Documenter la procédure dans docs/AJOUTER_UNE_LANGUE.md.

**Critères d'acceptation**
- [ ] Tous les tests existants passent sans modification
- [ ] Ajouter une langue de test demande un seul nouveau fichier + une ligne de registre

**Dépendances**
Dépend de B1, B5, C1, D1 mergés.

**Règles de travail**
Branche : feature/d6-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [D7] Traduire l'interface (internationalisation Flutter)

**Labels** : lot-d, phase-2, taille-L, langue · **Phase 2 - Finitions**

**Contexte**
Aujourd'hui seuls les textes de l'IA, la voix, la phrase d'accueil suivent la langue choisie : tous les boutons, menus et titres sont en français en dur.

**Fichiers que tu modifies (et seulement ceux-là)**
- l10n.yaml
- lib/l10n/*.arb
- puis chaque lot extrait les textes de SES écrans

**À implémenter**
- D (cette issue) : configurer l10n.yaml, créer lib/l10n/app_fr.arb (référence), app_en.arb, app_wo.arb, générer AppLocalizations. main.dart ajoute localizationsDelegates et supportedLocales, et la locale suit AppState.languageCode.
- Chaque lot extrait les textes de ses propres fichiers (issue enfant, un commit par écran) : remplacer les chaînes en dur par AppLocalizations.of(context)!.clé. Convention de clés : ecran_element.
- Chaque texte traduit doit être relu par un locuteur natif.

**Critères d'acceptation**
- [ ] Changer de langue dans le profil traduit l'interface entière sans redémarrer
- [ ] Aucun texte français en dur dans lib/screens/** (hors logs)
- [ ] Une clé manquante dans une langue retombe sur le français

**Dépendances**
Dépend de toutes les issues d'écrans fusionnées. Phase 2.

**Règles de travail**
Branche : feature/d7-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [D8] Valider le wolof : test réel de la voix et relecture des textes par un locuteur natif

**Labels** : lot-d, phase-2, taille-M, langue, validation · **Phase 2 - Finitions**

**Contexte**
La documentation RodiumAI ne liste pas les langues supportées : la qualité du wolof est inconnue tant qu'on n'a pas testé avec la vraie clé.

**Fichiers que tu modifies (et seulement ceux-là)**
- aucun fichier imposé (corrections dans lib/languages/wo.dart ou dans les fichiers actuels)
- functions/.env pour les modèles

**À implémenter**
- Avec la vraie clé RodiumAI : dicter 3 phrases en wolof (aiTranscribe) et écouter 3 réponses (aiSpeech). Noter dans l'issue ce qui marche.
- Si la qualité est mauvaise : essayer un autre modèle via RODIUMAI_TTS_MODEL_WO et RODIUMAI_STT_MODEL, ou brancher un modèle ouvert.
- Faire relire par un locuteur natif : greetings['wo'], cameraReply('wo'), les messages d'alerte météo en wolof, la consigne de style de l'IA pour wo. Poser 5 questions agricoles à l'avatar en wolof et faire juger les réponses.
- Décision à consigner : wolof gardé / gardé en texte seulement / retiré de la démo.

**Critères d'acceptation**
- [ ] Compte rendu écrit dans l'issue (tests, modèles retenus, décision)
- [ ] Les textes wolof relus sont corrigés dans le code

**Dépendances**
Dépend de D2, D3, E6. Avant toute présentation.

**Règles de travail**
Branche : feature/d8-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [F1] [MODÈLE À DUPLIQUER] Ajouter ma langue (une issue par langue et par personne qui la parle)

**Labels** : lot-d, phase-2, taille-S, langue, modèle · **Phase 2 - Finitions**

**Contexte**
Les langues locales doivent être ajoutées par les membres qui les parlent. Dupliquer cette issue pour chaque langue.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/languages/<code>.dart + une ligne dans lib/languages/registry.dart
- functions/src/weatherAlerts.js (objet MESSAGES)

**À implémenter**
- Déclarer la langue : créer lib/languages/<code>.dart et ajouter une ligne dans registry.dart.
- Phrase d'accueil : une phrase courte pour l'écran de choix de la langue, relue par un locuteur natif.
- Voix : si le téléphone ne gère pas la langue, passer usesCloudVoice à vrai puis tester avec la vraie clé.
- Consigne de style pour l'IA : alphabet, mots techniques à garder en français.
- Caméra : le mot pour « photo » et la phrase de réponse.
- Notifications météo : titre et texte des deux alertes dans MESSAGES de weatherAlerts.js.
- Essai complet : choisir la langue, écouter l'accueil, parler à l'avatar, écouter la réponse, recevoir une alerte.
- Règle : une seule personne à la fois modifie registry.dart (rebase avant de fusionner).

**Critères d'acceptation**
- [ ] Les 7 étapes sont faites et testées sur téléphone
- [ ] Un locuteur natif a relu tous les textes

**Dépendances**
Dépend de D6, D2, D3, E6.

**Règles de travail**
Branche : feature/f1-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

## Lot E : Météo, points de vente et notifications

### [E1] WeatherService et règles de risque (maladie fongique, stress hydrique)

**Labels** : lot-e, phase-1, taille-S · **Phase 1 - Fonctionnalités**

**Contexte**
Prévisions météo réelles et règles de risque calculées localement, sans appel IA.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/services/external/weather_service.dart
- test/weather_outlook_test.dart

**À implémenter**
- WeatherService.fetchOutlook({required double lat, required double lng}) : GET https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..&daily=precipitation_probability_max,relative_humidity_2m_max,temperature_2m_max&forecast_days=3&timezone=auto. Statut différent de 200 : lever une exception « Erreur météo (code) ». Renvoie un WeatherOutlook.
- WeatherOutlook : trois listes precipitationProbabilityPct, humidityPct, maxTempC, une valeur par jour.
- bool get highFungalRisk : vrai si, sur au moins 2 des 3 jours, l'humidité max est ≥ 80 % ET la probabilité de pluie ≥ 60 %.
- bool get heatStressRisk : vrai si, sur au moins 2 jours, la température max est ≥ 38 °C ET la probabilité de pluie ≤ 20 %.
- Ces seuils sont provisoires : ils seront validés par un agronome (issue E7). Les définir comme constantes nommées en haut du fichier.

**Critères d'acceptation**
- [ ] Tests de highFungalRisk et heatStressRisk : cas limites (79 % / 80 %, 1 jour / 2 jours, listes de longueurs différentes, listes vides)
- [ ] Test de fetchOutlook avec un faux client HTTP (réponse 200 et erreur 500)

**Dépendances**
Aucune. Débloque E2.

**Règles de travail**
Branche : feature/e1-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [E2] WeatherAlertsScreen : alertes météo et prévisions à 3 jours

**Labels** : lot-e, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Écran /weather : il prévient l'agriculteur d'un risque de maladie ou de chaleur d'après sa position.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/weather/weather_alerts_screen.dart

**À implémenter**
- Titre « Alertes météo », bouton actualiser dans la barre.
- Au chargement : vérifier/demander la permission de localisation, lire la position, appeler WeatherService.fetchOutlook. Refus de permission : erreur claire « Permission de localisation refusée » avec bouton « Réessayer ».
- Bandeaux StatusBanner :
  - highFungalRisk : ton danger, « Risque élevé de maladie fongique », « Humidité et pluie élevées prévues plusieurs jours : surveillez vos cultures (mildiou, rouille...). »
  - sinon : ton succès, « Pas de risque élevé détecté », « Conditions météo actuellement peu favorables aux maladies fongiques. »
  - heatStressRisk : ton alerte, « Forte chaleur annoncée », « Arrosez tôt le matin ou en fin de journée pour éviter le stress hydrique. »
- Section « Prévisions 3 jours » : une ligne par jour avec température max, humidité max et probabilité de pluie.
- États : chargement, erreur (message + « Réessayer »), succès.

**Critères d'acceptation**
- [ ] Position acceptée : bandeaux cohérents avec les seuils de E1
- [ ] Position refusée / pas de réseau : message clair, pas de crash
- [ ] Thèmes clair et sombre

**Dépendances**
Dépend de E1.

**Règles de travail**
Branche : feature/e2-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [E3] Liens de contact (appel, WhatsApp, itinéraire) et données des points de vente

**Labels** : lot-e, phase-1, taille-S · **Phase 1 - Fonctionnalités**

**Contexte**
Fonctions pures et testables utilisées par l'écran des points de vente (E4) et par la marketplace (D4).

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/services/external/vendor_links.dart
- lib/data/vendors_seed.dart
- test/vendor_links_test.dart

**À implémenter**
- vendor_links.dart (fonctions de module) :
  - String? vendorPhoneDigits(String? phone) : ne garde que les chiffres ; null si vide ; un numéro de 9 chiffres est considéré sénégalais (préfixe 221) ; null si le résultat a moins de 11 chiffres.
  - Uri? vendorTelUri(String? phone) : tel:+<chiffres>.
  - Uri? vendorWhatsAppUri(String? phone, {String message = ''}) : https://wa.me/<chiffres> avec ?text= si message non vide. WhatsApp n'existe que sur mobile : renvoyer null sauf si le numéro commence par 221 et que le numéro national commence par 7 (70, 75, 76, 77, 78) ; les fixes (33...) n'ont pas de lien WhatsApp.
  - Uri? vendorDirectionsUri(num? latitude, num? longitude) : https://www.google.com/maps/dir/?api=1&destination=lat,lng ; null si une coordonnée manque.
- vendors_seed.dart : const vendorsSeed = <Map<String, dynamic>>[...] avec, par point de vente : name, address, latitude, longitude, phone, products. Intégrer les 9 adresses de Dakar et Thiès.

**Critères d'acceptation**
- [ ] Tests : 9 chiffres devient 221... ; numéro invalide donne null ; mobile 77... donne un lien WhatsApp ; fixe 33... donne null ; itinéraire sans coordonnée donne null
- [ ] Au moins 9 points de vente intégrés, chacun avec nom, adresse, coordonnées

**Dépendances**
Aucune. Débloque E4 et D4.

**Règles de travail**
Branche : feature/e3-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [E4] VendorsMapScreen : points de vente d'intrants triés par distance

**Labels** : lot-e, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Écran /vendors : l'agriculteur trouve où acheter des intrants et contacte le magasin directement.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/screens/market/vendors_map_screen.dart

**À implémenter**
- Titre « Points de vente d'intrants », bouton actualiser.
- Chargement : demander la position (geolocator, permission refusée ou erreur = pas de distances mais la liste s'affiche quand même) ; lire vendorsSeed ET FirebaseService.fetchNearbyVendors() (erreur réseau ignorée). Fusionner les deux listes en dédoublonnant par nom.
- Si la position est connue : calculer distanceKm (Geolocator.distanceBetween / 1000) et trier du plus proche au plus loin.
- Carte de chaque point de vente : nom, distance (« 2.3 km ») si connue, adresse, produits séparés par « · », et 3 boutons : « Appeler » (vendorTelUri), « WhatsApp » (vendorWhatsAppUri, message « Bonjour, je vous contacte depuis KultivIA. Avez-vous des produits pour soigner mes cultures ? »), « Itinéraire » (vendorDirectionsUri).
- États : chargement, liste vide.

**Critères d'acceptation**
- [ ] Sans permission de position : la liste s'affiche, sans distances
- [ ] Avec position : tri par distance correct
- [ ] Les 3 boutons ouvrent l'application d'appel, WhatsApp et Maps
- [ ] Un point de vente ajouté dans Firestore apparaît sans republier l'app

**Dépendances**
Dépend de E3, A4 (fetchNearbyVendors).

**Règles de travail**
Branche : feature/e4-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [E5] NotificationService : notifications push (FCM)

**Labels** : lot-e, phase-1, taille-S · **Phase 1 - Fonctionnalités**

**Contexte**
Les notifications remplacent le SMS. Service utilisé par le paramétrage (C2), le profil (C3), l'écran principal (B3).

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/services/system/notification_service.dart

**À implémenter**
- Classe NotificationService (contrat) :
  - static const alertsTopic = 'alerts'.
  - Future<bool> enable(String uid) : demande l'autorisation ; si refusée ou non fournie, renvoyer false ; sinon s'abonner au topic alerts, récupérer le jeton de l'appareil et l'enregistrer en merge dans users/{uid}.fcmToken ; renvoyer true.
  - Future<void> disable() : se désabonner du topic alerts.
  - Stream<String> get foregroundTexts : notifications reçues pendant que l'app est ouverte, mises en forme « titre : texte », à afficher dans un SnackBar par B3.
  - Gérer aussi onTokenRefresh : ré-enregistrer le jeton quand il change.
- Android 13+ : la permission POST_NOTIFICATIONS est déclarée en A1.

**Critères d'acceptation**
- [ ] Sur téléphone : activer puis recevoir une notification de test envoyée depuis la console Firebase (topic alerts)
- [ ] Permission refusée : enable renvoie false, pas de crash
- [ ] disable arrête les notifications

**Dépendances**
Dépend de A1, A2. Débloque C2, C3, D5.

**Règles de travail**
Branche : feature/e5-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [E6] Cloud Function weatherAlerts : notification météo préventive chaque matin

**Labels** : lot-e, phase-1, taille-M · **Phase 1 - Fonctionnalités**

**Contexte**
Chaque matin à 6 h, le serveur prévient les utilisateurs dont la localité est à risque.

**Fichiers que tu modifies (et seulement ceux-là)**
- functions/src/weatherAlerts.js
- functions/src/weatherRules.js
- functions/test/weatherRules.test.js

**À implémenter**
- Planification : fonction planifiée (onSchedule) tous les jours à 06:00, fuseau Africa/Dakar.
- Utilisateurs concernés : documents users avec notificationsEnabled == true, un fcmToken et une locality non vide.
- Position : géocoder la localité avec l'API de géocodage Open-Meteo (gratuite). Mettre en cache les résultats par localité pendant l'exécution. Localité introuvable : ignorer l'utilisateur.
- Règles (fichier weatherRules.js, fonctions pures testées) : mêmes seuils que WeatherOutlook côté app (E1).
- Fréquence : au plus une alerte tous les 3 jours par utilisateur (champ lastWeatherAlertAt dans users/{uid}).
- Messages dans un objet MESSAGES par langue (fr, en, wo) avec titre et texte pour les deux alertes (maladie, chaleur) ; langue = languageCode de l'utilisateur, français par défaut.
- Envoi via FCM au fcmToken. Token invalide : le retirer du profil.

**Critères d'acceptation**
- [ ] Tests de weatherRules (cas limites identiques à ceux de E1)
- [ ] Exécution manuelle sur un utilisateur de test dans une localité à risque : une notification arrive
- [ ] Deux exécutions dans la même semaine ne renvoient pas d'alerte avant 3 jours

**Dépendances**
Dépend de A2, E5, C2.

**Règles de travail**
Branche : feature/e6-<mot-cle>. Pull request relue par une autre personne avant fusion.

---

### [E7] Faire valider les seuils d'alerte météo par un agronome

**Labels** : lot-e, phase-2, taille-S, validation · **Phase 2 - Finitions**

**Contexte**
Les seuils (80 % d'humidité, 60 % de pluie, 38 °C, 20 % de pluie, 2 jours sur 3) sont des valeurs provisoires.

**Fichiers que tu modifies (et seulement ceux-là)**
- lib/services/external/weather_service.dart
- functions/src/weatherRules.js

**À implémenter**
- Présenter les règles à un agronome ou un conseiller agricole.
- Ajuster les constantes dans les deux fichiers en même temps et adapter les tests.
- Noter dans l'issue qui a validé et quand.

**Critères d'acceptation**
- [ ] Seuils validés par une personne qualifiée, consignés dans l'issue
- [ ] E1 et E6 utilisent exactement les mêmes valeurs

**Dépendances**
Dépend de E1, E6. Avant une présentation publique.

**Règles de travail**
Branche : feature/e7-<mot-cle>. Pull request relue par une autre personne avant fusion.
