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
    throw UnimplementedError();
  }

  void bindHistory() {
    throw UnimplementedError();
  }

  void removeDiagnosis(String diagnosisId) {
    throw UnimplementedError();
  }

  void clear() {
    throw UnimplementedError();
  }

  @override
  void dispose() {
    throw UnimplementedError();
  }
}