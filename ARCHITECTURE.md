# Architecture KultivIA

## Vue d'ensemble

KultivIA est une application mobile Flutter qui aide les petits agriculteurs à diagnostiquer les maladies de leurs cultures via une IA conversationnelle multimodale (vision, texte, audio).

## Structure du projet

```
lib/
├── core/                    # Cœur de l'application
│   ├── constants/           # Constantes globales
│   │   ├── app_constants.dart
│   │   └── api_constants.dart
│   ├── config/              # Configuration de l'app
│   │   └── app_config.dart
│   ├── errors/              # Exceptions personnalisées
│   │   └── app_exceptions.dart
│   ├── json/                # Sérialiseurs JSON
│   │   └── json_serializers.dart
│   └── theme/               # Design system
│       └── theme.dart
├── data/                    # Données statiques
│   └── vendors_seed.dart
├── models/                  # Modèles de données
│   ├── diagnosis.dart
│   └── user_profile.dart
├── repositories/            # Pattern Repository (abstraction data)
│   ├── diagnosis_repository.dart
│   └── firebase_diagnosis_repository.dart
├── screens/                 # Écrans de l'application
│   ├── auth/                # Authentification
│   │   └── auth_screen.dart
│   ├── community/           # Partage communautaire
│   │   └── community_screen.dart
│   ├── health/              # Diagnostic et santé
│   │   ├── diagnosis_result_screen.dart
│   │   └── health_dashboard_screen.dart
│   ├── market/              # Marketplace et vendeurs
│   │   ├── marketplace_screen.dart
│   │   └── vendors_map_screen.dart
│   ├── settings/            # Paramètres utilisateur
│   │   ├── language_screen.dart
│   │   └── profile_screen.dart
│   ├── weather/             # Alertes météo
│   │   └── weather_alerts_screen.dart
│   ├── onboarding/          # Première utilisation
│   │   └── onboarding_screen.dart
│   ├── home_ai/             # Conversation IA (sous-composants)
│   │   ├── composer.dart
│   │   ├── empty_state.dart
│   │   ├── message_view.dart
│   │   └── typing_dots.dart
│   ├── setup/               # Configuration initiale
│   │   ├── setup_bottom_bar.dart
│   │   ├── setup_controller.dart
│   │   ├── step_exploitation.dart
│   │   ├── step_identity.dart
│   │   └── step_preferences.dart
│   ├── gate_screen.dart     # Écran de démarrage
│   ├── history_screen.dart  #历史 des diagnostics
│   ├── home_ai_screen.dart  # Écran principal
│   └── setup_screen.dart    # Écran de setup
├── services/                # Services métier
│   ├── auth/                # Firebase Auth
│   │   ├── firebase_service.dart
│   │   └── mock_auth_service.dart
│   ├── ai/                  # RodiumAI (vision, chat, TTS, STT)
│   │   ├── avatar_intents.dart
│   │   └── rodium_ai_service.dart
│   ├── data/                # Gestion des données
│   │   └── diagnosis_history.dart
│   ├── ui/                  # Services UI (voix)
│   │   └── voice_service.dart
│   ├── external/            # APIs externes (météo, vendeurs)
│   │   ├── vendor_links.dart
│   │   └── weather_service.dart
│   └── system/              # Services système (état, notifications)
│       ├── app_state.dart
│       ├── notification_service.dart
│       └── user_settings.dart
├── widgets/                 # Composants UI réutilisables
│   ├── app_drawer.dart
│   └── k_components.dart
└── main.dart               # Point d'entrée
```

## Architecture technique

### Design System
- **Tokens** : KSpace (espacements), KRadius (rayons), KStatus (couleurs sémantiques)
- **Thème** : Adaptatif clair/sombre, extension ThemeExtension pour KStatus
- **Composants** : KCard, KButton, etc. dans `widgets/k_components.dart`

### Pattern Repository
- `DiagnosisRepository` (interface) → `FirebaseDiagnosisRepository` (implémentation)
- Abstraction pour faciliter les tests et le changement d'implémentation

### State Management
- **Provider** pour l'état global
- Services principaux : `AppState`, `UserSettings`, `DiagnosisHistory`
- `SetupController` pour le flux de configuration

### Services IA (RodiumAI)
- **Sécurité** : Appels via Firebase Cloud Functions (jamais direct depuis mobile)
- **Fonctions** :
  - `aiProxy` : diagnostic vision + chat
  - `aiSpeech` : synthèse vocale
  - `aiTranscribe` : reconnaissance vocale

### Firebase
- **Auth** : Email/Google/Apple/Téléphone
- **Firestore** : Profils, diagnostics, signalements, marketplace
- **Cloud Functions** : Proxy IA (sécurité des clés API)

## Flux utilisateur principal

1. **GateScreen** : Redirection selon état (onboarding → auth → setup → home)
2. **Onboarding** : Présentation de l'app
3. **Auth** : Connexion/inscription
4. **Setup** : Configuration profil (identité, exploitation, préférences)
5. **Home AI** : Conversation avec l'avatar (photo + texte + voix)
6. **Diagnostic** : Résultat avec traitement + actions (community, marketplace, health)

## Fonctionnalités clés

### 1. Diagnostic IA
- Photo de culture + description optionnelle
- Analyse via modèle vision de RodiumAI
- Réponse structurée : maladie, confiance, traitement, message avatar
- Support multilingue (fr, en, wo)

### 2. Conversation multimodale
- Texte, photo, voix
- Historique de conversation
- Synthèse vocale des réponses
- Reconnaissance vocale des entrées

### 3. Écosystème agriculteur
- **Community** : Signalements épidémiques locaux
- **Marketplace** : Vente de cultures saines
- **Vendors** : Points de vente d'intrants
- **Weather** : Alertes météo historiques
- **Health Dashboard** : Score de santé de l'exploitation

### 4. Accessibilité
- Interface vocale (pour non-lecteurs)
- Support wolof (alphabet latin)
- Design simple et intuitif
- Réponses audio pour tous les diagnostics

## Stack technique

- **Framework** : Flutter (Dart)
- **Backend** : Firebase (Auth, Firestore, Cloud Functions)
- **IA** : RodiumAI (vision, langage, audio)
- **State** : Provider
- **Navigation** : MaterialApp avec routes nommées
- **Localisation** : Support multilingue (fr, en, wo)

## Sécurité

- Clés API IA jamais exposées côté client
- Proxy via Cloud Functions
- Validation des entrées utilisateur
- Gestion des erreurs avec exceptions personnalisées
