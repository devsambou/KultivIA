# KultivIA — Fonctionnalités et état d'avancement

*Mis à jour le 24 septembre 2026.*

KultivIA est une application mobile (Flutter + Firebase) pour les **agriculteurs** : ils photographient ou décrivent (à l'écrit ou à la voix) le problème de leur culture, et un avatar IA (RodiumAI) leur répond dans leur langue, à l'écrit et à l'oral, pour ceux qui ne savent pas lire.

> **État global : le code est écrit, mais il n'a jamais été compilé ni testé sur un téléphone.**
> La première étape est `flutter create --platforms=android,ios .`, puis `flutter pub get`, `flutter analyze` et `flutter test`. Il y aura des erreurs à corriger. Voir le README pour l'installation complète.

**Légende :** *Codé* = écrit mais à tester sur téléphone · *Partiel* = fonctionne avec des limites indiquées · *À faire* = pas commencé.

---

## 1. Ce que l'application fait

### Compte et parcours

| Fonctionnalité | État | Détail |
|---|---|---|
| Onboarding (3 écrans) | Codé | Présentation de l'app au premier lancement |
| Connexion / inscription | Codé | Email + mot de passe, Google, Apple, téléphone (code envoyé par Firebase). Demande l'activation de chaque méthode dans la console Firebase |
| Paramétrage à la première connexion | Codé | 3 étapes : nom et profil, localité et cultures, langue / réponses parlées / notifications |
| Profil | Codé | Modifier le profil, changer de langue, activer les notifications, se déconnecter |
| Routage au démarrage | Codé | Non connecté → onboarding ; profil vide → paramétrage ; sinon → conversation |

### Conversation avec l'avatar

| Fonctionnalité | État | Détail |
|---|---|---|
| Conversation façon Claude mobile | Codé | Réponses sans bulle, champ de saisie arrondi, menu latéral, thème clair et sombre |
| Envoi d'une photo | Codé | Bouton « + » : appareil photo ou galerie |
| Caméra déclenchée par l'avatar | Codé | Dire ou écrire « photo », « caméra » ou « foto » ouvre l'appareil photo |
| Suggestions de départ | Codé | Photographier une plante, symptômes courants, risque météo |
| Nouvelle conversation | Codé | Efface la conversation en cours |

### Diagnostic

| Fonctionnalité | État | Détail |
|---|---|---|
| Diagnostic par photo | Codé | Analyse d'image par l'IA via une Cloud Function (la clé n'est jamais dans l'app) |
| Diagnostic par texte ou voix | Codé | L'utilisateur décrit les symptômes ; « diagnostiquer » lance l'analyse sur tout ce qu'il a dit |
| Écran de résultat | Codé | Maladie, niveau de confiance coloré, traitement conseillé, bouton « Écouter le conseil » |
| Historique des diagnostics | Codé | Enregistré dans Firestore, consultable et rouvrable |
| Score de santé de l'exploitation | Partiel | Calculé côté téléphone à partir de l'historique. Le calcul est simple (part de diagnostics sans maladie) |

### Voix : l'avatar écoute et parle

| Fonctionnalité | État | Détail |
|---|---|---|
| Gros bouton « Appuyez et parlez » | Codé | Utilisable sans savoir lire |
| Réponse à l'oral | Codé | Une question posée à voix haute reçoit une réponse lue |
| Réponses parlées en continu | Codé | Interrupteur dans la barre du haut et dans le paramétrage |
| Choix de la langue à l'oreille | Codé | Un haut-parleur à côté de chaque langue dit une phrase d'accueil |
| Français et anglais | Codé | Moteurs du téléphone (gratuits) |
| Wolof | **À valider** | Passe par RodiumAI (transcription et synthèse). La documentation ne liste pas les langues supportées : tester la qualité avec la vraie clé |

### Météo, alertes et notifications

| Fonctionnalité | État | Détail |
|---|---|---|
| Écran Alertes météo | Codé | Prévisions à 3 jours (Open-Meteo, sans clé), risque de maladie fongique et de stress hydrique |
| Notification météo préventive | Codé | Chaque matin à 6 h, une fonction serveur prévient les utilisateurs dont la localité est à risque. Une alerte tous les 3 jours au maximum |
| Notifications de signalement | Codé | Alerte push à tous les abonnés quand un signalement est publié |
| Pas de SMS | Décision | Les notifications remplacent le SMS |

### Marché et entraide

| Fonctionnalité | État | Détail |
|---|---|---|
| Points de vente d'intrants | Codé | 9 adresses de Dakar et Thiès intégrées, triées par distance, avec **appeler, WhatsApp et itinéraire**. Données à confirmer par téléphone avant publication |
| Communauté (signalements) | Partiel | On peut publier et lire des signalements. Ils n'ont pas de coordonnées : l'alerte part à tous, pas seulement aux voisins |
| Marketplace | Partiel | On peut publier une annonce (culture, quantité, prix) et voir les annonces. **Aucun moyen de contacter le vendeur** |

### Design

| Fonctionnalité | État | Détail |
|---|---|---|
| Design system | Codé | Jetons d'espacement, de rayon et de couleurs sémantiques (succès, alerte, danger, info) dans `lib/theme.dart`, composants dans `lib/widgets/k_components.dart` |

---

## 2. Langues : chaque membre du groupe implémente la sienne

Aujourd'hui l'IA et la voix gèrent **français, anglais et wolof**. Les autres langues du groupe doivent être ajoutées **par les membres qui les parlent** : ce sont les seuls à pouvoir relire les textes et juger si la voix est compréhensible. Une traduction faite par une IA n'est pas suffisante pour un texte lu à des agriculteurs.

Chaque langue demande les étapes suivantes. Le wolof sert d'exemple dans le code.

1. **Déclarer la langue.** `lib/services/app_state.dart`, dans `supportedLanguages` : ajouter une ligne `'code': 'Nom'` (code ISO, deux lettres si possible, par exemple `'bm': 'Bambara'`).
2. **Phrase d'accueil.** `lib/services/voice_service.dart`, dans `greetings` : une phrase courte pour l'écran de choix de la langue, relue par un locuteur natif.
3. **Voix.** Si le téléphone ne gère pas la langue (c'est probable pour les langues locales) : ajouter le code dans `cloudLanguages` (même fichier), puis **tester avec la vraie clé RodiumAI** : dicter trois phrases, écouter trois réponses.
   - Si la qualité est mauvaise : essayer un autre modèle avec les variables `RODIUMAI_TTS_MODEL_<CODE>` (synthèse) et `RODIUMAI_STT_MODEL` (transcription) dans `functions/.env`, ou brancher un modèle ouvert derrière les fonctions `aiSpeech` et `aiTranscribe`.
   - Pour la transcription, ajouter le code dans `PROMPT_ONLY_LANGUAGES` de `functions/index.js` si les modèles ne reconnaissent pas ce code de langue.
4. **Consignes de style pour l'IA.** `lib/services/rodium_ai_service.dart`, fonction `_spokenStyle` : ajouter une consigne pour la langue (alphabet, mots techniques à garder en français). Vérifier que l'IA répond correctement en lui posant des questions agricoles.
5. **Caméra.** `lib/services/avatar_intents.dart` : ajouter le mot pour « photo » dans l'expression `_cameraWords` et la phrase de `cameraReply`.
6. **Notifications météo.** `functions/weather_rules.js`, dans `MESSAGES` : le titre et le texte des deux alertes (maladie, chaleur).
7. **Faire un essai complet** : choisir la langue, écouter l'accueil, parler à l'avatar, écouter la réponse, recevoir une alerte.

**Ce qui n'est pas encore traduit :** tous les textes de l'interface (boutons, menus, titres) sont en français. Seules les réponses de l'IA, la voix, la phrase d'accueil, la réponse caméra et les alertes météo suivent la langue choisie. Traduire l'interface est un chantier à part (internationalisation Flutter).

**Attention :** les textes en wolof déjà présents (accueil, caméra, alertes météo) sont des brouillons non relus. À faire valider avant toute présentation.

---

## 3. Ce qu'il reste à faire

### Bloquant (avant tout le reste)

1. Lancer le projet : `flutter create`, `flutter pub get`, `flutter analyze`, `flutter test`, puis corriger les erreurs.
2. Réglages natifs : `minSdkVersion 23`, permissions Android et iOS (liste dans le README), icône et écran de démarrage.
3. Brancher Firebase : `flutterfire configure`, déployer les règles et les fonctions, poser le secret `RODIUMAI_API_KEY`, activer les méthodes de connexion et ajouter l'empreinte SHA.
4. Créer l'index Firestore de la marketplace (filtre sur le statut et tri par date). Firestore en propose le lien dans l'erreur au premier lancement.

### À finir pour que l'app soit crédible

5. Tester la voix wolof et faire relire les textes wolof (voir section 2).
6. **Marketplace : ajouter le contact du vendeur** (téléphone et WhatsApp, avec le même mécanisme que les points de vente). Sans cela, une annonce ne sert à rien.
7. Confirmer les points de vente par téléphone, et en ajouter (fichier `lib/data/vendors_seed.dart`). Seuls Dakar et Thiès sont couverts.
8. Communauté : enregistrer les coordonnées des signalements pour n'alerter que les voisins.
9. Faire valider par un agronome les seuils des alertes météo (`functions/weather_rules.js` et `lib/services/weather_service.dart`, à garder identiques).
10. Parcourir les 13 écrans en clair et en sombre sur un vrai téléphone.

### Pas commencé

11. **Mode hors-ligne** : activer la persistance Firestore, garder les derniers diagnostics et conseils, afficher un bandeau « hors connexion ».
12. **Interface traduite** dans chaque langue (voir section 2).
13. Voix sur les autres écrans (météo, résultat de diagnostic) et notifications lues à voix haute.
14. Publication : comptes Google Play et Apple Developer.

### Idées, si le temps le permet

- Partage d'un diagnostic par WhatsApp.
- Calendrier cultural (semis, traitements, récolte).
- Cours du marché par produit.
- Journal de parcelle avec courbe d'évolution.
- Écran « impact » (diagnostics faits, pertes évitées) pour un pitch.

---

## 4. Décisions de conception

- **Une app pour les agriculteurs, pas pour les vendeurs.** Pas d'inscription de vendeurs : les points de vente sont des données intégrées à l'app, et l'agriculteur les contacte par appel ou WhatsApp.
- **Pas de SMS** : les notifications les remplacent.
- **La clé IA reste côté serveur** : l'app appelle les Cloud Functions `aiProxy`, `aiSpeech` et `aiTranscribe`, jamais RodiumAI directement.
- **Voix** : moteurs du téléphone pour le français et l'anglais (gratuits, rapides), RodiumAI pour les langues locales.
- **Design** : esprit de l'app Claude (fond crème, sobre) avec un accent vert et des couleurs d'état.

---

## 5. Où trouver quoi

| Sujet | Fichiers |
|---|---|
| Écran principal (conversation, micro, caméra) | `lib/screens/home_ai_screen.dart`, `lib/services/avatar_intents.dart` |
| Appels à l'IA | `lib/services/rodium_ai_service.dart`, `functions/index.js` |
| Voix | `lib/services/voice_service.dart` |
| Langues | `lib/services/app_state.dart` |
| Météo et alertes | `lib/services/weather_service.dart`, `functions/weather_rules.js` |
| Points de vente | `lib/data/vendors_seed.dart`, `lib/screens/vendors_map_screen.dart` |
| Design | `lib/theme.dart`, `lib/widgets/k_components.dart` |
| Règles de sécurité Firestore | `firestore.rules` |
| Installation et réglages natifs | `README.md` |

**Tests :** `flutter test` (profil, IA, voix, points de vente, météo, intentions de l'avatar) et `cd functions && npm test` (règles météo côté serveur).
