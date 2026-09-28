# KultivIA 

Diagnostic IA des maladies de cultures par photo, texte ou voix.
Hackathon FFSC 2026.

**Liste complète des fonctionnalités, état d'avancement, reste à faire et consignes pour ajouter une langue : voir [FONCTIONNALITES.md](FONCTIONNALITES.md).**

## Configuration

### Firebase
- Créer `android/app/google-services.json` avec votre configuration Firebase
- Configurer les providers d'authentification dans la console Firebase

### Supabase
- Créer un fichier `.env` à la racine du projet avec:
  ```env
  SUPABASE_URL=https://your-project.supabase.co
  SUPABASE_ANON_KEY=your_anon_key
  GOOGLE_CLIENT_ID=your_google_client_id.apps.googleusercontent.com
  ```
- Configurer les providers d'authentification dans la console Supabase (Google, Apple, Phone)
- Ajouter le callback URL: `https://your-project.supabase.co/auth/v1/callback`

