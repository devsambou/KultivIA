// Widget message view (bulle de conversation). Issue GitHub : #TODO
import 'package:flutter/material.dart';
import '../../models/diagnosis.dart';

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.entry, required this.onCopy, required this.onSpeak});

  final ChatEntry entry;
  final VoidCallback onCopy;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
