import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Ouvre la feuille de choix « Appareil photo / Photos » utilisée par le
/// bouton « + » du composer.
void showAttachSheet(
  BuildContext context, {
  required VoidCallback onCamera,
  required VoidCallback onGallery,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Row(
          children: [
            Expanded(
              child: _AttachTile(
                icon: Icons.photo_camera_outlined,
                label: 'Appareil photo',
                onTap: () {
                  Navigator.pop(ctx);
                  onCamera();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AttachTile(
                icon: Icons.photo_library_outlined,
                label: 'Photos',
                onTap: () {
                  Navigator.pop(ctx);
                  onGallery();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KultivTheme.userBubble(context),
      borderRadius: KRadius.md,
      child: InkWell(
        borderRadius: KRadius.md,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(label),
          ]),
        ),
      ),
    );
  }
}

/// Barre de saisie : champ texte, vignette de la photo jointe, micro,
/// bouton d'envoi. Sur le modèle de l'app mobile Claude.
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
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Container(
          padding: const EdgeInsets.all(KSpace.sm),
          decoration: BoxDecoration(
            color: KultivTheme.composer(context),
            borderRadius: KRadius.pill,
            border: Border.all(color: KultivTheme.border(context)),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(KultivTheme.isDark(context) ? 80 : 14), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imagePath != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: KRadius.sm,
                          child: Image.file(File(imagePath!),
                              width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 72)),
                        ),
                        Positioned(
                          top: 3,
                          right: 3,
                          child: GestureDetector(
                            onTap: onRemoveImage,
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              TextField(
                controller: controller,
                minLines: 1,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Décrivez le problème de votre culture…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Ajouter une photo',
                    onPressed: thinking ? null : onAttach,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(listening ? Icons.mic : Icons.mic_none, color: listening ? cs.error : null),
                    tooltip: 'Dicter',
                    onPressed: thinking ? null : onMic,
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: canSend ? cs.primary : cs.onSurface.withAlpha(30),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: canSend ? onSend : null,
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Icon(Icons.arrow_upward, size: 20, color: canSend ? cs.onPrimary : cs.onSurface.withAlpha(100)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
