import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scene_kit.dart';

/// Version 2 : le fermier africain entre en marchant, scanne la plante,
/// la pluie la soigne, puis il repart. Pendant ce temps, une agricultrice
/// sème dans un sillon et les pousses sortent au fil de la boucle (12 s).
class KultivFarmScene extends StatelessWidget {
  const KultivFarmScene({super.key, this.width = 250});

  final double width;

  @override
  Widget build(BuildContext context) => SceneView(
        width: width,
        duration: const Duration(seconds: 12),
        semanticLabel:
            'Un fermier arrive en marchant et scanne une plante malade avec son téléphone, '
            'la pluie la soigne, pendant qu\'une agricultrice sème des graines dans un champ',
        draw: _draw,
      );
}

void _draw(Canvas c, double t, double ms, ScenePalette pal) {
  drawBackdrop(c, pal, ms, 158);
  _field(c, t, pal);
  _woman(c, t, ms);

  // Plante (repère de la version 1 décalé de -12 pour laisser la place au champ).
  c.save();
  c.translate(-12, 0);
  c.fade(kf(t, const [[0, 1], [.57, 1], [.61, 0], [.94, 0], [1, 1]]), () => sickPlant(c));
  c.fade(kf(t, const [[0, 0], [.57, 0], [.61, 1], [.94, 1], [1, 0]]), () {
    final s = kf(t, const [[0, .92], [.57, .92], [.61, 1.06], [.64, 1], [.94, 1], [1, .92]]);
    c.zoom(s, 170, 145, () => goodPlant(c));
  });
  c.restore();

  _farmer(c, t, ms);

  // Faisceau du téléphone.
  final beam = kf(t, const [[0, 0], [.22, 0], [.25, .28], [.39, .28], [.42, 0], [1, 0]]);
  if (beam > .01) {
    c.drawPath(
      Path()
        ..moveTo(102, 76)
        ..lineTo(130, 90)
        ..lineTo(130, 148)
        ..lineTo(102, 84)
        ..close(),
      fill(0x7FD1E8, beam),
    );
  }

  c.save();
  c.translate(-12, 0);
  scanFrame(c, 50 * pingPong(ms, 2200),
      kf(t, const [[0, 0], [.22, 0], [.25, 1], [.39, 1], [.42, 0], [1, 0]]));

  final cloudOp = kf(t, const [[0, 0], [.42, 0], [.46, 1], [.58, 1], [.62, 0], [1, 0]]);
  final cloudTx = kf(t, const [[0, -80], [.42, -80], [.47, 0], [.58, 0], [.64, 30], [1, 30]]);
  c.fade(cloudOp, () {
    c.save();
    c.translate(cloudTx, 0);
    rainCloud(c);
    c.restore();
  });
  rain(c, ms, kf(t, const [[0, 0], [.47, 0], [.48, 1], [.58, 1], [.59, 0], [1, 0]]));

  final spk = kf(t, const [[0, 0], [.59, 0], [.63, 1.3], [.67, 1], [.73, 0], [1, 0]]);
  sparkle(c, 148, 104, 6, spk);
  sparkle(c, 198, 98, 6, spk);
  sparkle(c, 200, 124, 5, spk);
  c.restore();

  bubble(c, 'Plante malade', 158, 84,
      kf(t, const [[0, 0], [.28, 0], [.31, 1.1], [.33, 1], [.39, 1], [.42, 0], [1, 0]]),
      0xFBEBD0, 0x7A4A00);
  bubble(c, 'Plante saine', 158, 76,
      kf(t, const [[0, 0], [.62, 0], [.65, 1.1], [.67, 1], [.76, 1], [.80, 0], [1, 0]]),
      0xE8F2E8, 0x1B5E20);
}

// ---------------------------------------------------------------------------
// Champ : bande de terre + pousses qui sortent peu à peu
// ---------------------------------------------------------------------------

const _sproutX = [186.0, 190.0, 194.5, 199.0, 203.0];
const _sproutStart = [.06, .18, .30, .42, .54];

void _field(Canvas c, double t, ScenePalette pal) {
  c.oval(195, 141.5, 22, 4, fill(pal.soil));
  final furrow = stroke(0x000000, 1, .18);
  c.seg(178, 140, 212, 140, furrow);
  c.seg(180, 143, 210, 143, furrow);

  for (var i = 0; i < _sproutX.length; i++) {
    final x = _sproutX[i];
    final g = kf(t, [[0, 0], [_sproutStart[i], 0], [_sproutStart[i] + .08, 1], [.93, 1], [1, 0]]);
    c.zoom(g, x, 141, () {
      c.seg(x, 141, x, 135, stroke(0x3E8E3A, 1.6));
      c.oval(x - 2.5, 136, 2.6, 1.3, fill(0x6BBF4E), -30);
      c.oval(x + 2.5, 135, 2.6, 1.3, fill(0x4FA83F), 30);
    });
  }
}

// ---------------------------------------------------------------------------
// Agricultrice : cycle de 3 s (se penche, puise, lance les graines)
// ---------------------------------------------------------------------------

void _woman(Canvas c, double t, double ms) {
  final p = (ms / 3000) % 1.0;
  final lean = 14 + 6 * math.sin(p * 2 * math.pi);
  final throwArm = kf(p, const [[0, 115], [.3, 125], [.55, 8], [.65, 20], [1, 115]]);

  final skin = fill(0x6E4126);
  final dark = fill(0x2B2018);
  final blouse = 0xE5A823;

  c.oval(226, 139, 13, 3, fill(0x000000, .15));
  c.save();
  c.translate(226, 138);
  c.scale(-0.85, 0.85); // elle regarde vers la gauche, vers le champ

  // Jambes et pieds.
  c.seg(-3, -10, -3, -2, stroke(0x6E4126, 4));
  c.seg(4, -10, 4, -2, stroke(0x6E4126, 4));
  c.oval(-1.5, 0, 4.5, 1.8, dark);
  c.oval(5.5, 0, 4.5, 1.8, dark);

  // Pagne en tissu imprimé.
  c.drawPath(
    Path()
      ..moveTo(-10, -34)
      ..lineTo(10, -34)
      ..lineTo(14, -8)
      ..lineTo(-14, -8)
      ..close(),
    fill(0x1E8A8A),
  );
  c.drawPath(
    Path()
      ..moveTo(-13.6, -11)
      ..lineTo(13.7, -11)
      ..lineTo(14, -8)
      ..lineTo(-14, -8)
      ..close(),
    fill(0xE9794A),
  );
  final dotP = fill(0xE1F5EE);
  for (final d in const [
    Offset(-6, -28), Offset(2, -29), Offset(8, -23), Offset(-8, -21),
    Offset(-1, -22), Offset(5, -16), Offset(-5, -15),
  ]) {
    c.dot(d.dx, d.dy, 1.2, dotP);
  }

  // Buste penché : haut, tête, foulard, bras.
  c.turn(lean, 0, -34, () {
    c.box(-8, -58, 16, 26, 6, fill(blouse));
    c.box(-2.5, -58, 5, 5, 1, skin);
    c.dot(0, -63, 8.5, skin);
    c.dot(-3.5, -62, 1.8, fill(0x5A331D));
    c.dot(4, -61, 1.1, fill(0x1B1209));
    c.oval(8.7, -59.5, 1.8, 1.5, skin);
    // Foulard (gele) avec nœud.
    c.oval(0, -69, 10.5, 5.5, fill(0xC2185B));
    c.oval(0, -67.4, 10.2, 1.5, fill(0xF2B84B));
    c.dot(-8, -72, 4, fill(0xE0457B));
    c.dot(-11.5, -69.5, 3, fill(0xC2185B));

    // Bras qui tient la calebasse de graines.
    c.turn(70, -1, -53, () {
      c.seg(-1, -53, 7, -53, stroke(blouse, 6));
      c.seg(7, -53, 16, -53, stroke(0x6E4126, 4.5));
      c.dot(16, -53, 2.6, skin);
    });
    c.oval(4.8, -34.5, 7, 4, fill(0xC98B4A));
    final seed = fill(0x4B2E17);
    c.dot(2, -37.5, 1.2, seed);
    c.dot(5.5, -38.2, 1.2, seed);
    c.dot(8.5, -36.8, 1.2, seed);

    // Bras qui lance.
    c.turn(throwArm, 2, -53, () {
      c.seg(2, -53, 10, -53, stroke(blouse, 6));
      c.seg(10, -53, 22, -53, stroke(0x6E4126, 4.5));
      c.dot(22, -53, 2.8, skin);
    });
  });

  // Graines : point de départ = position de la main au moment du lancer.
  final l = (14 + 6 * math.sin(.55 * 2 * math.pi)) * math.pi / 180;
  final hx = 2 + 22 * math.cos(8 * math.pi / 180);
  final hy = -53 + 22 * math.sin(8 * math.pi / 180);
  final sx = hx * math.cos(l) - (hy + 34) * math.sin(l);
  final sy = hx * math.sin(l) + (hy + 34) * math.cos(l) - 34;
  const landX = [32.0, 37.0, 42.0, 47.0];
  for (var k = 0; k < 4; k++) {
    final u = (p - .55 - k * .02) / .38;
    if (u <= 0 || u >= 1) continue;
    final x = sx + (landX[k] - sx) * u;
    final y = sy + (3 - sy) * u - 14 * math.sin(math.pi * u);
    final o = 1 - ((u - .8) / .2).clamp(0.0, 1.0);
    c.dot(x, y, 1.4, fill(0x4B2E17, o));
  }
  c.restore();
}

// ---------------------------------------------------------------------------
// Fermier africain : marche, scanne, célèbre, repart
// ---------------------------------------------------------------------------

void _farmer(Canvas c, double t, double ms) {
  final x = kf(t, const [[0, -30], [.18, 70], [.74, 70], [1, 285]]);
  final m = kf(t, const [[0, 1], [.16, 1], [.19, 0], [.74, 0], [.78, 1], [1, 1]]);
  final sw = math.sin(x / 22 * 2 * math.pi); // phase de pas liée à la distance : pas de glissement
  final bob = -sw.abs() * 1.6 * m;

  final armBase = kf(t, const [
    [0, 90], [.17, 90], [.23, -6], [.40, -6], [.46, 60], [.60, 60], [.66, -62], [.76, -62], [.82, 90], [1, 90],
  ]);
  final phone = kf(t, const [[0, 0], [.16, 0], [.20, 1], [.46, 1], [.50, 0], [1, 0]]);
  final glow = kf(t, const [[0, .4], [.2, .4], [.24, 1], [.40, 1], [.44, .4], [1, .4]]);

  const shirt = 0xE0A100;
  final skin = fill(0x7B4B2A);
  final eye = fill(0x1B1209);

  c.oval(x, 145, 14, 3, fill(0x000000, .15));
  c.save();
  c.translate(x, 144 + bob);

  // Bras de l'arrière-plan (dans l'ombre).
  c.turn(90 - 26 * sw * m, 0, -62, () {
    c.seg(0, -62, 12, -62, stroke(0xB88300, 7));
    c.seg(12, -62, 22, -62, stroke(0x5E361E, 5.5));
    c.dot(22, -62, 3, fill(0x5E361E));
  });

  // Jambes : la jambe de devant avance quand le bras de devant recule.
  c.turn(30 * sw * m, 0, -32, () {
    c.box(-4, -33, 8, 33, 3, fill(0x2B3C60));
    c.oval(3, -1, 6, 2.6, fill(0x2B2018));
  });
  c.turn(-30 * sw * m, 0, -32, () {
    c.box(-4, -33, 8, 33, 3, fill(0x3A4F7A));
    c.oval(3, -1, 6, 2.6, fill(0x2B2018));
  });

  // Chemise jaune à motifs.
  c.box(-10, -68, 20, 42, 8, fill(shirt));
  final dotP = fill(0xFFF1BF);
  for (final d in const [
    Offset(-5, -60), Offset(4, -58), Offset(-2, -50), Offset(6, -46),
    Offset(-6, -42), Offset(1, -36), Offset(-7, -31),
  ]) {
    c.dot(d.dx, d.dy, 1.4, dotP);
  }

  // Tête de profil.
  c.box(-3, -73, 6, 6, 2, skin);
  c.dot(0, -80, 10, skin);
  c.oval(-6, -80, 4, 5, fill(0x1B1209));
  c.dot(-4, -79, 2, fill(0x5E361E));
  c.dot(5, -81, 1.2, eye);
  c.oval(10, -79, 2.2, 1.8, skin);

  // Chapeau de paille.
  c.drawPath(
    Path()
      ..moveTo(-10, -84)
      ..arcToPoint(const Offset(10, -84), radius: const Radius.elliptical(10, 8), clockwise: true)
      ..close(),
    fill(0xE3C47A),
  );
  c.oval(0, -84, 18, 4.5, fill(0xD4B060));
  c.box(-9.5, -87, 19, 2.5, 0, fill(0x8C3B1E));

  // Bras de devant + téléphone.
  c.turn(armBase + 26 * sw * m, 2, -62, () {
    c.seg(2, -62, 14, -62, stroke(shirt, 7));
    c.seg(14, -62, 26, -62, stroke(0x7B4B2A, 5.5));
    c.dot(26, -62, 3.6, skin);
    c.fade(phone, () {
      c.box(24, -74, 8, 15, 2, fill(0x263238));
      c.fade(glow, () => c.box(25.5, -72, 5, 10, 1, fill(0x7FD1E8)));
    });
  });

  c.restore();
}
