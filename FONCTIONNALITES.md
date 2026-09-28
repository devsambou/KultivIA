# KultivIA - Fonctionnalites et etat d'avancement (Branche `skeleton`)

*Mis a jour le 28 septembre 2026.*

> **Etat global : SQUELETTE.** Tous les fichiers `lib/` sont la, seules les **signatures publiques** (classes, champs, methodes) sont conservees. Chaque corps de methode lance `UnimplementedError()`. Les widgets renvoient un `Scaffold` minimal avec le nom de l'ecran. **Rien ne fonctionne** : c'est une base de depart pour l'equipe de 5.

**Legende :** *Squelette* = signatures presentes, corps a implementer (voir `docs/ISSUES.md`) * *Core intact* = fondations communes (ne pas modifier sans prevenir l'equipe).

---

## 1. Ce que l'application DOIT faire (a implementer)

### Compte et parcours

| Fonctionnalite | Etat | Fichier(s) concerne(s) | Issue |
|---|---|---|---|
| Onboarding (3 ecrans) | Squelette | `lib/screens/onboarding/onboarding_screen.dart` | #TODO |
| Connexion / inscription (Email, Google, Apple, telephone) | Squelette | `lib/screens/auth/auth_screen.dart`, `lib/services/auth/firebase_service.dart` | #TODO |
| Parametrage 1ere connexion (3 etapes : identite, exploitation, preferences) | Squelette | `lib/screens/setup/` (5 fichiers) | #TODO |
| Profil (modif, langue, notifications, deconnexion) | Squelette | `lib/screens/settings/profile_screen.dart`, `lib/screens/settings/language_screen.dart` | #TODO |
| Routage au demarrage (GateScreen) | Squelette | `lib/screens/gate/gate_screen.dart` | #TODO |

### Conversation avec l'avatar

| Fonctionnalite | Etat | Fichier(s) concerne(s) | Issue |
|---|---|---|---|
| UI facon app mobile (bulles, composer, drawer) | Squelette | `lib/screens/home_ai/` (5 fichiers), `lib/widgets/app_drawer.dart` | #TODO |
| Envoi photo (camera/galerie) | Squelette | `lib/screens/home_ai/composer.dart` | #TODO |
| Camera declenchee par intention ("photo", "camera", "foto"...) | Squelette | `lib/services/ai/avatar_intents.dart` | #TODO |
| Suggestions de depart | Squelette | `lib/screens/home_ai/empty_state.dart` | #TODO |
| Nouvelle conversation | Squelette | `lib/screens/home_ai/home_ai_screen.dart` | #TODO |

### Diagnostic

| Fonctionnalite | Etat | Fichier(s) concerne(s) | Issue |
|---|---|---|---|
| Diagnostic par photo (Cloud Function `aiProxy`) | Squelette | `lib/services/ai/rodium_ai_service.dart` | #TODO |
| Diagnostic par texte/voix | Squelette | `lib/services/ai/rodium_ai_service.dart` | #TODO |
| Ecran resultat (maladie, confiance, traitement, ecouter) | Squelette | `lib/screens/health/diagnosis_result_screen.dart` | #TODO |
| Historique diagnostics (Firestore) | Squelette | `lib/screens/history/history_screen.dart`, `lib/repositories/firebase_diagnosis_repository.dart` | #TODO |
| Score sante exploitation | Squelette | `lib/screens/health/health_dashboard_screen.dart` | #TODO |

### Voix : l'avatar ecoute et parle

| Fonctionnalite | Etat | Fichier(s) concerne(s) | Issue |
|---|---|---|---|
| Bouton "Appuyez et parlez" | Squelette | `lib/screens/home_ai/composer.dart`, `lib/services/ui/voice_service.dart` | #TODO |
| Reponse a l'oral (STT -> IA -> TTS) | Squelette | `lib/services/ui/voice_service.dart` | #TODO |
| Reponses parlees en continu (interrupteur) | Squelette | `lib/services/system/user_settings.dart` | #TODO |
| Choix langue a l'oreille (phrase d'accueil par langue) | Squelette | `lib/screens/settings/language_screen.dart` | #TODO |
| FR/EN : moteurs natifs telephone | Squelette | `lib/services/ui/voice_service.dart` | #TODO |
| **Langues locales** (Wolof, Bambara, Lingala, Malgache...) : via RodiumAI (Cloud Functions) | Squelette | `lib/services/ui/voice_service.dart`, `functions/index.js` | #TODO |

### Meteo, alertes et notifications

| Fonctionnalite | Etat | Fichier(s) concerne(s) | Issue |
|---|---|---|---|
| Ecran Alertes meteo (Open-Meteo, 3 jours) | Squelette | `lib/screens/weather/weather_alerts_screen.dart`, `lib/services/external/weather_service.dart` | #TODO |
| Notification meteo preventive (6h locale, max 1/3j) | Squelette | `functions/weather_rules.js`, `lib/services/system/notification_service.dart` | #TODO |
| Notifications signalement (push topic `alerts`) | Squelette | `lib/services/system/notification_service.dart` | #TODO |

### Marche et entraide

| Fonctionnalite | Etat | Fichier(s) concerne(s) | Issue |
|---|---|---|---|
| Points de vente intrants (seed Dakar/Thies, distance, appel/WhatsApp/itineraire) | Squelette | `lib/data/vendors_seed.dart`, `lib/screens/market/vendors_map_screen.dart`, `lib/services/external/vendor_links.dart` | #TODO |
| Communaute (signalements geolocalises, alertes voisins) | Squelette | `lib/screens/community/community_screen.dart` | #TODO |
| Marketplace (annonces culture/quantite/prix + contact vendeur) | Squelette | `lib/screens/market/marketplace_screen.dart` | #TODO |

### Design System (CORE INTACT - ne pas modifier sans prevenir l'equipe)

| Element | Etat | Fichier |
|---|---|---|
| Jetons (KSpace, KRadius, KStatus) | **Core intact** | `lib/core/theme/theme.dart` |
| Composants (KCard, StatusChip, StatusBanner) | **Core intact** | `lib/widgets/k_components.dart` |
| Theme clair/sombre, Material 3 | **Core intact** | `lib/core/theme/theme.dart` |

---

## 2. Langues : chaque membre implemente la sienne

L'IA et la voix gerent **francais, anglais** + **langues locales** (squelettes presents : Wolof, Bambara, Lingala, Malgache...). Les langues locales doivent etre ajoutees **par les membres qui les parlent** (seuls a pouvoir valider textes et voix).

Etapes par langue (wolof = exemple dans le code) :
1. Declarer la langue : `UserSettings.supportedLanguages` (`lib/services/system/user_settings.dart`)
2. Phrase d'accueil : `VoiceService.greetings` (`lib/services/ui/voice_service.dart`) - relue par locuteur natif
3. Voix : si telephone ne gere pas -> ajouter dans `cloudLanguages`, tester avec **vraie cle RodiumAI**
4. Consignes style IA : `_spokenStyle` dans `lib/services/ai/rodium_ai_service.dart` (alphabet, mots techniques a garder en francais)
5. Camera : `_cameraWords` et `cameraReply` dans `lib/services/ai/avatar_intents.dart` (mots "photo" dans la langue)
6. Alertes meteo : `MESSAGES` dans `functions/weather_rules.js` (titre/texte alertes dans la langue)
7. Test complet : choisir langue -> ecouter accueil -> parler -> ecouter reponse -> recevoir alerte

> **Attention :** textes wolof existants = brouillons non relus. A valider avant demo. Meme processus pour chaque nouvelle langue.

---

## 3. Ce qu'il reste a faire (par ordre de priorite)

### Bloquant (avant tout le reste)
1. `flutter create --platforms=android,ios .` + `flutter pub get` + `flutter analyze` (OK) + `flutter test` (OK avec skip)
2. Reglages natifs : `minSdkVersion 23`, permissions Android/iOS, icone, splash screen
3. Firebase : `flutterfire configure`, deployer regles + functions, secret `RODIUMAI_API_KEY`, activer auth providers, empreinte SHA
4. Index Firestore marketplace (filtre statut + tri date)

### Pour credibilite
5. Tester voix wolof + faire relire textes wolof (voir §2) - **repeter pour chaque nouvelle langue**
6. **Marketplace : ajouter contact vendeur** (telephone/WhatsApp comme points de vente)
7. Confirmer points de vente par telephone, en ajouter (`lib/data/vendors_seed.dart`)
8. Communaute : coordonnees signalements -> alerter voisins seulement
9. Valider seuils alertes meteo par agronome (`weather_rules.js` = `weather_service.dart`)
10. Parcourir les 13+ ecrans en clair/sombre sur vrai telephone

### Non commence
11. Mode hors-ligne (persistance Firestore, derniers diagnostics, bandeau "hors connexion")
12. Interface traduite par langue (internationalisation Flutter - `intl` + arb)
13. Voix sur autres ecrans (meteo, resultat) + notifications lues a voix haute
14. Publication : comptes Google Play / Apple Developer

### Idees (si temps)
- Partage diagnostic WhatsApp
- Calendrier cultural
- Cours du marche par produit
- Journal de parcelle avec courbe d'evolution
- Ecran "impact" (diagnostics faits, pertes evitees) pour pitch

---

## 4. Decisions de conception (inchangées)

- **App pour agriculteurs** (pas inscription vendeurs) : points de vente = donnees integres
- **Pas de SMS** : notifications push uniquement
- **Cle IA cote serveur** : Cloud Functions `aiProxy`, `aiSpeech`, `aiTranscribe`
- **Voix** : natif FR/EN (gratuit, rapide), RodiumAI pour langues locales (cloud)
- **Design** : esprit app Claude (fond creme, sobre) + accent vert + couleurs d'etat

---

## 5. Ou trouver quoi (structure squelette)

| Sujet | Fichiers (signatures uniquement) |
|---|---|
| Ecran principal (conversation, micro, camera) | `lib/screens/home_ai/home_ai_screen.dart`, `lib/screens/home_ai/composer.dart`, `lib/services/ai/avatar_intents.dart` |
| Appels a l'IA (diagnostic, chat, TTS, STT) | `lib/services/ai/rodium_ai_service.dart`, `functions/index.js` |
| Voix (STT/TTS, natif + cloud multi-langues) | `lib/services/ui/voice_service.dart` |
| Langues & reglages utilisateur | `lib/services/system/user_settings.dart`, `lib/services/system/app_state.dart` |
| Meteo & alertes (Open-Meteo + regles) | `lib/services/external/weather_service.dart`, `functions/weather_rules.js` |
| Points de vente (seed + carte + liens) | `lib/data/vendors_seed.dart`, `lib/screens/market/vendors_map_screen.dart`, `lib/services/external/vendor_links.dart` |
| Design system & composants | `lib/core/theme/theme.dart`, `lib/widgets/k_components.dart` |
| Regles Firestore | `firestore.rules` |
| Installation & config native | `README.md` |
| **Liste issues par ecran/service** | `docs/ISSUES.md` |

---

## 6. Tests

- `test/user_profile_test.dart` : **conserve** (modeles intacts)
- Tous les autres tests : **remplaces par `skip: 'a implementer avec l'issue #TODO'`**
- Cote serveur : `cd functions && npm test` (regles meteo)

---

## 7. Regles d'equipe (voir `CONTRIBUTING.md`)

- 1 branche par issue (`feature/nom` ou `fix/nom`)
- PR obligatoire, revue par un pair
- Ne pas toucher `lib/core/` ni `lib/widgets/k_components.dart` sans prevenir l'equipe
- `flutter analyze` sans erreur avant merge
- **Nouvelle langue = proprietaire dedie** (membre qui parle la langue)
