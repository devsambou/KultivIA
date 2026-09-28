import 'package:flutter/material.dart';

/// Design system KultivIA.
///
/// Esprit : app mobile Claude (fond crème, texte sombre, bulles discrètes,
/// champ de saisie arrondi) avec un accent vert. Suit le mode clair/sombre
/// du téléphone.
///
/// Tout passe par des jetons :
///  - [KSpace]  espacements (4 / 8 / 12 / 16 / 24 / 32)
///  - [KRadius] rayons (4 / 12 / 16 / 24 / pilule)
///  - [KStatus] couleurs sémantiques (succès, alerte, danger, info),
///              accessibles via `KultivTheme.status(context)`
///  - les couleurs de surface via les méthodes statiques de [KultivTheme]
///
/// Ne pas écrire de couleur, de rayon ou de marge en dur dans les écrans.

/// Jetons d'espacement.
class KSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Jetons de rayon.
class KRadius {
  static const BorderRadius xs = BorderRadius.all(Radius.circular(4));
  static const BorderRadius sm = BorderRadius.all(Radius.circular(12));
  static const BorderRadius md = BorderRadius.all(Radius.circular(16));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(24));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(28));
}

/// Un couple fond / texte pour un état (succès, alerte...).
@immutable
class StatusTone {
  const StatusTone(this.bg, this.fg);
  final Color bg;
  final Color fg;

  static StatusTone lerp(StatusTone a, StatusTone b, double t) =>
      StatusTone(Color.lerp(a.bg, b.bg, t)!, Color.lerp(a.fg, b.fg, t)!);
}

/// Couleurs sémantiques, exposées comme extension du thème.
@immutable
class KStatus extends ThemeExtension<KStatus> {
  const KStatus({required this.success, required this.warning, required this.danger, required this.info});

  final StatusTone success;
  final StatusTone warning;
  final StatusTone danger;
  final StatusTone info;

  static const light = KStatus(
    success: StatusTone(Color(0xFFE8F2E8), Color(0xFF1B5E20)),
    warning: StatusTone(Color(0xFFFBEBD0), Color(0xFF7A4A00)),
    danger: StatusTone(Color(0xFFF9DEDC), Color(0xFF8C1D18)),
    info: StatusTone(Color(0xFFDDEEF4), Color(0xFF0F4C63)),
  );

  static const dark = KStatus(
    success: StatusTone(Color(0xFF1F3A22), Color(0xFFA5D6A7)),
    warning: StatusTone(Color(0xFF4A3510), Color(0xFFF2B84B)),
    danger: StatusTone(Color(0xFF4A1F1C), Color(0xFFF2B8B5)),
    info: StatusTone(Color(0xFF1B3540), Color(0xFF8AC4D8)),
  );

  /// Score de santé (0 à 100) : bon, à surveiller, critique.
  StatusTone forScore(int score) => score >= 80 ? success : (score >= 50 ? warning : danger);

  /// Confiance d'un diagnostic (0.0 à 1.0) : élevée, moyenne, faible.
  StatusTone forConfidence(double c) => c >= 0.7 ? success : (c >= 0.4 ? warning : danger);

  @override
  KStatus copyWith({StatusTone? success, StatusTone? warning, StatusTone? danger, StatusTone? info}) => KStatus(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        info: info ?? this.info,
      );

  @override
  KStatus lerp(ThemeExtension<KStatus>? other, double t) {
    if (other is! KStatus) return this;
    return KStatus(
      success: StatusTone.lerp(success, other.success, t),
      warning: StatusTone.lerp(warning, other.warning, t),
      danger: StatusTone.lerp(danger, other.danger, t),
      info: StatusTone.lerp(info, other.info, t),
    );
  }
}

class KultivTheme {
  static const _green = Color(0xFF2E7D32);
  static const serif = ['Georgia', 'serif'];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF262624) : const Color(0xFFFAF9F5);
    final surfaceCard = dark ? const Color(0xFF30302E) : Colors.white;
    final line = dark ? const Color(0xFF444441) : const Color(0xFFE6E3D8);
    final scheme = ColorScheme.fromSeed(seedColor: _green, brightness: brightness).copyWith(surface: bg);

    const buttonShape = RoundedRectangleBorder(borderRadius: KRadius.sm);
    const buttonPadding = EdgeInsets.symmetric(horizontal: KSpace.xl, vertical: KSpace.md);
    const buttonMin = Size(64, 48);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      extensions: <ThemeExtension<dynamic>>[dark ? KStatus.dark : KStatus.light],
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: bg, surfaceTintColor: Colors.transparent),
      dividerTheme: DividerThemeData(color: line, thickness: 0.5, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonMin, padding: buttonPadding, shape: buttonShape),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: buttonMin, padding: buttonPadding, shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMin,
          padding: buttonPadding,
          shape: buttonShape,
          side: BorderSide(color: line),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: buttonShape)),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceCard,
        side: BorderSide(color: line),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: KRadius.sm),
      ),
    );
  }

  static bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color userBubble(BuildContext c) => isDark(c) ? const Color(0xFF141413) : const Color(0xFFF0EEE6);
  static Color composer(BuildContext c) => isDark(c) ? const Color(0xFF30302E) : Colors.white;
  static Color border(BuildContext c) => isDark(c) ? const Color(0xFF444441) : const Color(0xFFE6E3D8);
  static Color muted(BuildContext c) => Theme.of(c).colorScheme.onSurface.withAlpha(140);

  /// Couleurs sémantiques du thème courant.
  static KStatus status(BuildContext c) => Theme.of(c).extension<KStatus>() ?? KStatus.light;
}
