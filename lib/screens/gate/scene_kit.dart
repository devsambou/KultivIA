import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Interpolation par mots-clés, lissée entre deux clés (équivalent des @keyframes CSS).
/// [p] = liste de [temps 0..1, valeur], temps strictement croissants.
double kf(double t, List<List<double>> p) {
  if (t <= p.first[0]) return p.first[1];
  for (var i = 1; i < p.length; i++) {
    if (t <= p[i][0]) {
      final a = p[i - 1], b = p[i];
      var u = (t - a[0]) / (b[0] - a[0]);
      u = u * u * (3 - 2 * u);
      return a[1] + (b[1] - a[1]) * u;
    }
  }
  return p.last[1];
}

/// Va-et-vient 0..1..0 de période [periodMs].
double pingPong(double ms, double periodMs) =>
    0.5 - 0.5 * math.cos(2 * math.pi * ms / periodMs);

Color col(int rgb, [double o = 1]) =>
    Color(0xFF000000 | rgb).withAlpha((o.clamp(0.0, 1.0) * 255).round());

Paint fill(int rgb, [double o = 1]) => Paint()..color = col(rgb, o);

Paint stroke(int rgb, double w, [double o = 1]) => Paint()
  ..color = col(rgb, o)
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

extension SceneCanvas on Canvas {
  void oval(double cx, double cy, double rx, double ry, Paint p, [double rotDeg = 0]) {
    save();
    translate(cx, cy);
    if (rotDeg != 0) rotate(rotDeg * math.pi / 180);
    drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), p);
    restore();
  }

  void box(double x, double y, double w, double h, double r, Paint p) =>
      drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), p);

  void seg(double x1, double y1, double x2, double y2, Paint p) =>
      drawLine(Offset(x1, y1), Offset(x2, y2), p);

  void dot(double x, double y, double r, Paint p) => drawCircle(Offset(x, y), r, p);

  /// Rotation de [deg] degrés autour du point (px, py).
  void turn(double deg, double px, double py, VoidCallback draw) {
    save();
    translate(px, py);
    rotate(deg * math.pi / 180);
    translate(-px, -py);
    draw();
    restore();
  }

  /// Mise à l'échelle autour du point (px, py).
  void zoom(double s, double px, double py, VoidCallback draw) {
    if (s <= 0.001) return;
    save();
    translate(px, py);
    scale(s);
    translate(-px, -py);
    draw();
    restore();
  }

  /// Dessine [draw] avec une opacité de groupe [o].
  void fade(double o, VoidCallback draw) {
    if (o <= 0.01) return;
    if (o >= 0.99) {
      draw();
      return;
    }
    saveLayer(const Rect.fromLTWH(-100, -100, 500, 400),
        Paint()..color = Color.fromRGBO(0, 0, 0, o));
    draw();
    restore();
  }

  void label(String s, double cx, double cy, int rgb) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: col(rgb)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(this, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
}

// ---------------------------------------------------------------------------
// Palette clair / sombre
// ---------------------------------------------------------------------------

class ScenePalette {
  const ScenePalette(this.sky, this.hill1, this.hill2, this.soil);
  final int sky, hill1, hill2, soil;

  static const light = ScenePalette(0xD6ECF5, 0xBFDDA8, 0x9CCB86, 0x8B5E3C);
  static const dark = ScenePalette(0x2A4A5E, 0x2F5233, 0x3F7A43, 0x6A4630);

  static ScenePalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// ---------------------------------------------------------------------------
// Éléments communs aux deux scènes (repère 240 x 170)
// ---------------------------------------------------------------------------

void drawBackdrop(Canvas c, ScenePalette pal, double ms, double soilX) {
  c.drawRect(const Rect.fromLTWH(0, 0, 240, 170), fill(pal.sky));
  c.zoom(1 + 0.12 * pingPong(ms, 6000), 34, 30, () => c.dot(34, 30, 13, fill(0xF2B84B)));
  c.save();
  c.translate(12 * pingPong(ms, 12000), 0);
  c.oval(124, 34, 20, 7, fill(0xFFFFFF, .85));
  c.oval(112, 30, 11, 7, fill(0xFFFFFF, .85));
  c.restore();
  c.drawPath(
    Path()
      ..moveTo(0, 118)
      ..quadraticBezierTo(60, 96, 120, 112)
      ..quadraticBezierTo(180, 128, 240, 104)
      ..lineTo(240, 170)
      ..lineTo(0, 170)
      ..close(),
    fill(pal.hill1),
  );
  c.drawPath(
    Path()
      ..moveTo(0, 140)
      ..quadraticBezierTo(70, 124, 140, 136)
      ..quadraticBezierTo(210, 148, 240, 128)
      ..lineTo(240, 170)
      ..lineTo(0, 170)
      ..close(),
    fill(pal.hill2),
  );
  c.oval(soilX, 145, 28, 6, fill(pal.soil));
}

/// Plante malade, tige à x = 170 (le appelant translate si besoin).
void sickPlant(Canvas c) {
  c.drawPath(
    Path()
      ..moveTo(170, 145)
      ..cubicTo(170, 126, 172, 112, 184, 102),
    stroke(0xA89B4A, 4),
  );
  c.oval(160, 122, 15, 6, fill(0xD9B94A), -50);
  c.oval(184, 124, 15, 6, fill(0xCDAE45), 50);
  c.oval(190, 106, 12, 5, fill(0xD9B94A), 55);
  final spot = fill(0x8C5A2B);
  c.dot(156, 125, 2.2, spot);
  c.dot(163, 119, 2.0, spot);
  c.dot(187, 128, 2.2, spot);
  c.dot(192, 108, 2.0, spot);
}

/// Plante saine, tige à x = 170.
void goodPlant(Canvas c) {
  c.seg(170, 145, 170, 90, stroke(0x3E8E3A, 4));
  c.oval(156, 108, 16, 7, fill(0x6BBF4E), 35);
  c.oval(184, 102, 17, 7, fill(0x4FA83F), -35);
  c.oval(170, 90, 8, 14, fill(0x7FD165));
  c.dot(161, 127, 5.5, fill(0xE0523B));
  c.dot(180, 121, 5, fill(0xE0523B));
}

/// Cadre de scan (coins + ligne qui descend), repère de la plante à x = 170.
void scanFrame(Canvas c, double scanY, double o) {
  c.fade(o, () {
    final p = stroke(0x1FA38A, 2.5);
    c.drawPath(Path()..moveTo(142, 100)..lineTo(142, 90)..lineTo(152, 90), p);
    c.drawPath(Path()..moveTo(198, 100)..lineTo(198, 90)..lineTo(188, 90), p);
    c.drawPath(Path()..moveTo(142, 138)..lineTo(142, 148)..lineTo(152, 148), p);
    c.drawPath(Path()..moveTo(198, 138)..lineTo(198, 148)..lineTo(188, 148), p);
    c.box(144, 93 + scanY, 52, 2.5, 1.2, fill(0x1FA38A));
  });
}

void bubble(Canvas c, String text, double cx, double w, double scale, int bg, int fg) {
  c.zoom(scale, cx, 72, () {
    c.box(cx - w / 2, 62, w, 20, 10, fill(bg));
    c.label(text, cx, 72, fg);
  });
}

void rainCloud(Canvas c) {
  final p = fill(0xBFD3E0);
  c.oval(170, 28, 24, 9, p);
  c.oval(158, 24, 13, 9, p);
  c.oval(182, 23, 12, 8, p);
}

void rain(Canvas c, double ms, double o) {
  c.fade(o, () {
    for (var i = 0; i < 3; i++) {
      final u = ((ms / 700) + i * 0.33) % 1.0;
      final x = 160 + i * 10.0;
      c.seg(x, 42 + u * 50, x, 49 + u * 50, stroke(0x4A90B8, 2, 1 - u));
    }
  });
}

void sparkle(Canvas c, double x, double y, double r, double s) {
  c.zoom(s, x, y, () {
    final p = stroke(0xF2B84B, 2.5);
    c.seg(x, y - r, x, y + r, p);
    c.seg(x - r, y, x + r, y, p);
  });
}

// ---------------------------------------------------------------------------
// Widget hôte : boucle d'animation + CustomPaint + cadre arrondi
// ---------------------------------------------------------------------------

typedef SceneDraw = void Function(Canvas c, double t, double ms, ScenePalette pal);

class SceneView extends StatefulWidget {
  const SceneView({
    super.key,
    required this.duration,
    required this.draw,
    this.width = 250,
    this.semanticLabel,
  });

  final Duration duration;
  final SceneDraw draw;
  final double width;
  final String? semanticLabel;

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = ScenePalette.of(context);
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.width,
          child: AspectRatio(
            aspectRatio: 240 / 170,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: .5,
                ),
              ),
              child: CustomPaint(
                painter: _ScenePainter(_c, widget.duration, pal, widget.draw),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.anim, this.duration, this.pal, this.draw) : super(repaint: anim);

  final Animation<double> anim;
  final Duration duration;
  final ScenePalette pal;
  final SceneDraw draw;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 240);
    draw(canvas, anim.value, anim.value * duration.inMilliseconds, pal);
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.pal != pal;
}
