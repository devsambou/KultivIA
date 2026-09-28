import '../models/diagnosis.dart';

/// Interface pour la persistance des diagnostics.
/// Permet de découpler l'UI de l'implémentation Firebase (et future cache local).
abstract class DiagnosisRepository {
  /// Sauvegarde un diagnostic dans le backend.
  Future<void> saveDiagnosis(Diagnosis diagnosis);

  /// Observe l'historique des diagnostics de l'utilisateur connecté.
  /// Retourne un stream vide si non connecté.
  Stream<List<Diagnosis>> watchDiagnoses();

  /// Supprime un diagnostic par son ID.
  Future<void> deleteDiagnosis(String diagnosisId);

  /// Nettoie les ressources (ex: annule les abonnements stream).
  Future<void> dispose();
}