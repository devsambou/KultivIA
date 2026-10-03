import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

enum _Scene { plant, scan, alert }

class _SlideData {
  const _SlideData(this.scene, this.title, this.text);
  final _Scene scene;
  final String title;
  final String text;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _SlideData(
      _Scene.plant,
      'Vos cultures, en bonne santé',
      'Chaque année, les maladies des cultures font perdre une part importante des récoltes des petits agriculteurs.',
    ),
    _SlideData(
      _Scene.scan,
      'Un diagnostic en une photo',
      'Prenez une photo, décrivez le symptôme ou parlez à l\'avatar : KultivIA identifie la maladie et propose un traitement.',
    ),
    _SlideData(
      _Scene.alert,
      'Toujours prévenu',
      'Recevez une alerte quand la météo favorise les maladies ou qu\'une épidémie est signalée près de chez vous.',
    ),
  ];

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      Navigator.of(context).pushReplacementNamed('/auth');
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _skip() => _controller.animateToPage(
    _slides.length - 1,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(KSpace.sm),
                child: Visibility(
                  visible: !_isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(onPressed: _skip, child: const Text('Passer')),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlidePage(data: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                    (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.all(KSpace.xs),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? cs.primary : cs.primary.withAlpha(77),
                    borderRadius: KRadius.xs,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KSpace.xl),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isLast
                        ? const Text('Commencer', key: ValueKey('go'))
                        : const Row(
                      key: ValueKey('next'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Suivant'),
                        SizedBox(width: KSpace.sm),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une slide : scène animée + titre + texte qui apparaissent en fondu.
class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.data});
  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SceneView(scene: data.scene),
          const SizedBox(height: KSpace.xxl),
          _FadeUp(
            child: Text(data.title, textAlign: TextAlign.center, style: tt.headlineSmall),
          ),
          const SizedBox(height: KSpace.lg),
          _FadeUp(
            delayMs: 120,
            child: Text(data.text, textAlign: TextAlign.center, style: tt.bodyLarge),
          ),
        ],
      ),
    );
  }
}

/// Apparition en fondu + légère montée, avec un délai optionnel.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.child, this.delayMs = 0});
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final total = 500 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.easeOut),
      child: child,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child),
      ),
    );
  }
}

/// Scène animée (plante / scan / alerte), dessinée sans aucun asset.
class _SceneView extends StatefulWidget {
  const _SceneView({required this.scene});
  final _Scene scene;

  @override
  State<_SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<_SceneView> with TickerProviderStateMixin {
  // Boucle continue (soleil, scan, cloche, ondes).
  late final AnimationController _loop =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  // Entrée jouée une seule fois (croissance, apparition des puces).
  late final AnimationController _intro =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();

  @override
  void dispose() {
    _loop.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = KultivTheme.status(context);

    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: Listenable.merge([_loop, _intro]),
        builder: (context, _) {
          final intro = _intro.value;
          final loop = _loop.value;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScenePainter(
                    scene: widget.scene,
                    loop: loop,
                    intro: intro,
                    cs: cs,
                    status: status,
                  ),
                ),
              ),
              if (widget.scene == _Scene.scan)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Opacity(
                    opacity: Curves.easeOut.transform(((intro - 0.6) / 0.4).clamp(0.0, 1.0)),
                    child: _Chip(tone: status.forConfidence(0.92), label: 'Mildiou · 92 %'),
                  ),
                ),
              if (widget.scene == _Scene.alert) ...[
                Align(
                  alignment: Alignment.bottomRight,
                  child: Transform.translate(
                    offset: Offset(0, -4 * math.sin(loop * 2 * math.pi)),
                    child: _Chip(tone: status.info, label: 'Pluie annoncée'),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 52,
                  child: Transform.scale(
                    scale: Curves.elasticOut.transform(((intro - 0.35) / 0.4).clamp(0.0, 1.0)),
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: status.danger.fg, shape: BoxShape.circle),
                      child: Text(
                        '1',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: status.danger.bg, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.tone, required this.label});
  final StatusTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: KSpace.xs + 2),
      decoration: BoxDecoration(color: tone.bg, borderRadius: KRadius.pill),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: tone.fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.scene,
    required this.loop,
    required this.intro,
    required this.cs,
    required this.status,
  });

  final _Scene scene;
  final double loop; // 0..1, en boucle
  final double intro; // 0..1, une seule fois
  final ColorScheme cs;
  final KStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200); // on dessine dans un repère 200 x 200
    canvas.drawCircle(
      const Offset(100, 100),
      92,
      Paint()..color = cs.primaryContainer.withAlpha(120),
    );
    switch (scene) {
      case _Scene.plant:
        _plant(canvas);
      case _Scene.scan:
        _scan(canvas);
      case _Scene.alert:
        _alert(canvas);
    }
    canvas.restore();
  }

  // ---------- Slide 1 : une plante qui pousse ----------
  void _plant(Canvas canvas) {
    // Sol
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 156), width: 92, height: 18),
      Paint()..color = cs.outlineVariant,
    );

    // Soleil qui pulse (halo + cœur)
    final pulse = math.sin(loop * 2 * math.pi);
    canvas.drawCircle(const Offset(150, 52), 20 + 3 * pulse, Paint()..color = status.warning.bg);
    canvas.drawCircle(const Offset(150, 52), 10, Paint()..color = status.warning.fg.withAlpha(170));

    // Tige qui monte
    final stemT = Curves.easeOut.transform((intro / 0.5).clamp(0.0, 1.0));
    canvas.drawLine(
      const Offset(100, 154),
      Offset(100, 154 - 62 * stemT),
      Paint()
        ..color = cs.primary
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Feuilles qui apparaissent l'une après l'autre
    _leaf(canvas, const Offset(76, 108), 24, 11, -0.52, _stage(0.45, 0.70), cs.primary.withAlpha(190));
    _leaf(canvas, const Offset(126, 96), 26, 12, 0.52, _stage(0.55, 0.80), cs.primary);
    _leaf(canvas, const Offset(100, 80), 12, 22, 0, _stage(0.65, 0.90), cs.primary.withAlpha(150));
  }

  double _stage(double a, double b) =>
      Curves.elasticOut.transform(((intro - a) / (b - a)).clamp(0.0, 1.0));

  void _leaf(Canvas c, Offset o, double rx, double ry, double angle, double s, Color col) {
    if (s <= 0) return;
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(angle);
    c.scale(s);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), Paint()..color = col);
    c.restore();
  }

  // ---------- Slide 2 : une feuille scannée ----------
  void _scan(Canvas canvas) {
    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(45, 28, 110, 140),
      const Radius.circular(14),
    );
    canvas.drawRRect(card, Paint()..color = cs.surface);
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = cs.outlineVariant,
    );

    // Feuille malade
    final leaf = Path()
      ..moveTo(100, 48)
      ..cubicTo(140, 68, 150, 118, 100, 148)
      ..cubicTo(50, 118, 60, 68, 100, 48)
      ..close();
    canvas.drawPath(leaf, Paint()..color = cs.primary.withAlpha(200));
    canvas.drawLine(
      const Offset(100, 56),
      const Offset(100, 140),
      Paint()
        ..color = cs.surface
        ..strokeWidth = 2,
    );
    final spot = Paint()..color = status.warning.fg.withAlpha(210);
    canvas.drawCircle(const Offset(84, 90), 6, spot);
    canvas.drawCircle(const Offset(116, 108), 5, spot);
    canvas.drawCircle(const Offset(92, 120), 4, spot);

    // Coins de cadrage
    final br = Paint()
      ..style = PaintingStyle.stroke
      ..color = cs.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void corner(double x, double y, double dx, double dy) => canvas.drawPath(
      Path()
        ..moveTo(x, y + dy * 14)
        ..lineTo(x, y)
        ..lineTo(x + dx * 14, y),
      br,
    );
    corner(52, 34, 1, 1);
    corner(148, 34, -1, 1);
    corner(52, 162, 1, -1);
    corner(148, 162, -1, -1);

    // Ligne de scan qui fait des allers-retours
    final ping = loop < 0.5 ? loop * 2 : 2 - loop * 2;
    final y = 44 + 104 * Curves.easeInOut.transform(ping);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(52, y, 96, 3), const Radius.circular(2)),
      Paint()..color = cs.primary.withAlpha(220),
    );
  }

  // ---------- Slide 3 : une cloche d'alerte ----------
  void _alert(Canvas canvas) {
    // Ondes qui s'étendent
    for (var i = 0; i < 2; i++) {
      final p = (loop + i * 0.5) % 1;
      canvas.drawCircle(
        const Offset(100, 104),
        56 * (0.5 + p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = cs.primary.withAlpha(((1 - p) * 150).round()),
      );
    }

    // Cloche qui se balance autour de son sommet
    final angle = 0.2 * math.sin(loop * 2 * math.pi * 2);
    canvas.save();
    canvas.translate(100, 54);
    canvas.rotate(angle);
    canvas.translate(-100, -54);

    final bell = Path()
      ..moveTo(100, 54)
      ..cubicTo(78, 54, 66, 72, 66, 94)
      ..lineTo(66, 116)
      ..lineTo(56, 130)
      ..lineTo(144, 130)
      ..lineTo(134, 116)
      ..lineTo(134, 94)
      ..cubicTo(134, 72, 122, 54, 100, 54)
      ..close();
    canvas.drawPath(bell, Paint()..color = cs.surface);
    canvas.drawPath(
      bell,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = cs.primary
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(100, 142), 8, Paint()..color = cs.primary);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.loop != loop || old.intro != intro || old.scene != scene || old.cs != cs;
}