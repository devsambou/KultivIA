# Contributing to KultivIA

## Branching Strategy

- **Une branche par issue** : `feature/nom-de-l-issue` ou `fix/nom-du-bug`
- La branche `main` est protégée, pas de push direct
- La branche `skeleton` sert de base de départ pour l'équipe

## Pull Requests

- **Pull request obligatoire** pour toute modification
- **Revue par au moins une autre personne** avant merge
- **CI désactivée pour l'instant** (flutter analyze, flutter test) - sera activée en fin de projet
- Description claire : quoi, pourquoi, comment tester

## Zones protégées (core team only)

Ne pas modifier sans prévenir l'équipe :
- `lib/core/` (thème, constantes, config, erreurs, JSON)
- `lib/widgets/k_components.dart` (design system)

Ces fichiers définissent les fondations communes. Toute modification impacte toute l'app.

## Style de code

- `flutter analyze` sans erreur (warnings tolérés pour l'instant)
- `flutter test` passe (tests skip autorisés pour le squelette)
- Formatage : `dart format .`
- Commentaires en français (langue du projet)

## Commits

- Messages clairs et atomiques (un commit = une logique)
- Préfixes : `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`

## Issues GitHub

- Une issue = une tâche traçable
- Labels : `screen`, `service`, `model`, `widget`, `infra`
- Assigner un propriétaire à la création

## Tests

- Tests unitaires pour la logique pure (models, utils, parsers)
- Tests widget pour les écrans critiques
- Mock les dépendances externes (Firebase, IA, HTTP)

## Documentation

- Mettre à jour `ARCHITECTURE.md` si structure modifiée
- Ajouter une entrée dans `docs/ISSUES.md` pour chaque nouvelle tâche
- README à jour pour les nouveaux contributeurs