import 'dart:math';

import 'palette.dart';
import 'pixel_canvas.dart';

/// Pixel-art sprites for things standing in the world.
class ObjectArt {
  /// A round leafy tree, 26x30 pixels, standing on the bottom row.
  static PixelCanvas oak(Random r, {bool apples = false}) {
    const w = 26, h = 30;
    final trunk = PixelCanvas(w, h);
    const bark = Palette.bark;
    for (var y = 15; y < h - 1; y++) {
      trunk.set(11, y, bark[3]);
      trunk.set(12, y, bark[2]);
      trunk.set(13, y, bark[1]);
      trunk.set(14, y, bark[0]);
    }
    // Roots.
    trunk.set(10, h - 2, bark[2]);
    trunk.set(15, h - 2, bark[0]);
    for (var i = 0; i < 4; i++) {
      trunk.set(12 + r.nextInt(2), 18 + r.nextInt(9), bark[0]);
    }
    trunk.outline(Palette.outline);

    final canopy = PixelCanvas(w, h);
    // Leafy clumps drawn back to front, each lit on its own.
    for (final k in const [
      [13.0, 10.0, 10.0, 8.5],
      [7.5, 12.0, 5.5, 5.0],
      [18.5, 12.0, 5.5, 5.0],
      [10.0, 6.5, 5.5, 5.0],
      [16.5, 6.5, 5.5, 5.0],
      [13.0, 14.5, 6.5, 4.5],
    ]) {
      canopy.shadedEllipse(
        k[0] + r.nextDouble() - 0.5,
        k[1] + r.nextDouble() - 0.5,
        k[2],
        k[3],
        Palette.leaves,
        random: r,
        jitter: 0.22,
      );
    }
    if (apples) {
      var placed = 0;
      while (placed < 5) {
        final x = 5 + r.nextInt(15);
        final y = 6 + r.nextInt(10);
        if (!canopy.isOpaque(x, y) || !canopy.isOpaque(x + 1, y + 1)) continue;
        canopy.set(x, y, Palette.apple[2]);
        canopy.set(x + 1, y, Palette.apple[1]);
        canopy.set(x, y + 1, Palette.apple[1]);
        canopy.set(x + 1, y + 1, Palette.apple[0]);
        placed++;
      }
    }
    canopy.outline(Palette.leavesOutline);
    trunk.stamp(canopy, 0, 0);
    return trunk;
  }

  /// A layered pine, 20x32 pixels.
  static PixelCanvas pine(Random r) {
    const w = 20, h = 32;
    final c = PixelCanvas(w, h);
    const bark = Palette.bark;
    for (var y = 24; y < h - 1; y++) {
      c.set(9, y, bark[3]);
      c.set(10, y, bark[1]);
    }
    const ramp = Palette.pine;
    for (var layer = 0; layer < 4; layer++) {
      final top = 1 + layer * 6;
      final bottom = top + 9;
      final halfWidth = 3.0 + layer * 2.0;
      for (var y = top; y <= bottom; y++) {
        final t = (y - top) / (bottom - top);
        final hw = 0.8 + t * halfWidth;
        for (var x = (9.5 - hw).floor(); x <= (9.5 + hw).ceil(); x++) {
          final s = (x + 0.5 - (9.5 - hw)) / (2 * hw);
          if (s < 0 || s > 1) continue;
          var index = s < 0.35
              ? 3
              : s < 0.7
                  ? 2
                  : 1;
          if (y == bottom) index = 0;
          if (r.nextDouble() < 0.12) index = (index + (r.nextBool() ? 1 : -1)).clamp(0, 4);
          c.set(x, y, ramp[index]);
        }
      }
    }
    c.outline(Palette.pineOutline);
    return c;
  }

  /// A boulder, 16x14 pixels. Out in the valley some are mossy; [ore]
  /// streaks it with seams of metal.
  static PixelCanvas rock(Random r, {bool mossy = true, List<int>? ore}) {
    final c = PixelCanvas(16, 14);
    const ramp = Palette.rock;
    c.shadedEllipse(8.5, 8, 6.2, 4.8, ramp, light: 0.05);
    c.shadedEllipse(5 + r.nextDouble(), 9.5, 3.4, 3, ramp);
    if (r.nextBool()) c.shadedEllipse(12, 10, 2.6, 2.4, ramp);
    final crack = 7 + r.nextInt(3);
    c.line(crack, 5, crack + 1, 8, ramp[0]);
    c.set(crack + 2, 9, ramp[0]);
    if (r.nextDouble() < 0.4 && mossy) {
      for (var i = 0; i < 5; i++) {
        c.tint(4 + r.nextInt(9), 4 + r.nextInt(3), Palette.grass[2 + r.nextInt(2)]);
      }
    }
    if (ore != null) {
      for (var i = 0; i < 5; i++) {
        final x = 3 + r.nextInt(10);
        final y = 5 + r.nextInt(6);
        c.tint(x, y, ore[2]);
        c.tint(x + 1, y, ore[1]);
        c.tint(x + 1, y + 1, ore[0]);
        c.tint(x - 1, y - 1, ore[3]);
      }
    }
    c.outline(Palette.rockOutline);
    return c;
  }

  /// A cluster of glowing crystals on a rocky base, 16x16 pixels.
  static PixelCanvas crystals(Random r) {
    final c = PixelCanvas(16, 16);
    c.shadedEllipse(8, 13, 5.5, 2.3, Palette.rock);
    const ramp = Palette.crystal;
    // Shards from the back to the front: base, tip, half width and lean.
    for (final (base, tip, halfWidth, lean) in [
      (5.0, 5 + r.nextInt(2), 1.6, -1.0),
      (11.0, 4 + r.nextInt(2), 1.6, 1.0),
      (8.0, 1 + r.nextInt(2), 2.2, 0.0),
    ]) {
      const bottom = 13;
      for (var y = tip; y <= bottom; y++) {
        final t = (y - tip) / (bottom - tip);
        final w = halfWidth * min(1.0, t * 3 + 0.15);
        final cx = base + lean * (1 - t) * 2;
        for (var x = (cx - w).floor(); x <= (cx + w).ceil(); x++) {
          final d = (x + 0.5 - cx) / max(w, 0.5);
          if (d.abs() > 1) continue;
          // Lit on the left face, dark on the right.
          c.set(x, y, d < -0.2 ? ramp[3] : (d < 0.35 ? ramp[2] : ramp[1]));
        }
      }
      c.set((base + lean * 1.6 - 0.5).round(), tip + 2, ramp[4]);
    }
    c.outline(0xFF1A1030);
    return c;
  }

  /// A thick cobweb strung across a tunnel.
  static PixelCanvas cobweb() {
    final c = PixelCanvas(16, 16);
    const thread = 0xF0E8E8F0;
    const faint = 0xB0D0D0DC;
    // Spokes from the middle out to the walls.
    for (final (x, y) in const [(0, 0), (7, 0), (15, 1), (15, 8), (15, 15), (8, 15), (0, 14), (0, 7)]) {
      c.line(8, 8, x, y, faint);
    }
    // Rings that sag a little under their own weight.
    for (final radius in const [1.8, 3.4, 5.0, 6.6]) {
      (int, int)? last;
      for (var i = 0; i <= 8; i++) {
        final a = i * pi / 4 + pi / 8;
        final x = (8 + cos(a) * radius).round();
        final y = (8 + sin(a) * radius * 0.9 + (sin(a) > 0 ? 0.6 : 0)).round();
        if (last != null) c.line(last.$1, last.$2, x, y, thread);
        last = (x, y);
      }
    }
    c.set(8, 8, 0xF0F0F0F6);
    return c;
  }

  /// Rocks and a snapped beam where a tunnel caved in.
  static PixelCanvas rubble(Random r) {
    final c = PixelCanvas(16, 16);
    for (final (x, y, rx, ry) in const [
      (3.5, 7.5, 2.6, 2.4),
      (12.5, 6.5, 2.5, 2.2),
      (8.0, 8.0, 4.0, 3.4),
      (5.0, 11.5, 4.2, 3.4),
      (11.0, 12.0, 4.0, 3.2),
    ]) {
      c.shadedEllipse(x + r.nextDouble() - 0.5, y, rx, ry, Palette.rock);
    }
    for (var i = 0; i < 5; i++) {
      final x = 3 + r.nextInt(10);
      final y = 6 + r.nextInt(7);
      c.tint(x, y, Palette.rock[0]);
      c.tint(x + 1, y + 1, Palette.rock[0]);
    }
    // The end of the beam pokes out of the pile.
    const wood = Palette.wood;
    c.line(1, 3, 6, 6, wood[1]);
    c.line(1, 2, 6, 5, wood[3]);
    c.line(2, 4, 6, 7, wood[0]);
    c.set(1, 3, wood[4]);
    c.outline(Palette.rockOutline);
    return c;
  }

  /// A few glowing cave mushrooms.
  static PixelCanvas mushrooms(Random r) {
    final c = PixelCanvas(16, 16);
    const cap = Palette.glowcap;
    final count = 2 + r.nextInt(2);
    for (var i = 0; i < count; i++) {
      final x = 3 + r.nextInt(10);
      final y = 6 + r.nextInt(6);
      final half = i == 0 ? 2 : 1;
      c.rect(x, y, 1, half + 2, 0xFFD8D0C0);
      c.rect(x - half, y - 1, half * 2 + 1, 1, cap[2]);
      c.rect(x - half + 1, y - 2, max(1, half * 2 - 1), 1, cap[3]);
      c.set(x - half, y - 1, cap[1]);
      c.set(x + half, y - 1, cap[1]);
    }
    c.outline(0xA0102428);
    return c;
  }

  /// Timber posts and a beam propping up the roof of a narrow tunnel,
  /// 16x24 pixels.
  static PixelCanvas timberFrame() {
    final c = PixelCanvas(16, 24);
    const wood = Palette.wood;
    for (final x in const [0, 13]) {
      c.rect(x, 4, 3, 20, wood[1]);
      c.rect(x, 4, 1, 20, wood[3]);
      c.rect(x + 2, 4, 1, 20, wood[0]);
    }
    c.rect(0, 1, 16, 4, wood[2]);
    c.rect(0, 1, 16, 1, wood[4]);
    c.rect(0, 4, 16, 1, wood[0]);
    c.set(1, 3, 0xFF2A2A2A);
    c.set(14, 3, 0xFF2A2A2A);
    c.outline(Palette.outline);
    return c;
  }

  /// An old mine cart with some ore still in it, 16x14 pixels.
  static PixelCanvas mineCart(Random r) {
    final c = PixelCanvas(16, 14);
    const steel = Palette.steel;
    const wood = Palette.wood;
    c.shadedEllipse(8, 5, 5.5, 2.6, Palette.rock);
    for (var i = 0; i < 4; i++) {
      c.tint(4 + r.nextInt(8), 3 + r.nextInt(3), Palette.rust[2]);
    }
    c.rect(1, 5, 14, 6, wood[1]);
    c.rect(1, 7, 14, 1, wood[0]);
    c.rect(1, 5, 14, 1, steel[3]);
    c.rect(1, 10, 14, 1, steel[1]);
    c.rect(1, 5, 1, 6, steel[2]);
    c.rect(14, 5, 1, 6, steel[1]);
    for (final x in const [4.0, 12.0]) {
      c.shadedEllipse(x, 11.5, 1.8, 1.8, steel);
    }
    c.outline(Palette.outline);
    return c;
  }

  /// A ladder up a shaft into daylight, standing against a rock face,
  /// 16x28 pixels.
  static PixelCanvas ladder() {
    final c = PixelCanvas(16, 28);
    c.ellipse(8, 6, 7, 5.5, 0xFF0E0C0E);
    c.ellipse(8, 5.5, 5.5, 4.2, 0xFF7E98AC);
    c.ellipse(8, 5, 4, 3, 0xFFB8D0DE);
    c.ellipse(7.5, 4.5, 2, 1.5, 0xFFE6F2F8);
    const wood = Palette.wood;
    for (final x in const [3, 11]) {
      c.rect(x, 2, 2, 26, wood[2]);
      c.rect(x, 2, 1, 26, wood[3]);
    }
    for (var y = 5; y < 28; y += 4) {
      c.rect(5, y, 6, 1, wood[1]);
      c.rect(5, y + 1, 6, 1, wood[0]);
    }
    return c;
  }

  /// The way into the old mine: a cave mouth framed in timber, boarded up
  /// until the elder hands over the key.
  static PixelCanvas mineEntrance({required bool open}) {
    final c = cave();
    const wood = Palette.wood;
    for (final x in const [1, 12]) {
      c.rect(x, 5, 3, 11, wood[1]);
      c.rect(x, 5, 1, 11, wood[3]);
      c.rect(x + 2, 5, 1, 11, wood[0]);
    }
    c.rect(0, 3, 16, 3, wood[2]);
    c.rect(0, 3, 16, 1, wood[4]);
    c.rect(0, 5, 16, 1, wood[0]);
    if (!open) {
      for (final y in const [7, 10, 13]) {
        c.rect(3, y, 10, 2, wood[2]);
        c.rect(3, y, 10, 1, wood[3]);
        c.set(4, y, 0xFF3A3A3A);
        c.set(11, y, 0xFF3A3A3A);
      }
    }
    return c;
  }

  /// The village forge, two tiles wide: a stone furnace with a chimney and
  /// an anvil on a stump. In ruins until it is rebuilt; once [built], its
  /// fire glows and flickers through [frame] 0-2.
  static PixelCanvas forge({required bool built, int frame = 0}) {
    const w = 32, h = 34;
    final c = PixelCanvas(w, h);
    const stone = Palette.stone;
    const wood = Palette.wood;
    const steel = Palette.steel;
    final r = Random(4100);
    final top = built ? 13 : 21;

    if (built) {
      c.rect(12, 1, 6, 13, stone[2]);
      c.rect(12, 1, 1, 13, stone[3]);
      c.rect(17, 1, 1, 13, stone[0]);
      for (var y = 4; y < 13; y += 3) {
        c.rect(12, y, 6, 1, stone[1]);
      }
      c.rect(11, 0, 8, 2, stone[3]);
      c.rect(13, 0, 4, 1, 0xFF1A1A1A);
    } else {
      // The stub of the fallen chimney.
      c.rect(12, 15, 6, 7, stone[2]);
      c.rect(12, 15, 1, 7, stone[3]);
      for (final (x, y) in const [(12, 14), (13, 13), (15, 14), (17, 14)]) {
        c.set(x, y, stone[2]);
      }
    }
    // The furnace, built of blocks, with a rounded top.
    for (var y = top; y < h; y++) {
      for (var x = 1; x < 20; x++) {
        final row = (y - top) ~/ 4;
        final mortar = (y - top) % 4 == 3 || (x + (row.isOdd ? 2 : 0)) % 5 == 0;
        c.set(x, y, mortar ? stone[1] : (x < 4 ? stone[3] : stone[2]));
      }
    }
    c.shadedEllipse(10.5, top + 1.0, 9.5, 3.5, stone.sublist(1));
    // The mouth of the furnace.
    for (var y = 23; y < h - 1; y++) {
      for (var x = 6; x < 15; x++) {
        final dx = (x + 0.5 - 10.5) / 4.5;
        final dy = (y + 0.5 - 27) / 4;
        if (y < 27 && dx * dx + dy * dy > 1) continue;
        if (!built) {
          c.set(x, y, 0xFF141012);
          continue;
        }
        final heat = (y - 23) / 10 + (1 - dx.abs()) * 0.5 + r.nextDouble() * 0.25 + (frame == 1 ? 0.1 : 0);
        c.set(x, y, Palette.fire[(heat * 3).floor().clamp(0, Palette.fire.length - 1)]);
      }
    }
    // The stump, and the anvil on it or knocked off beside it.
    c.rect(23, 27, 7, 7, wood[1]);
    c.rect(23, 27, 7, 1, wood[3]);
    c.rect(29, 27, 1, 7, wood[0]);
    if (built) {
      c.rect(22, 22, 9, 3, steel[2]);
      c.rect(22, 22, 9, 1, steel[4]);
      c.rect(20, 22, 2, 2, steel[2]);
      c.rect(24, 25, 5, 2, steel[1]);
    } else {
      c.rect(21, 30, 4, 4, steel[1]);
      c.rect(21, 30, 4, 1, Palette.rust[1]);
      // Fallen stones.
      for (final (x, y) in const [(2.5, 19.5), (19.5, 31.0), (7.5, 18.5)]) {
        c.shadedEllipse(x, y, 2.2, 1.8, Palette.rock);
      }
    }
    c.outline(Palette.outline);
    return c;
  }

  /// A torch held up in the hand. The flame flickers through [frame] 0-2.
  static PixelCanvas heldTorch(int frame) {
    const flames = [
      ['..r...', '..nr..', '.rnyr.', '.nyYn.', '.nyyn.'],
      ['...r..', '..rn..', '.rnyr.', '.nYyn.', '.nyyn.'],
      ['..r...', '.rn...', '.nyr..', 'rnYyn.', '.nyyn.'],
    ];
    return spriteFromRows(
      [...flames[frame], '.wwww.', '.WWWW.', '..bd..', '..bd..', '..bd..', '..bd..', '..bd..'],
      {
        'Y': Palette.fire[4],
        'y': Palette.fire[3],
        'n': Palette.fire[2],
        'r': Palette.fire[1],
        'w': 0xFF8E7656,
        'W': 0xFF5E4A36,
        'b': Palette.wood[3],
        'd': Palette.wood[1],
      },
    );
  }

  /// A crystal lantern held by its handle.
  static PixelCanvas heldLantern() => spriteFromRows(
        const ['..ooo..', '.o...o.', '.ooooo.', 'oxqqqxo', 'oxqPqxo', 'oxqqqxo', 'oxPqPxo', '.ooooo.', '..xxx..'],
        {
          'o': Palette.outline,
          'x': Palette.steel[1],
          'q': Palette.crystal[4],
          'P': Palette.crystal[3],
        },
      );

  /// A berry bush, 16x14 pixels, with or without berries.
  static PixelCanvas bush(Random r, {required bool berries}) {
    final c = PixelCanvas(16, 14);
    const ramp = Palette.leaves;
    c.shadedEllipse(8, 8, 6.4, 4.6, ramp, random: r, jitter: 0.2);
    c.shadedEllipse(4.5, 9.5, 3.4, 3.2, ramp, random: r, jitter: 0.2);
    c.shadedEllipse(11.5, 9.5, 3.4, 3.2, ramp, random: r, jitter: 0.2);
    if (berries) {
      for (final (x, y) in const [(4, 8), (7, 5), (10, 7), (12, 10), (6, 10)]) {
        c.set(x, y, Palette.berry[2]);
        c.set(x + 1, y, Palette.berry[1]);
        c.set(x, y + 1, Palette.berry[1]);
        c.set(x + 1, y + 1, Palette.berry[0]);
      }
    }
    c.outline(Palette.leavesOutline);
    return c;
  }

  static PixelCanvas flowers(Random r, int petal, int centre) {
    final c = PixelCanvas(16, 16);
    final count = 2 + r.nextInt(2);
    for (var i = 0; i < count; i++) {
      final x = 3 + r.nextInt(10);
      final y = 4 + r.nextInt(6);
      c.rect(x, y + 2, 1, 4, Palette.grass[1]);
      c.set(x + 1, y + 4, Palette.grass[3]);
      c.set(x - 1, y + 5, Palette.grass[2]);
      c.set(x - 1, y, petal);
      c.set(x + 1, y, petal);
      c.set(x, y - 1, petal);
      c.set(x, y + 1, petal);
      c.set(x, y, centre);
    }
    return c;
  }

  static PixelCanvas tallGrass(Random r) {
    final c = PixelCanvas(16, 16);
    const ramp = Palette.grass;
    for (var i = 0; i < 7; i++) {
      final x = 3 + r.nextInt(10);
      final height = 5 + r.nextInt(5);
      final lean = r.nextInt(3) - 1;
      for (var j = 0; j < height; j++) {
        final color = j == height - 1
            ? ramp[4]
            : j > height / 2
                ? ramp[3]
                : ramp[1];
        c.set(x + (j > height / 2 ? lean : 0), 14 - j, color);
      }
    }
    c.outline(0x70142A10);
    return c;
  }

  /// A cave mouth in a rock face.
  static PixelCanvas cave() {
    final c = PixelCanvas(16, 16);
    const ramp = Palette.stone;
    c.ellipse(8, 12, 6.5, 6.5, ramp[1]);
    c.ellipse(8, 12.5, 5, 5.5, 0xFF16161B);
    c.ellipse(8, 13.5, 3.5, 4, 0xFF08080B);
    for (final (x, y) in const [(3, 8), (4, 7), (5, 6), (6, 5)]) {
      c.set(x, y, ramp[4]);
    }
    return c;
  }

  /// A ring of stones with logs; lit fires flicker through [frame] 0-2.
  static PixelCanvas firePit({required bool lit, int frame = 0}) {
    final c = PixelCanvas(16, 16);
    final stones = [
      for (var i = 0; i < 8; i++) (8 + cos(i * pi / 4) * 5.2, 11.5 + sin(i * pi / 4) * 2.8),
    ];
    void drawStones(bool front) {
      for (final (x, y) in stones) {
        if ((y >= 11.5) == front) c.shadedEllipse(x, y, 1.7, 1.4, Palette.rock);
      }
    }

    drawStones(false);
    final logs = lit ? Palette.bark : const [0xFF222222, 0xFF2F2F2F, 0xFF3D3D3D, 0xFF4B4B4B];
    c.line(4, 13, 11, 10, logs[1]);
    c.line(4, 12, 11, 9, logs[2]);
    c.line(4, 9, 11, 12, logs[1]);
    c.line(4, 10, 11, 13, logs[3]);
    if (lit) {
      _flames(c, frame);
    } else {
      c.set(7, 11, 0xFF6E6E6E);
      c.set(9, 10, 0xFF5A5A5A);
    }
    drawStones(true);
    return c;
  }

  static void _flames(PixelCanvas c, int frame) {
    final r = Random(frame * 97 + 3);
    final sway = const [0.0, 0.7, -0.6][frame];
    for (final (cx, height, width, dir) in const [
      (8.0, 9.5, 3.0, 1.0),
      (5.8, 6.0, 1.8, -1.0),
      (10.2, 6.5, 1.8, -1.0),
    ]) {
      const base = 11.5;
      for (var y = (base - height).floor(); y <= base.floor(); y++) {
        final t = ((base - y) / height).clamp(0.0, 1.0);
        final hw = width * sqrt(1 - t) * (1 - t * 0.3);
        final centre = cx + sway * dir * t * 1.5;
        for (var x = (centre - hw).floor(); x <= (centre + hw).ceil(); x++) {
          final d = ((x + 0.5 - centre) / max(hw, 0.6)).abs();
          if (d > 1) continue;
          final heat = (1 - d) * (1 - t * 0.6) + r.nextDouble() * 0.15;
          c.set(x, y, Palette.fire[(heat * Palette.fire.length).floor().clamp(0, Palette.fire.length - 1)]);
        }
      }
    }
    // A spark or two.
    c.set(6 + frame * 2, 1 + frame, Palette.fire[3]);
    if (frame != 1) c.set(10 - frame, 3, Palette.fire[2]);
  }

  static PixelCanvas bed() {
    final c = PixelCanvas(16, 16);
    const wood = Palette.wood;
    c.rect(1, 1, 14, 14, wood[1]);
    c.rect(1, 1, 14, 3, wood[2]);
    c.rect(1, 1, 14, 1, wood[3]);
    c.rect(3, 4, 10, 3, 0xFFF2F2F2);
    c.rect(3, 6, 10, 1, 0xFFC8C8D0);
    c.rect(2, 7, 12, 7, 0xFFC0504D);
    c.rect(2, 7, 12, 1, 0xFFE07A70);
    c.rect(2, 10, 12, 1, 0xFFA84442);
    c.rect(2, 13, 12, 1, 0xFF8E3434);
    c.outline(Palette.outline);
    return c;
  }

  /// A carrot growing on farmland: 0 = seed, 1 = sprout, 2 = young, 3 = ripe.
  static PixelCanvas crop(int stage) {
    final c = PixelCanvas(16, 16);
    const leaf = Palette.grass;
    switch (stage) {
      case 0:
        c.ellipse(8, 11, 3.5, 1.6, Palette.soil[3]);
        c.rect(5, 12, 7, 1, Palette.soil[1]);
        c.set(7, 10, 0xFFE8D08A);
        c.set(9, 11, 0xFFE8D08A);
        return c;
      case 1:
        c.rect(8, 8, 1, 4, leaf[2]);
        c.rect(6, 8, 2, 1, leaf[3]);
        c.rect(9, 7, 2, 1, leaf[3]);
        c.set(6, 7, leaf[4]);
        c.set(10, 6, leaf[4]);
        break;
      case 2:
        for (final (x, y) in const [(5, 6), (8, 4), (11, 6)]) {
          c.line(8, 12, x, y, leaf[2]);
          c.line(9, 12, x + 1, y, leaf[3]);
          c.set(x, y, leaf[4]);
        }
        break;
      default:
        for (final (x, y) in const [(4, 4), (7, 2), (10, 2), (13, 4), (8, 1)]) {
          c.line(8, 11, x, y, leaf[1]);
          c.line(9, 11, x + 1, y, leaf[3]);
          c.set(x, y, leaf[4]);
        }
        c.rect(6, 11, 5, 3, Palette.carrot[1]);
        c.rect(6, 11, 5, 1, Palette.carrot[2]);
        c.rect(10, 12, 1, 2, Palette.carrot[0]);
        c.rect(6, 13, 5, 1, Palette.carrot[0]);
    }
    c.outline(0xFF1E4A1E);
    return c;
  }

  static PixelCanvas shadow(int w, int h) {
    final c = PixelCanvas(w, h);
    c.ellipse(w / 2, h / 2, w / 2, h / 2, Palette.shadow);
    return c;
  }

  /// Corner brackets marking what the action button will use.
  static PixelCanvas bracket() {
    final c = PixelCanvas(16, 16);
    const white = 0xFFFFFFFF;
    for (final (x, y, dx, dy) in const [(1, 1, 1, 1), (14, 1, -1, 1), (1, 14, 1, -1), (14, 14, -1, -1)]) {
      for (var i = 0; i < 4; i++) {
        c.set(x + i * dx, y, white);
        c.set(x, y + i * dy, white);
      }
    }
    c.outline(0xB0000000);
    return c;
  }

  // ---------------------------------------------------------------------------
  // Houses

  /// A shingled roof covering [widthTiles] x [heightTiles] tiles, plus three
  /// rows of shadow it casts on the wall below.
  static PixelCanvas roof(Random r, int widthTiles, int heightTiles, {bool chimney = false}) {
    final w = widthTiles * 16;
    final h = heightTiles * 16;
    final c = PixelCanvas(w, h + 3);
    const ramp = Palette.roof;
    final ridge = (h * 0.32).round();
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        int color;
        if (y < ridge) {
          // The far slope: darker, with fine rows.
          color = y % 4 == 3 ? ramp[0] : ramp[1];
        } else if (y < ridge + 2) {
          color = y == ridge ? ramp[4] : ramp[3];
        } else {
          final row = (y - ridge - 2) ~/ 5;
          final inRow = (y - ridge - 2) % 5;
          final seam = (x + (row.isOdd ? 3 : 0)) % 6 == 0;
          color = inRow == 0
              ? ramp[3]
              : inRow == 4
                  ? ramp[1]
                  : ramp[2];
          if (seam && inRow != 0) color = ramp[1];
        }
        c.set(x, y, color);
      }
    }
    for (var i = 0; i < w ~/ 3; i++) {
      final x = r.nextInt(w);
      final y = ridge + 3 + r.nextInt(h - ridge - 5);
      if (c.get(x, y) == ramp[2]) c.set(x, y, r.nextBool() ? ramp[3] : ramp[1]);
    }
    c.rect(0, 0, w, 1, ramp[0]);
    c.rect(0, 0, 1, h, ramp[0]);
    c.rect(w - 1, 0, 1, h, ramp[0]);
    c.rect(0, h - 2, w, 2, ramp[0]);
    c.rect(0, h, w, 1, 0x60000000);
    c.rect(0, h + 1, w, 1, 0x38000000);
    c.rect(0, h + 2, w, 1, 0x18000000);

    if (chimney) {
      const stone = Palette.stone;
      final x = w - 22;
      c.rect(x, ridge - 12, 8, 14, stone[2]);
      c.rect(x, ridge - 12, 2, 14, stone[3]);
      c.rect(x + 6, ridge - 12, 2, 14, stone[1]);
      for (var y = ridge - 9; y < ridge + 2; y += 3) {
        c.rect(x, y, 8, 1, stone[1]);
      }
      c.rect(x - 1, ridge - 13, 10, 2, stone[3]);
      c.rect(x + 2, ridge - 13, 4, 1, 0xFF1A1A1A);
    }
    return c;
  }

  /// The front wall of a house: wooden planks on a stone footing.
  static PixelCanvas facadeWall(Random r) {
    const wood = Palette.wood;
    const stone = Palette.stone;
    final c = PixelCanvas(16, 16)..fill(wood[2]);
    for (var x = 0; x < 16; x += 4) {
      c.rect(x, 0, 1, 16, wood[3]);
      c.rect(x + 3, 0, 1, 16, wood[0]);
    }
    for (var i = 0; i < 6; i++) {
      c.set(r.nextInt(16), r.nextInt(12), wood[1]);
    }
    c.rect(0, 13, 16, 3, stone[2]);
    c.rect(0, 13, 16, 1, stone[3]);
    for (var x = 2; x < 16; x += 5) {
      c.rect(x, 14, 1, 2, stone[0]);
    }
    c.rect(0, 15, 16, 1, stone[0]);
    return c;
  }

  /// A window; at night the room behind it is lit.
  static PixelCanvas facadeWindow(Random r, {required bool lit}) {
    final c = facadeWall(r);
    final frame = Palette.logs[0];
    c.rect(3, 2, 10, 9, frame);
    c.rect(4, 3, 8, 7, lit ? 0xFFFFC85A : 0xFF7FB6DE);
    if (lit) {
      c.rect(5, 4, 6, 5, 0xFFFFE29A);
    } else {
      c.set(5, 4, 0xFFD8F0FF);
      c.set(6, 4, 0xFFD8F0FF);
      c.set(5, 5, 0xFFD8F0FF);
      c.set(9, 7, 0xFFB8DCF5);
    }
    c.rect(7, 3, 1, 7, frame);
    c.rect(4, 6, 8, 1, frame);
    c.rect(2, 11, 12, 1, Palette.wood[3]);
    c.rect(2, 12, 12, 1, Palette.wood[0]);
    return c;
  }

  /// The front door, open when someone is about to walk through it.
  static PixelCanvas facadeDoor(Random r, {required bool open}) {
    final c = facadeWall(r);
    const wood = Palette.wood;
    c.rect(3, 1, 10, 15, Palette.logs[0]);
    if (open) {
      c.rect(4, 2, 8, 14, 0xFF1C130D);
      c.rect(4, 12, 8, 4, 0xFF3A2616);
      c.rect(4, 2, 2, 14, wood[1]);
      c.rect(4, 2, 1, 14, wood[3]);
    } else {
      c.rect(4, 2, 8, 14, wood[1]);
      for (final x in const [6, 9]) {
        c.rect(x, 2, 1, 14, wood[0]);
      }
      c.rect(4, 2, 8, 1, wood[3]);
      c.rect(4, 6, 8, 1, wood[0]);
      c.set(10, 9, 0xFFE8C34A);
      c.set(10, 10, 0xFFB08A2A);
    }
    return c;
  }
}
