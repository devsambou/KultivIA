// Widget empty state (état vide de conversation). Issue GitHub : #TODO
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.name,
    required this.listening,
    required this.onMic,
    required this.onCamera,
    required this.onPrompt,
    required this.onWeather,
  });

  final String? name;
  final bool listening;
  final VoidCallback onMic;
  final VoidCallback onCamera;
  final ValueChanged<String> onPrompt;
  final VoidCallback onWeather;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
