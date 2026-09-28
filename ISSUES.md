# Issues - Roadmap de développement

## Phase 1 : Initialisation et Structure du Projet

### #1 Initialisation du projet Flutter
- [ ] Créer le projet Flutter
- [ ] Configurer les dépendances (provider, firebase_core, cloud_firestore, firebase_auth, cloud_functions, image_picker, geolocator, url_launcher)
- [ ] Configurer Firebase (flutterfire configure)
- [ ] Mettre en place la structure de dossiers initiale

### #2 Design System et Thème
- [ ] Créer le design system (KSpace, KRadius, KStatus)
- [ ] Implémenter le thème clair/sombre
- [ ] Créer les composants de base (KCard, KButton, etc.)
- [ ] Configurer les couleurs sémantiques (succès, warning, danger, info)

### #3 Architecture Core
- [ ] Créer la structure du dossier `core/`
- [ ] Implémenter les constantes (app_constants, api_constants)
- [ ] Créer la configuration (app_config)
- [ ] Implémenter les exceptions personnalisées
- [ ] Mettre en place les sérialiseurs JSON

## Phase 2 : Authentification et Firebase

### #4 Configuration Firebase Auth
- [ ] Configurer les fournisseurs d'authentification (Email, Google, Apple, Téléphone)
- [ ] Créer le service FirebaseService
- [ ] Implémenter l'écran d'authentification (AuthScreen)
- [ ] Créer le service MockAuthService pour les tests

### #5 Écran de démarrage (Gate)
- [ ] Créer l'écran GateScreen
- [ ] Implémenter la logique de redirection selon l'état utilisateur
- [ ] Gérer les états : non-connecté → onboarding → auth → setup → home

### #6 Onboarding
- [ ] Créer l'écran OnboardingScreen
- [ ] Implémenter le carrousel de présentation
- [ ] Ajouter les boutons d'action (commencer, passer)

## Phase 3 : Setup et Profil Utilisateur

### #7 Modèle UserProfile
- [ ] Créer le modèle UserProfile
- [ ] Définir les champs : nom, rôle, localisation, cultures, préférences

### #8 Setup Screen et Controller
- [ ] Créer SetupController (state management)
- [ ] Implémenter SetupScreen avec navigation entre étapes
- [ ] Créer les 3 étapes : identité, exploitation, préférences

### #9 Étapes de Setup
- [ ] StepIdentity : formulaire nom + rôle
- [ ] StepExploitation : localisation + cultures
- [ ] StepPreferences : langue + notifications + voix
- [ ] SetupBottomBar : navigation Retour/Suivant/Terminer

### #10 Persistance du Profil
- [ ] Sauvegarder le profil dans Firestore
- [ ] Charger le profil au démarrage
- [ ] Permettre la modification depuis Profil

## Phase 4 : Services IA et Conversation

### #11 Intégration RodiumAI
- [ ] Créer RodiumAiService
- [ ] Implémenter les prompts système (diagnostic, chat)
- [ ] Configurer la Cloud Function aiProxy

### #12 Diagnostic par Image
- [ ] Implémenter diagnoseFromImage
- [ ] Intégrer image_picker
- [ ] Encoder l'image en base64
- [ ] Parser la réponse JSON de l'IA

### #13 Diagnostic par Texte
- [ ] Implémenter diagnoseFromText
- [ ] Gérer les descriptions texte/vocale

### #14 Conversation avec l'Avatar
- [ ] Implémenter chatWithAvatar
- [ ] Gérer l'historique de conversation
- [ ] Configurer le style de réponse (oral, simple)

### #15 Services Audio
- [ ] Implémenter synthesizeSpeech (TTS)
- [ ] Implémenter transcribeAudio (STT)
- [ ] Configurer les Cloud Functions aiSpeech et aiTranscribe

## Phase 5 : Écran Principal (Home AI)

### #16 Structure Home AI
- [ ] Créer HomeAiScreen
- [ ] Implémenter l'état de conversation (ChatEntry)
- [ ] Créer les sous-composants dans home_ai/

### #17 Composants Home AI
- [ ] Composer : champ de saisie + boutons (micro, photo, envoi)
- [ ] EmptyState : état vide avec suggestions
- [ ] MessageView : bulles de conversation
- [ ] TypingDots : indicateur "en train d'écrire"

### #18 Navigation et Actions
- [ ] Intégrer AppDrawer (menu latéral)
- [ ] Implémenter les actions de diagnostic
- [ ] Gérer l'affichage des résultats

## Phase 6 : Repository et Historique

### #19 Pattern Repository
- [ ] Créer l'interface DiagnosisRepository
- [ ] Implémenter FirebaseDiagnosisRepository
- [ ] Configurer Firestore pour les diagnostics

### #20 Historique des Diagnostics
- [ ] Créer DiagnosisHistory service
- [ ] Sauvegarder les diagnostics dans Firestore
- [ ] Charger l'historique utilisateur
- [ ] Créer HistoryScreen

### #21 Modèle Diagnosis
- [ ] Créer le modèle Diagnosis
- [ ] Définir les champs : maladie, confiance, traitement, image, date

## Phase 7 : Écran de Résultat de Diagnostic

### #22 DiagnosisResultScreen
- [ ] Créer l'écran de résultat
- [ ] Afficher la maladie, confiance, traitement
- [ ] Implémenter les actions : partager (community), vendre (marketplace), santé (dashboard)

### #23 Actions depuis le Résultat
- [ ] Navigation vers CommunityScreen avec pré-remplissage
- [ ] Navigation vers MarketplaceScreen
- [ ] Navigation vers HealthDashboardScreen

## Phase 8 : Fonctionnalités Communautaires

### #24 Community Screen
- [ ] Créer CommunityScreen
- [ ] Afficher les signalements locaux
- [ ] Permettre de publier un signalement
- [ ] Configurer Firestore collection `signalements`

### #25 Géolocalisation
- [ ] Intégrer geolocator
- [ ] Demander la permission de localisation
- [ ] Calculer la distance aux autres signalements

## Phase 9 : Marketplace et Vendeurs

### #26 Marketplace Screen
- [ ] Créer MarketplaceScreen
- [ ] Afficher les offres de vente
- [ ] Permettre de publier une offre
- [ ] Configurer Firestore collection `marketplace`

### #27 Vendors Map Screen
- [ ] Créer VendorsMapScreen
- [ ] Afficher les points de vente d'intrants
- [ ] Intégrer url_launcher (appels, WhatsApp)
- [ ] Créer vendors_seed.dart (données offline)

### #28 Vendor Links Service
- [ ] Créer VendorLinks service
- [ ] Gérer les liens externes (téléphone, WhatsApp, itinéraire)

## Phase 10 : Météo et Alertes

### #29 Weather Service
- [ ] Créer WeatherService
- [ ] Intégrer Open-Meteo API (gratuit, sans clé)
- [ ] Récupérer l'historique météo et les alertes

### #30 Weather Alerts Screen
- [ ] Créer WeatherAlertsScreen
- [ ] Afficher l'historique météo
- [ ] Afficher les alertes futures
- [ ] Utiliser la géolocalisation

Health Dashboard

### #31 Health Dashboard Screen

- [ ] Créer HealthDashboardScreen
- [ ] Calculer le score de santé de l'exploitation
- [ ] Agréger l'historique des diagnostics
- [ ] Afficher les statistiques et tendances

## Phase 12 : Paramètres et Profil

### #32 Profile Screen
- [ ] Créer ProfileScreen
- [ ] Afficher les informations utilisateur
- [ ] Permettre la modification du profil
- [ ] Gérer les notifications

### #33 Language Screen
- [ ] Créer LanguageScreen
- [ ] Implémenter le sélecteur de langue
- [ ] Sauvegarder la préférence
- [ ] Mettre à jour l'interface

### #34 Voice Service
- [ ] Créer VoiceService
- [ ] Intégrer la synthèse vocale locale
- [ ] Gérer les préférences de voix

## Phase 13 : Services Système

### #35 AppState Service
- [ ] Créer AppState (state management global)
- [ ] Gérer l'état de l'application
- [ ] Centraliser les services

### #36 UserSettings Service
- [ ] Créer UserSettings
- [ ] Gérer les préférences utilisateur
- [ ] Persister localement

### #37 Notification Service
- [ ] Créer NotificationService
- [ ] Configurer les notifications push
- [ ] Gérer les permissions

## Phase 14 : Accessibilité et Multilingue

### #38 Support Multilingue
- [ ] Implémenter le support français/anglais/wolof
- [ ] Adapter les prompts IA selon la langue
- [ ] Traduire l'interface

### #39 Accessibilité Vocale
- [ ] Optimiser les réponses pour la lecture vocale
- [ ] Phrases courtes, mots simples
- [ ] Pas de markdown ni symboles

## Phase 15 : Tests et Qualité

### #40 Tests Unitaires
- [ ] Tester les services (RodiumAiService, etc.)
- [ ] Tester les modèles
- [ ] Tester les repositories

### #41 Tests d'Intégration
- [ ] Tester les flux Firebase
- [ ] Tester les Cloud Functions
- [ ] Tester la navigation

### #42 Optimisation
- [ ] Optimiser les performances
- [ ] Réduire la taille de l'APK
- [ ] Améliorer le temps de chargement

## Phase 16 : Déploiement

### #43 Configuration Production
- [ ] Configurer Firebase en production
- [ ] Sécuriser les règles Firestore
- [ ] Configurer les Cloud Functions

### #44 Publication
- [ ] Préparer le build Android
- [ ] Préparer le build iOS
- [ ] Soumettre sur les stores

## Phase 17 : Maintenance et Évolution

### #45 Monitoring
- [ ] Configurer Crashlytics
- [ ] Configurer Analytics
- [ ] Surveiller les performances

### #46 Améliorations Continues
- [ ] Collecter les feedbacks utilisateurs
- [ ] Améliorer les prompts IA
- [ ] Ajouter de nouvelles fonctionnalités

---

## Priorités suggérées

**MVP (Minimum Viable Product)** : Issues #1-#15
**Fonctionnalités core** : Issues #16-#25
**Écosystème complet** : Issues #26-#37
**Accessibilité et qualité** : Issues #38-#46
