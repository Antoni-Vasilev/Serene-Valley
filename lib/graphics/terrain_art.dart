import 'dart:math';

import 'palette.dart';
import 'pixel_canvas.dart';

/// Pixel-art textures for terrain tiles and the overlays that blend
/// neighbouring tiles together. Every tile is 16x16 pixels.
class TerrainArt {
  static const int size = 16;

  static PixelCanvas grass(Random r, List<int> ramp, {bool litter = false}) {
    final c = PixelCanvas(size, size)..fill(ramp[2]);
    // Mottled patches.
    for (var i = 0; i < 8; i++) {
      final x = r.nextInt(size);
      final y = r.nextInt(size);
      c.set(x, y, ramp[1]);
      c.set((x + 1) % size, y, ramp[1]);
    }
    for (var i = 0; i < 6; i++) {
      c.set(r.nextInt(size), r.nextInt(size), ramp[3]);
    }
    // Blades: a bright tip over a darker root.
    for (var i = 0; i < 5; i++) {
      final x = 1 + r.nextInt(14);
      final y = 1 + r.nextInt(12);
      c.set(x, y, ramp[4]);
      c.set(x, y + 1, ramp[3]);
      c.set(x + (r.nextBool() ? 1 : -1), y + 1, ramp[3]);
      c.set(x, y + 2, ramp[1]);
    }
    if (litter) {
      for (var i = 0; i < 2; i++) {
        c.set(r.nextInt(size), r.nextInt(size), Palette.dirt[1]);
      }
    }
    return c;
  }

  static PixelCanvas dirt(Random r) {
    const ramp = Palette.dirt;
    final c = PixelCanvas(size, size)..fill(ramp[2]);
    for (var i = 0; i < 12; i++) {
      c.set(r.nextInt(size), r.nextInt(size), ramp[1]);
    }
    for (var i = 0; i < 7; i++) {
      c.set(r.nextInt(size), r.nextInt(size), ramp[3]);
    }
    // Pebbles with a shadow underneath.
    for (var i = 0; i < 3; i++) {
      final x = 1 + r.nextInt(13);
      final y = 1 + r.nextInt(13);
      c.set(x, y, ramp[4]);
      c.set(x + 1, y, ramp[3]);
      c.set(x, y + 1, ramp[0]);
      c.set(x + 1, y + 1, ramp[0]);
    }
    return c;
  }

  static PixelCanvas sand(Random r) {
    const ramp = Palette.sand;
    final c = PixelCanvas(size, size)..fill(ramp[2]);
    // Wind ripples.
    for (var i = 0; i < 2; i++) {
      final y0 = 3 + i * 7 + r.nextInt(2);
      final phase = r.nextDouble() * 6;
      for (var x = 0; x < size; x++) {
        final y = y0 + (sin(x / 2.5 + phase) * 1.2).round();
        c.set(x, y, ramp[3]);
        c.set(x, y + 1, ramp[1]);
      }
    }
    for (var i = 0; i < 10; i++) {
      c.set(r.nextInt(size), r.nextInt(size), i.isEven ? ramp[4] : ramp[1]);
    }
    return c;
  }

  static PixelCanvas cobble(Random r) {
    const ramp = Palette.cobble;
    final c = PixelCanvas(size, size)..fill(ramp[1]);
    for (var gy = 0; gy < 4; gy++) {
      for (var gx = 0; gx < 4; gx++) {
        final offset = gy.isOdd ? 2.0 : 0.0;
        final cx = gx * 4 + 2 + offset + (r.nextDouble() - 0.5) * 0.6;
        final cy = gy * 4 + 2 + (r.nextDouble() - 0.5) * 0.6;
        c.shadedEllipse(cx % size, cy, 1.9, 1.7, ramp.sublist(2, 4));
      }
    }
    for (var i = 0; i < 4; i++) {
      c.set(r.nextInt(size), r.nextInt(size), ramp[4]);
    }
    return c;
  }

  static PixelCanvas stone(Random r) {
    const ramp = Palette.stone;
    final c = PixelCanvas(size, size)..fill(ramp[1]);
    for (final (x, y, radius) in [
      (3.5, 3.5, 3.6),
      (11.5, 3.0, 3.2),
      (8.0, 9.0, 4.0),
      (2.5, 12.0, 3.0),
      (13.0, 12.5, 3.2),
    ]) {
      c.shadedEllipse(
        x + r.nextDouble() - 0.5,
        y + r.nextDouble() - 0.5,
        radius,
        radius * 0.85,
        ramp.sublist(1),
        random: r,
        jitter: 0.12,
      );
    }
    for (var i = 0; i < 3; i++) {
      c.set(r.nextInt(size), r.nextInt(size), ramp[0]);
    }
    return c;
  }

  /// Open water. [frame] (0-3) moves the wave highlights back and forth.
  static PixelCanvas water(Random r, int frame) {
    const ramp = Palette.water;
    final c = PixelCanvas(size, size)..fill(ramp[2]);
    final streaks = [
      for (var i = 0; i < 4; i++) (r.nextInt(size), r.nextInt(size), 3 + r.nextInt(3)),
    ];
    final waves = [
      for (var i = 0; i < 3; i++) (r.nextInt(size), 2 + i * 5 + r.nextInt(2), 3 + r.nextInt(2)),
    ];
    for (final (x, y, length) in streaks) {
      for (var i = 0; i < length; i++) {
        c.set((x + i) % size, y, ramp[1]);
      }
    }
    final shift = const [0, 1, 2, 1][frame];
    for (final (x, y, length) in waves) {
      for (var i = 0; i < length; i++) {
        final color = i == 0 || i == length - 1 ? ramp[3] : ramp[4];
        c.set((x + i + shift) % size, y, color);
      }
    }
    return c;
  }

  /// Horizontal floor planks.
  static PixelCanvas woodFloor(Random r) {
    const ramp = Palette.wood;
    final c = PixelCanvas(size, size)..fill(ramp[2]);
    for (var row = 0; row < 4; row++) {
      final y = row * 4;
      c.rect(0, y, size, 1, ramp[3]);
      c.rect(0, y + 3, size, 1, ramp[0]);
      // Where one plank ends and the next begins.
      final joint = 2 + r.nextInt(12);
      c.rect(joint, y, 1, 3, ramp[0]);
      c.set(joint - 1, y + 1, ramp[1]);
      c.set(joint + 1, y + 1, ramp[1]);
      for (var i = 0; i < 3; i++) {
        c.set(r.nextInt(size), y + 1 + r.nextInt(2), ramp[1]);
      }
    }
    return c;
  }

  /// House walls seen from above: stacked logs.
  static PixelCanvas logs(Random r) {
    const ramp = Palette.logs;
    final c = PixelCanvas(size, size);
    for (var row = 0; row < 3; row++) {
      final y = row * 5;
      final h = row == 2 ? 6 : 5;
      c.rect(0, y, size, h, ramp[2]);
      c.rect(0, y, size, 1, ramp[4]);
      c.rect(0, y + 1, size, 1, ramp[3]);
      c.rect(0, y + h - 1, size, 1, ramp[0]);
      c.rect(0, y + h - 2, size, 1, ramp[1]);
      for (var i = 0; i < 3; i++) {
        c.set(r.nextInt(size), y + 2, ramp[1]);
      }
    }
    c.rect(0, 15, size, 1, ramp[0]);
    return c;
  }

  /// Bridge deck: planks running across the river.
  static PixelCanvas bridge(Random r) {
    const ramp = Palette.wood;
    final c = PixelCanvas(size, size)..fill(ramp[2]);
    for (var plank = 0; plank < 4; plank++) {
      final x = plank * 4;
      c.rect(x, 0, 1, size, ramp[3]);
      c.rect(x + 3, 0, 1, size, ramp[0]);
      c.set(x + 1, 2, ramp[0]);
      c.set(x + 1, 13, ramp[0]);
      for (var i = 0; i < 3; i++) {
        c.set(x + 1 + r.nextInt(2), r.nextInt(size), ramp[1]);
      }
    }
    return c;
  }

  /// Tilled soil with furrows; darker when watered.
  static PixelCanvas farmland(Random r, {required bool wet}) {
    final ramp = wet ? Palette.wetSoil : Palette.soil;
    final c = PixelCanvas(size, size)..fill(ramp[2]);
    for (var row = 0; row < 4; row++) {
      final y = row * 4;
      c.rect(0, y, size, 1, ramp[3]);
      c.rect(0, y + 2, size, 1, ramp[1]);
      c.rect(0, y + 3, size, 1, ramp[0]);
    }
    for (var i = 0; i < 6; i++) {
      final x = r.nextInt(size);
      final y = r.nextInt(4) * 4 + 1;
      c.set(x, y, ramp[3]);
    }
    if (wet) {
      for (var i = 0; i < 3; i++) {
        c.set(r.nextInt(size), r.nextInt(4) * 4 + 2, 0xFF3C5A78);
      }
    }
    return c;
  }

  // ---------------------------------------------------------------------------
  // Overlays

  /// Shallows and foam along a shore on the top edge of a water tile. The
  /// top edge also gets the shadow of the bank above.
  static PixelCanvas shore(Random r, int frame, {required bool bankShadow}) {
    const ramp = Palette.water;
    final c = PixelCanvas(size, size);
    final pattern = Random(frame * 31 + 7);
    for (var x = 0; x < size; x++) {
      final depth = 2 + r.nextInt(2);
      var y = 0;
      if (bankShadow) {
        c.set(x, 0, ramp[0]);
        c.set(x, 1, ramp[1]);
        y = 2;
      }
      if (pattern.nextDouble() < 0.75) c.set(x, y, Palette.foam);
      for (var i = 1; i <= depth; i++) {
        c.set(x, y + i, i == 1 ? ramp[4] : ramp[3]);
      }
    }
    return c;
  }

  /// Foam in the top-left corner of a water tile whose two neighbours there
  /// are water but whose diagonal neighbour is land.
  static PixelCanvas shoreCorner() {
    const ramp = Palette.water;
    final c = PixelCanvas(size, size);
    c.rect(0, 0, 2, 1, Palette.foam);
    c.set(0, 1, Palette.foam);
    c.rect(2, 0, 1, 2, ramp[4]);
    c.rect(0, 2, 2, 1, ramp[4]);
    c.set(1, 1, ramp[4]);
    c.set(3, 0, ramp[3]);
    c.set(0, 3, ramp[3]);
    return c;
  }

  /// A thin dark rim on the edge of land that meets water.
  static PixelCanvas landEdge() {
    final c = PixelCanvas(size, size);
    c.rect(0, 0, size, 1, 0x38000000);
    return c;
  }

  /// Grass spilling over the top edge of a path, dirt or sand tile.
  static PixelCanvas fringe(Random r, List<int> ramp) {
    final c = PixelCanvas(size, size);
    for (var x = 0; x < size; x++) {
      final depth = 1 + r.nextInt(3);
      for (var y = 0; y < depth; y++) {
        c.set(x, y, y == depth - 1 ? ramp[1] : ramp[2]);
      }
      if (r.nextDouble() < 0.2) c.set(x, 0, ramp[3]);
    }
    return c;
  }

  /// The face of a cliff along the bottom of a stone tile.
  static PixelCanvas cliffFace(Random r) {
    const ramp = Palette.stone;
    final c = PixelCanvas(size, size);
    c.rect(0, 10, size, 1, ramp[4]);
    for (var x = 0; x < size; x++) {
      for (var y = 11; y < size; y++) {
        final streak = (x + r.nextInt(2)) % 3 == 0;
        c.set(x, y, streak ? ramp[0] : ramp[1]);
      }
    }
    c.rect(0, 15, size, 1, ramp[0]);
    return c;
  }

  static PixelCanvas cliffTop() {
    const ramp = Palette.stone;
    final c = PixelCanvas(size, size);
    c.rect(0, 0, size, 1, ramp[4]);
    c.rect(0, 1, size, 1, ramp[3]);
    return c;
  }

  static PixelCanvas cliffSide({required bool left}) {
    const ramp = Palette.stone;
    final c = PixelCanvas(size, size);
    c.rect(left ? 0 : size - 1, 0, 1, size, left ? ramp[3] : ramp[0]);
    return c;
  }

  /// Shadow a cliff casts on the ground just below it.
  static PixelCanvas cliffShadow() {
    final c = PixelCanvas(size, size);
    c.rect(0, 0, size, 1, 0x50000000);
    c.rect(0, 1, size, 1, 0x30000000);
    c.rect(0, 2, size, 1, 0x18000000);
    return c;
  }

  /// Bridge rail along the top or bottom edge.
  static PixelCanvas bridgeRail({required bool top}) {
    const ramp = Palette.wood;
    final c = PixelCanvas(size, size);
    final y = top ? 0 : 13;
    c.rect(0, y, size, 3, ramp[1]);
    c.rect(0, y, size, 1, ramp[3]);
    c.rect(0, y + 2, size, 1, ramp[0]);
    for (final x in const [2, 10]) {
      c.rect(x, top ? 0 : 11, 3, 5, ramp[1]);
      c.rect(x, top ? 0 : 11, 1, 5, ramp[3]);
      c.rect(x + 2, top ? 0 : 11, 1, 5, ramp[0]);
    }
    return c;
  }

  /// Posts sticking out of the water where the bridge used to be.
  static PixelCanvas brokenPosts() {
    const ramp = Palette.wood;
    final c = PixelCanvas(size, size);
    for (final (x, y) in const [(3, 1), (11, 10)]) {
      c.set(x - 1, y + 5, Palette.foam);
      c.set(x + 3, y + 5, Palette.foam);
      c.rect(x, y + 5, 3, 1, Palette.foam);
      c.rect(x, y, 3, 5, ramp[1]);
      c.rect(x, y, 1, 5, ramp[3]);
      c.rect(x + 2, y, 1, 5, ramp[0]);
      c.rect(x, y, 3, 1, ramp[4]);
    }
    return c;
  }

  static PixelCanvas fencePost() {
    const ramp = Palette.wood;
    final c = PixelCanvas(size, size);
    c.rect(6, 3, 4, 10, ramp[2]);
    c.rect(6, 3, 1, 10, ramp[3]);
    c.rect(9, 3, 1, 10, ramp[0]);
    c.rect(6, 3, 4, 1, ramp[4]);
    c.rect(6, 13, 4, 1, 0x40000000);
    c.outline(Palette.outline);
    return c;
  }

  /// Rails from the post towards one side: 0 = up, 1 = right, 2 = down, 3 = left.
  static PixelCanvas fenceRail(int side) {
    const ramp = Palette.wood;
    final c = PixelCanvas(size, size);
    switch (side) {
      case 0:
        c.rect(7, 0, 2, 4, ramp[2]);
        c.rect(7, 0, 1, 4, ramp[3]);
        break;
      case 2:
        c.rect(7, 12, 2, 4, ramp[2]);
        c.rect(7, 12, 1, 4, ramp[3]);
        break;
      default:
        final x = side == 1 ? 10 : 0;
        for (final y in const [5, 9]) {
          c.rect(x, y, 6, 2, ramp[2]);
          c.rect(x, y, 6, 1, ramp[3]);
        }
    }
    return c;
  }
}

/// Rotates a square canvas a quarter turn clockwise.
PixelCanvas rotateClockwise(PixelCanvas c) {
  final result = PixelCanvas(c.height, c.width);
  for (var y = 0; y < c.height; y++) {
    for (var x = 0; x < c.width; x++) {
      result.set(c.height - 1 - y, x, c.get(x, y));
    }
  }
  return result;
}
