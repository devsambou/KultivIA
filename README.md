# KultivIA — Flutter + Firebase

Diagnostic IA des maladies de cultures par photo, texte ou voix.
Hackathon FFSC 2026.

**Liste complète des fonctionnalités, état d'avancement, reste à faire et consignes pour ajouter une langue : voir [FONCTIONNALITES.md](FONCTIONNALITES.md).**

## Parcours utilisateur

1. **Onboarding** (3 écrans) → 2. **Connexion / inscription** (email, Google, Apple, téléphone)
3. **Première connexion seulement : paramétrage en 3 étapes**
   - Étape 1 : nom, profil (agriculteur / vendeur d'intrants / conseiller)
   - Étape 2 : localité, cultures principales
   - Étape 3 : langue (avec écoute de chaque langue), réponses parlées, notifications
4. **Conversation IA** façon Claude mobile : réponses sans bulle, champ de saisie arrondi, « + » pour joindre une photo (appareil ou galerie), micro, bouton d'envoi, menu latéral vers tous les écrans. **L'avatar parle** (voir « Voix de l'avatar ») et ouvre l'appareil photo quand on lui dit « photo » ou « caméra » : un gros bouton « Appuyez et parlez » permet d'utiliser l'app sans savoir lire.

Aux connexions suivantes, l'app va directement à la conversation. Le profil est modifiable dans **Profil → Modifier mon profil**.

## Structure

```
lib/
  main.dart              # init Firebase, thème, routes
  theme.dart             # design system : jetons KSpace/KRadius/KStatus, thème clair/sombre
  widgets/k_components.dart  # KCard, StatusChip, StatusBanner
  models/                # Diagnosis, ChatEntry, UserProfile
  services/              # IA (proxy), Firebase, notifications, voix, météo, état
  screens/               # gate, onboarding, auth, setup, home_ai, résultat, historique, ...
  widgets/app_drawer.dart
functions/index.js       # aiProxy, aiSpeech, aiTranscribe (RodiumAI, clé côté serveur) + notifyNewReport (push)
firestore.rules
```

## Mise en route (dans l'ordre)

```bash
# 1. Générer les dossiers android/ et ios/ (absents du zip) sans toucher à lib/
flutter create --platforms=android,ios --org com.kultivia .

# 2. Dépendances
flutter pub get

# 3. Connecter Firebase (crée google-services.json / GoogleService-Info.plist)
dart pub global activate flutterfire_cli
flutterfire configure

# 4. Règles + fonctions
firebase deploy --only firestore:rules
cd functions && npm install
firebase functions:secrets:set RODIUMAI_API_KEY     # la clé n'est JAMAIS dans l'app
firebase deploy --only functions
cd ..

# 5. Lancer
flutter run
```

Console Firebase → Authentication : activer Email/Mot de passe, Google, Apple, Téléphone.
Ajouter l'empreinte SHA-1/SHA-256 de votre clé de signature Android (nécessaire à Google Sign-In et à la connexion par téléphone).
Firebase Functions nécessite le plan **Blaze**.

## Réglages natifs obligatoires

**Android** — `android/app/build.gradle` : `minSdkVersion 23`. Dans `android/app/src/main/AndroidManifest.xml`, avant `<application>` :

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<queries>
  <intent><action android:name="android.speech.RecognitionService"/></intent>
</queries>
```

**iOS** — `ios/Runner/Info.plist` : `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSLocationWhenInUseUsageDescription`. Dans Xcode : capacités *Push Notifications* et *Sign in with Apple*, et clé APNs à téléverser dans Firebase → Paramètres du projet → Cloud Messaging.

## Notifications (remplacent le mode SMS)

- À la fin du paramétrage (ou dans Profil), l'utilisateur autorise les notifications ; l'appareil s'abonne au topic `alerts` et son jeton FCM est enregistré dans `users/{uid}`.
- `notifyNewReport` envoie une alerte à tous les abonnés à chaque nouveau signalement communautaire.
- Test rapide sans code : console Firebase → Messaging → nouvelle campagne → cible « Topic : alerts ».
- App ouverte : la notification s'affiche en bandeau dans la conversation ; app fermée : notification système.
- Limite actuelle : les signalements n'ont pas de coordonnées (TODO dans `community_screen.dart`), donc l'alerte part à tous, pas seulement aux voisins.

## Voix de l'avatar (français, wolof, anglais)

Pour les utilisateurs qui ne savent pas lire, l'avatar écoute et parle.

- **Parler** : gros bouton micro sur l'écran d'accueil et micro du champ de saisie. Une question posée à l'oral reçoit toujours une réponse lue à voix haute.
- **Réponses parlées** : haut-parleur dans la barre du haut (ou étape 3 du paramétrage) pour que *toutes* les réponses soient lues. Le bouton « Écouter » de chaque réponse reste disponible.
- **Choix de la langue à l'oreille** : un haut-parleur à côté de chaque langue dit une phrase d'accueil (`VoiceService.greetings`, à faire relire par un locuteur wolof).

| Langue | Écoute | Voix |
|---|---|---|
| Français, anglais | moteur du téléphone (gratuit) | moteur du téléphone |
| Wolof | enregistrement du micro → RodiumAI `/audio/transcriptions` | RodiumAI `/audio/speech`, repli sur la voix française du téléphone si le réseau échoue |

Configuration côté serveur, dans `functions/.env` (facultatif, valeurs par défaut entre parenthèses) :

```
RODIUMAI_TTS_MODEL=openai/tts-1          # synthèse vocale
RODIUMAI_TTS_VOICE=nova
RODIUMAI_TTS_MODEL_WO=                   # modèle dédié au wolof, si vous en avez un
RODIUMAI_STT_MODEL=google/gemini-2.5-flash   # transcription
```

**À tester avant de promettre le wolof.** La documentation RodiumAI que j'ai pu consulter décrit les points d'accès audio mais ne liste pas les langues supportées. Faites un essai réel : dictez trois phrases en wolof et écoutez la synthèse. Si la qualité est insuffisante, deux pistes : un autre modèle disponible chez RodiumAI (variables ci-dessus), ou un modèle wolof ouvert (par ex. sur Hugging Face) hébergé derrière la même fonction `aiSpeech` / `aiTranscribe`. Le code de l'app n'aurait pas à changer.

Contraintes : Android `minSdkVersion 23` (déjà requis), permission micro (déjà listée), la voix wolof exige une connexion internet, et chaque texte lu est limité à 600 caractères.

## Alertes météo préventives

Chaque matin à 6 h (heure de Dakar), la fonction `dailyWeatherRisk` prévient les utilisateurs qui ont activé les notifications :

- Elle convertit la **localité** saisie au paramétrage en coordonnées (Open-Meteo, gratuit, sans clé), puis lit les prévisions à 3 jours. Un seul appel par localité.
- **Risque de maladie fongique** : humidité ≥ 80 % et pluie ≥ 60 % sur au moins 2 jours (mildiou, rouille).
- **Stress hydrique** : température ≥ 38 °C et pluie ≤ 20 % sur au moins 2 jours.
- Message dans la langue de l'utilisateur (fr, en, wo), au plus une alerte tous les 3 jours par utilisateur. Le wolof est à faire relire.
- Les mêmes règles s'affichent dans l'écran **Alertes météo** de l'app. Les seuils sont dans `functions/weather_rules.js` et `WeatherOutlook` (à garder identiques ; à affiner avec un agronome).

Pour la tester : `cd functions && npm test` (règles), puis après déploiement, Google Cloud Console → Cloud Scheduler → tâche `firebase-schedule-dailyWeatherRisk-…` → « Forcer l'exécution ». Il faut un utilisateur avec notifications activées, jeton FCM enregistré et une localité reconnue. Pour une démo à coup sûr, mettez temporairement les seuils à 0 % dans `weather_rules.js`.

Limites : notification texte uniquement (pas lue à voix haute), une seule localité par utilisateur, et il faut Firebase au plan Blaze.

## Ce qui reste à faire avant la démo

| Sujet | Action |
|---|---|
| Points de vente | 9 adresses de Dakar et Thiès sont intégrées (`lib/data/vendors_seed.dart`) avec appel, WhatsApp et itinéraire. Appeler chacune pour confirmer avant publication ; en ajouter d'autres dans ce fichier ou dans la collection Firestore `points_de_vente` |
| Voix wolof | Tester la qualité RodiumAI (voir « Voix de l'avatar ») et faire relire la phrase d'accueil |
| Icône / splash | Logo 1024×1024 dans `assets/icon/icon.png`, puis `dart run flutter_launcher_icons` |
| Publication | Comptes Google Play / Apple Developer |
| Mode hors-ligne | Non commencé (activer la persistance Firestore, bandeau « hors connexion ») |

## Sécurité

- Clé IA uniquement dans les secrets Firebase Functions (plus aucun `.env` embarqué dans l'app).
- `aiProxy`, `aiSpeech` et `aiTranscribe` exigent un utilisateur connecté ; `aiProxy` plafonne `max_tokens`, `aiSpeech` 600 caractères, `aiTranscribe` environ 4,5 Mo d'audio.
- `firestore.rules` : chacun ne lit/écrit que son profil et ses diagnostics.

## Tests

```bash
flutter analyze && flutter test
```
