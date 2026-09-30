import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/diagnosis.dart';
import '../../core/theme/theme.dart';

/// Une bulle de la conversation : message utilisateur (photo + texte) ou
/// réponse de l'avatar (texte + éventuelle carte de diagnostic).
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.entry, required this.onCopy, required this.onSpeak});

  final ChatEntry entry;
  final VoidCallback onCopy;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    if (entry.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 14, bottom: 4, left: 48),
          padding: const EdgeInsets.all(KSpace.md),
          decoration: BoxDecoration(color: KultivTheme.userBubble(context), borderRadius: KRadius.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (entry.imagePath != null)
                ClipRRect(
                  borderRadius: KRadius.sm,
                  child: Image.file(File(entry.imagePath!),
                      height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              if (entry.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: entry.imagePath != null ? 8 : 0),
                  child: SelectableText(entry.text, style: const TextStyle(fontSize: 16, height: 1.4)),
                ),
            ],
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(entry.text, style: const TextStyle(fontSize: 16, height: 1.5)),
          if (entry.diagnosis != null) _DiagnosisCard(diagnosis: entry.diagnosis!),
          Row(
            children: [
              Icon(Icons.eco, size: 18, color: cs.primary),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.copy_outlined, size: 18, color: KultivTheme.muted(context)),
                tooltip: 'Copier',
                onPressed: onCopy,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.volume_up_outlined, size: 18, color: KultivTheme.muted(context)),
                tooltip: 'Écouter',
                onPressed: onSpeak,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiagnosisCard extends StatelessWidget {
  const _DiagnosisCard({required this.diagnosis});
  final Diagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Material(
        color: KultivTheme.composer(context),
        shape: RoundedRectangleBorder(
          borderRadius: KRadius.md,
          side: BorderSide(color: KultivTheme.border(context)),
        ),
        child: InkWell(
          borderRadius: KRadius.md,
          onTap: () => Navigator.of(context).pushNamed('/result', arguments: diagnosis),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.eco_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(diagnosis.disease, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text('Confiance ${(diagnosis.confidence * 100).round()} % · voir le traitement',
                          style: TextStyle(fontSize: 13, color: KultivTheme.muted(context))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}