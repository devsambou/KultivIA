import 'package:flutter/material.dart';
import '../core/theme/theme.dart';

/// Carte plate du design system : fond « composer », bordure fine, rayon 16,
/// sans ombre. À utiliser à la place de `Card`.
class KCard extends StatelessWidget {
  const KCard({
    super.key,
    required this.child,
    this.color,
    this.margin = const EdgeInsets.symmetric(vertical: KSpace.xs),
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: margin,
      color: color ?? KultivTheme.composer(context),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: KRadius.md,
        side: BorderSide(color: KultivTheme.border(context)),
      ),
      child: child,
    );
  }
}

/// Pastille d'état (ex. « Confiance : 87 % », « Risque élevé »).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone, this.icon});

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: KSpace.xs),
      decoration: BoxDecoration(color: tone.bg, borderRadius: KRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone.fg),
            const SizedBox(width: KSpace.xs),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tone.fg)),
        ],
      ),
    );
  }
}

/// Bandeau d'information ou d'alerte, coloré selon [tone].
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.tone, required this.icon, required this.title, this.subtitle});

  final StatusTone tone;
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.lg),
      decoration: BoxDecoration(color: tone.bg, borderRadius: KRadius.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone.fg),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: tone.fg)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: KSpace.xs),
                    child: Text(subtitle!, style: TextStyle(color: tone.fg)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
