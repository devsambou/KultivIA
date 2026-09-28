// Widget composer (barre de saisie). Issue GitHub : #TODO
import 'package:flutter/material.dart';

void showAttachSheet(
  BuildContext context, {
  required VoidCallback onCamera,
  required VoidCallback onGallery,
}) {
  throw UnimplementedError();
}

class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.imagePath,
    required this.listening,
    required this.canSend,
    required this.thinking,
    required this.onAttach,
    required this.onRemoveImage,
    required this.onMic,
    required this.onSend,
  });

  final TextEditingController controller;
  final String? imagePath;
  final bool listening;
  final bool canSend;
  final bool thinking;
  final VoidCallback onAttach;
  final VoidCallback onRemoveImage;
  final VoidCallback onMic;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
