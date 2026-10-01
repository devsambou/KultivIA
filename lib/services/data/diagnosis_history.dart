// Historique des diagnostics. Issue GitHub : #TODO
import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/diagnosis.dart';
import '../../repositories/diagnosis_repository.dart';

/// Historique des diagnostics, découplé de [AppState] pour éviter les rebuilds
/// quand seul l'historique change.
class DiagnosisHistory extends ChangeNotifier {
  final List<Diagnosis> _history = [];
  StreamSubscription<List<Diagnosis>>? _historySub;
  final DiagnosisRepository _repository;

  DiagnosisHistory(this._repository);

  List<Diagnosis> get history => List.unmodifiable(_history);

  void addDiagnosis(Diagnosis diagnosis) {
    _history.insert(0, diagnosis);
    notifyListeners();
  }

  void bindHistory() {
    _historySub = _repository.watchDiagnoses().listen((list) {
      _history
        ..clear()
        ..addAll(list);
      notifyListeners();
    });
  }

  void removeDiagnosis(String diagnosisId) {
    _history.removeWhere((d) => d.id == diagnosisId);
    notifyListeners();
  }

  void clear() {
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _historySub?.cancel();
    _historySub = null;
    super.dispose();
  }
}