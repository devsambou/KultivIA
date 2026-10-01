import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/diagnosis.dart';
import 'diagnosis_repository.dart';

/// Implémentation Firebase de [DiagnosisRepository].
/// Utilise les mêmes conventions que l'ancien FirebaseService pour la compatibilité.
class FirebaseDiagnosisRepository implements DiagnosisRepository {
  FirebaseDiagnosisRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _authOverride = auth,
        _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;

  bool get _isReady => Firebase.apps.isNotEmpty;

  String? get _currentUid => _isReady ? _auth.currentUser?.uid : null;

  CollectionReference<Map<String, dynamic>> _diagnosesCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('diagnoses');

  @override
  Future<void> saveDiagnosis(Diagnosis diagnosis) async {
    final uid = _currentUid;
    if (uid == null) return; // pas connecté → on ne persiste pas (comportement existant)
    await _diagnosesCol(uid).doc(diagnosis.id).set(diagnosis.toMap());
  }

  @override
  Stream<List<Diagnosis>> watchDiagnoses() {
    final uid = _currentUid;
    if (uid == null) return const Stream.empty();

    return _diagnosesCol(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
      final data = doc.data();
      return Diagnosis(
        id: data['id'] as String,
        date: DateTime.parse(data['date'] as String),
        imagePath: data['imagePath'] as String?,
        inputText: data['inputText'] as String? ?? '',
        disease: data['disease'] as String? ?? 'Indéterminé',
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
        advice: data['advice'] as String? ?? '',
        rawAiResponse: '',
      );
    }).toList());
  }

  @override
  Future<void> deleteDiagnosis(String diagnosisId) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _diagnosesCol(uid).doc(diagnosisId).delete();
  }

  @override
  Future<void> dispose() async {
    // Pas de ressources à nettoyer pour l'instant (les streams sont gérés par l'appelant)
  }
}