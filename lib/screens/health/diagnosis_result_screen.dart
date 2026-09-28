// Écran de résultat de diagnostic. Issue GitHub : #TODO
import 'package:flutter/material.dart';
import '../../models/diagnosis.dart';

class DiagnosisResultScreen extends StatelessWidget {
  DiagnosisResultScreen({super.key, required this.diagnosis});
  final Diagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DiagnosisResultScreen')),
      body: const Center(child: Text('DiagnosisResultScreen - à implémenter')),
    );
  }
}
