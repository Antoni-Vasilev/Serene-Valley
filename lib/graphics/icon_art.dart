import 'dart:math';

import 'palette.dart';
import 'pixel_canvas.dart';

/// The app icon: a cottage and a tree on a hill at sunset.
///
/// Android draws app icons in two layers, each 36x36 pixels here. Only the
/// middle 22x22 pixels are sure to be visible; the launcher may crop the
/// rest into a circle or rounded square.
class IconArt {
  static const int size = 36;

  static PixelCanvas background() {
    final c = PixelCanvas(size, size);
    const sky = [0xFF2B3A67, 0xFF46457A, 0xFF6A5288, 0xFF8E6C9E, 0xFFC27E95, 0xFFE89A7E, 0xFFF4B66A];
    for (var y = 0; y < size; y++) {
      final band = min(sky.length - 1, y ~/ 4);
      final next = min(sky.length - 1, band + 1);
      for (var x = 0; x < size; x++) {
        // Dither the last row of each band into the next.
        final dither = y % 4 == 3 && (x + y).isEven;
        c.set(x, y, dither ? sky[next] : sky[band]);
      }
    }
    for (final (x, y) in const [(5, 3), (13, 6), (29, 2), (32, 8), (9, 10)]) {
      c.set(x, y, 0xFFFFF2C0);
    }
    // The sun peeks out from behind the tree.
    c.ellipse(14, 12, 5, 5, 0xFFFFC866);
    c.ellipse(14, 12, 3.8, 3.8, 0xFFFFE08A);

    // Far hills, then the near hill the cottage stands on.
    for (var x = 0; x < size; x++) {
      final far = 22 + (sin(x / 4.5) * 2).round();
      for (var y = far; y < size; y++) {
        c.set(x, y, y == far ? 0xFF8A6A9A : 0xFF5E4A7A);
      }
      final near = 27 + (sin(x / 7 + 1.2) * 1.5).round();
      for (var y = near; y < size; y++) {
        c.set(x, y, y == near ? Palette.grass[4] : (y < near + 2 ? Palette.grass[3] : Palette.grass[2]));
      }
    }
    return c;
  }

  static PixelCanvas foreground() {
    final c = PixelCanvas(size, size);
    const wood = Palette.wood;
    const roof = Palette.roof;

    // The tree.
    for (var y = 21; y < 29; y++) {
      c.set(10, y, Palette.bark[3]);
      c.set(11, y, Palette.bark[1]);
    }
    c.shadedEllipse(10.5, 18.5, 4.2, 4.6, Palette.leaves);

    // The cottage: walls, door and lit windows.
    c.rect(16, 21, 10, 8, wood[3]);
    for (var x = 16; x < 26; x += 3) {
      c.rect(x, 21, 1, 8, wood[2]);
    }
    c.rect(20, 24, 3, 5, wood[0]);
    c.set(22, 26, 0xFFE8C34A);
    c.rect(17, 23, 2, 2, 0xFFFFD27A);
    c.rect(24, 23, 2, 2, 0xFFFFD27A);

    // Roof and chimney.
    c.rect(23, 12, 2, 5, Palette.stone[2]);
    c.set(23, 12, Palette.stone[3]);
    for (var i = 0; i < 6; i++) {
      final y = 15 + i;
      c.rect(20 - i - 1, y, 2 * i + 4, 1, i == 0 ? roof[4] : (i.isOdd ? roof[3] : roof[2]));
    }
    c.rect(14, 21, 14, 1, roof[0]);

    c.outline(Palette.outline);

    // Smoke curling from the chimney.
    for (final (x, y) in const [(24, 10), (25, 9), (25, 8), (26, 7)]) {
      c.set(x, y, 0xD8E8E8EE);
    }
    return c;
  }

  /// Both layers flattened and cropped to the middle, for old launchers.
  static PixelCanvas flat({int crop = 24, int cornerRadius = 4}) {
    final full = background()..stamp(foreground(), 0, 0);
    final offset = (size - crop) ~/ 2;
    final c = PixelCanvas(crop, crop);
    for (var y = 0; y < crop; y++) {
      for (var x = 0; x < crop; x++) {
        // Round the corners.
        final cx = x < cornerRadius ? cornerRadius - x : (x >= crop - cornerRadius ? x - (crop - cornerRadius - 1) : 0);
        final cy = y < cornerRadius ? cornerRadius - y : (y >= crop - cornerRadius ? y - (crop - cornerRadius - 1) : 0);
        if (cx * cx + cy * cy > cornerRadius * cornerRadius) continue;
        c.set(x, y, full.get(x + offset, y + offset));
      }
    }
    return c;
  }
}
