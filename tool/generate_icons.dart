// Draws the Android launcher icons from lib/graphics/icon_art.dart.
//
// Run from the project root with:
//   flutter test tool/generate_icons.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:serene_valley/graphics/icon_art.dart';
import 'package:serene_valley/graphics/pixel_canvas.dart';

const res = 'android/app/src/main/res';

// Launcher icons are 48dp; adaptive icon layers are 108dp.
const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

/// Scales [c] to [width] x [height] without smoothing.
PixelCanvas resize(PixelCanvas c, int width, int height) {
  final out = PixelCanvas(width, height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      out.set(x, y, c.get(x * c.width ~/ width, y * c.height ~/ height));
    }
  }
  return out;
}

Future<void> writePng(PixelCanvas c, String path) async {
  final image = c.toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  testWidgets('generate launcher icons', (tester) async {
    await tester.runAsync(() async {
      final flat = IconArt.flat();
      final foreground = IconArt.foreground();
      final background = IconArt.background();
      for (final MapEntry(key: density, value: scale) in densities.entries) {
        final dir = '$res/mipmap-$density';
        final legacy = (48 * scale).round();
        final layer = (108 * scale).round();
        await writePng(resize(flat, legacy, legacy), '$dir/ic_launcher.png');
        await writePng(resize(foreground, layer, layer), '$dir/ic_launcher_foreground.png');
        await writePng(resize(background, layer, layer), '$dir/ic_launcher_background.png');
      }
    });
  });
}
