import 'dart:async';

import 'package:flutter/material.dart';

import '../models/diagnosis.dart';
import '../repositories/diagnosis_repository.dart';

/// Historique des diagnostics, découplé de [AppState] pour éviter les rebuilds
/// quand seul l'historique change (ex: nouvelle entrée, sync Firestore).
class DiagnosisHistory extends ChangeNotifier {
  final List<Diagnosis> _history = [];
  StreamSubscription<List<Diagnosis>>? _historySub;
  final DiagnosisRepository _repository;

  DiagnosisHistory(this._repository);

  List<Diagnosis> get history => List.unmodifiable(_history);

  /// Ajoute un diagnostic en tête de liste (optimiste).
  void addDiagnosis(Diagnosis diagnosis) {
    _history.insert(0, diagnosis);
    notifyListeners();
  }

  /// Synchronise l'historique local avec le flux du repository.
  void bindHistory() {
    _historySub?.cancel();
    _historySub = _repository.watchDiagnoses().listen((list) {
      _history
        ..clear()
        ..addAll(list);
      notifyListeners();
    }, onError: (_) {});
  }

  /// Supprime un diagnostic par son ID.
  void removeDiagnosis(String diagnosisId) {
    _history.removeWhere((d) => d.id == diagnosisId);
    notifyListeners();
  }

  /// Vide l'historique (ex: déconnexion).
  void clear() {
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _historySub?.cancel();
    super.dispose();
  }
}