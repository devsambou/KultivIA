# KultivIA

Diagnostic IA des maladies de cultures par photo, texte ou voix.
Hackathon FFSC 2026.

**Liste complète des fonctionnalités, état d'avancement, reste à faire et consignes pour ajouter une langue : voir [FONCTIONNALITES.md](FONCTIONNALITES.md).**

**Organisation du code, source de vérité des données et règles de synchronisation : voir [ARCHITECTURE.md](ARCHITECTURE.md).**

## Qui fait quoi

| | Rôle |
|---|---|
| **Firebase** | Source de vérité : authentification (Firebase Auth), Firestore (profils, diagnostics, discussions), notifications |
| **Supabase** | Passerelle IA (Edge Functions) + copie PostgreSQL des profils et diagnostics |

Il n'y a **qu'un seul compte utilisateur**, c'est celui de Firebase. Supabase n'a pas d'authentification : les fonctions reçoivent le jeton Firebase et le vérifient elles-mêmes (`supabase/functions/_shared/rodium.ts`).

## Configuration

### Firebase
- Créer `android/app/google-services.json` avec votre configuration Firebase
- Configurer les providers d'authentification dans la console Firebase

### Supabase

Créer un fichier `.env` à la racine du projet (ce fichier n'est pas versionné) :

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key

# Miroir PostgreSQL. false = seul Firestore est écrit.
SIMULTANEOUS_WRITES=true
```

Puis, dans la console Supabase :
- Déployer les migrations de `supabase/migrations/` (ou via la CLI Supabase)
- Déployer les fonctions : `supabase/functions/` (`ai-proxy`, `ai-speech`, `ai-transcribe`, `sync-write`)
- Définir les secrets : `RODIUM_API_KEY`, `FIREBASE_PROJECT_ID`

Vérifier que le miroir est à jour : `select count(*) from sync_gap;` doit renvoyer `0`.

## Développement

```bash
flutter pub get
flutter analyze
flutter test
flutter run
