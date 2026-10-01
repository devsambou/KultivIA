import 'package:flutter/material.dart';

import 'scene_kit.dart';

/// Version 1 : port fidèle de kultivia_gate_fermier_scan.html.
/// Un fermier scanne une plante malade, un nuage l'arrose, elle devient saine.
/// Boucle de 10 s, aucun asset requis.
class KultivScanScene extends StatelessWidget {
  const KultivScanScene({super.key, this.width = 250});

  final double width;

  @override
  Widget build(BuildContext context) => SceneView(
        width: width,
        duration: const Duration(seconds: 10),
        semanticLabel:
            'Un fermier scanne une plante malade avec son téléphone, un nuage l\'arrose, la plante devient saine',
        draw: _draw,
      );
}

void _draw(Canvas c, double t, double ms, ScenePalette pal) {
  drawBackdrop(c, pal, ms, 170);

  // Plantes : la malade s'efface, la saine apparaît avec un petit rebond.
  c.fade(kf(t, const [[0, 1], [.54, 1], [.60, 0], [.94, 0], [1, 1]]), () => sickPlant(c));
  c.fade(kf(t, const [[0, 0], [.54, 0], [.60, 1], [.94, 1], [1, 0]]), () {
    final s = kf(t, const [[0, .92], [.54, .92], [.60, 1.06], [.64, 1], [.94, 1], [1, .92]]);
    c.zoom(s, 170, 145, () => goodPlant(c));
  });

  _farmer(c, t);

  // Faisceau et cadre de scan.
  final beam = kf(t, const [[0, 0], [.12, 0], [.16, .28], [.34, .28], [.38, 0], [1, 0]]);
  if (beam > .01) {
    c.drawPath(
      Path()
        ..moveTo(106, 76)
        ..lineTo(142, 90)
        ..lineTo(142, 148)
        ..lineTo(106, 84)
        ..close(),
      fill(0x7FD1E8, beam),
    );
  }
  scanFrame(c, 50 * pingPong(ms, 2200),
      kf(t, const [[0, 0], [.12, 0], [.16, 1], [.34, 1], [.38, 0], [1, 0]]));

  bubble(c, 'Plante malade', 170, 84,
      kf(t, const [[0, 0], [.26, 0], [.30, 1.1], [.34, 1], [.38, 1], [.42, 0], [1, 0]]),
      0xFBEBD0, 0x7A4A00);

  // Nuage + pluie.
  final cloudOp = kf(t, const [[0, 0], [.36, 0], [.44, 1], [.58, 1], [.66, 0], [1, 0]]);
  final cloudTx = kf(t, const [[0, -80], [.36, -80], [.44, 0], [.58, 0], [.66, 30], [1, 30]]);
  c.fade(cloudOp, () {
    c.save();
    c.translate(cloudTx, 0);
    rainCloud(c);
    c.restore();
  });
  rain(c, ms, kf(t, const [[0, 0], [.44, 0], [.46, 1], [.58, 1], [.60, 0], [1, 0]]));

  // Étincelles de guérison.
  final spk = kf(t, const [[0, 0], [.58, 0], [.64, 1.3], [.70, 1], [.78, 0], [1, 0]]);
  sparkle(c, 148, 104, 6, spk);
  sparkle(c, 198, 98, 6, spk);
  sparkle(c, 200, 124, 5, spk);

  bubble(c, 'Plante saine', 170, 76,
      kf(t, const [[0, 0], [.64, 0], [.68, 1.1], [.72, 1], [.90, 1], [.94, 0], [1, 0]]),
      0xE8F2E8, 0x1B5E20);
}

void _farmer(Canvas c, double t) {
  final skin = fill(0xE8B48A);
  final eye = fill(0x3B2A1E);

  c.box(54, 112, 8, 32, 3, fill(0x2F4B7C));
  c.box(66, 112, 8, 32, 3, fill(0x2F4B7C));
  c.seg(52, 84, 50, 106, stroke(0xE9794A, 7));
  c.box(50, 76, 28, 42, 8, fill(0xE9794A));
  c.dot(64, 64, 10, skin);
  c.dot(60.5, 64, 1.2, eye);
  c.dot(67.5, 64, 1.2, eye);

  // Chapeau.
  c.drawPath(
    Path()
      ..moveTo(54, 59)
      ..arcToPoint(const Offset(74, 59), radius: const Radius.elliptical(10, 8), clockwise: true)
      ..close(),
    fill(0xF2C94C),
  );
  c.oval(64, 59, 18, 4.5, fill(0xF2C94C));
  c.box(54, 56, 20, 2.5, 0, fill(0xC0392B));

  // Bras + téléphone.
  final arm = kf(t, const [
    [0, 60], [.06, 60], [.12, -6], [.36, -6], [.44, 40], [.60, 40], [.66, -50], [.86, -50], [.92, 60], [1, 60],
  ]);
  final glow = kf(t, const [[0, .4], [.12, .4], [.16, 1], [.34, 1], [.38, .4], [1, .4]]);
  c.turn(arm, 76, 82, () {
    c.seg(76, 82, 100, 82, stroke(0xE9794A, 7));
    c.box(98, 70, 8, 15, 2, fill(0x263238));
    c.fade(glow, () => c.box(99.5, 72, 5, 10, 1, fill(0x7FD1E8)));
    c.dot(100, 83, 3.6, skin);
  });
}
