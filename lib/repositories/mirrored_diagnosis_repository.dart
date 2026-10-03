import 'dart:async';

import '../models/diagnosis.dart';
import '../services/sync/supabase_mirror.dart';
import 'diagnosis_repository.dart';

/// Décorateur qui réplique chaque diagnostic vers Supabase après écriture.
///
/// Firestore reste la source de vérité : ce dépôt délègue tout à [_delegate] et
/// ne fait qu'ajouter une copie best-effort. Le lecteur comme l'écriture
/// restent ceux de Firestore.
///
/// Pourquoi un décorateur plutôt qu'une écriture directe dans
/// [FirebaseDiagnosisRepository] : le dépôt reste testable et inchangé, et la
/// réplication devient réversible en retirant le décorateur dans `main.dart`.
///
/// La suppression n'est pas répliquée : `sync-write` n'expose que l'ajout, et un
/// diagnostic effacé chez l'utilisateur ne doit pas réapparaître dans le
/// réplica. À traiter le jour où la lecture basculera.
class MirroredDiagnosisRepository implements DiagnosisRepository {
  MirroredDiagnosisRepository({
    required DiagnosisRepository delegate,
    required SupabaseMirror mirror,
  })  : _delegate = delegate,
        _mirror = mirror;

  final DiagnosisRepository _delegate;
  final SupabaseMirror _mirror;

  @override
  Future<void> saveDiagnosis(Diagnosis diagnosis) async {
    // Firestore d'abord. Si cette écriture échoue, la réplication n'a pas lieu
    // d'être : on ne copie jamais une ligne que la source n'a pas.
    await _delegate.saveDiagnosis(diagnosis);

    // Même carte que celle écrite par le délégué : `toMap()` regénèrerait un
    // horodatage différent de celui de la source.
    unawaited(_mirror.mirrorDiagnosis(diagnosis.toMap()));
  }

  @override
  Stream<List<Diagnosis>> watchDiagnoses() => _delegate.watchDiagnoses();

  @override
  Future<void> deleteDiagnosis(String diagnosisId) =>
      _delegate.deleteDiagnosis(diagnosisId);

  @override
  Future<void> dispose() => _delegate.dispose();
}