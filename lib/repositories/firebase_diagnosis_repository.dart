// Implémentation Firebase du repository de diagnostics. Issue GitHub : #TODO
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/diagnosis.dart';
import 'diagnosis_repository.dart';

/// Implémentation Firebase de [DiagnosisRepository].
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

  bool get _isReady => FirebaseAuth.instance.app != null && Firebase.apps.isNotEmpty;
  String? get _currentUid => _isReady ? _auth.currentUser?.uid : null;

  CollectionReference<Map<String, dynamic>> _diagnosesCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('diagnoses');

  @override
  Future<void> saveDiagnosis(Diagnosis diagnosis) {
    throw UnimplementedError();
  }

  @override
  Stream<List<Diagnosis>> watchDiagnoses() {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteDiagnosis(String diagnosisId) {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() {
    throw UnimplementedError();
  }
}