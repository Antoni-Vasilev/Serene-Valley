import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A small pixel buffer for drawing pixel art in code.
///
/// Colours are 0xAARRGGBB integers; 0 is transparent.
class PixelCanvas {
  final int width;
  final int height;
  final Uint32List pixels;

  PixelCanvas(this.width, this.height) : pixels = Uint32List(width * height);

  PixelCanvas.copy(PixelCanvas other)
      : width = other.width,
        height = other.height,
        pixels = Uint32List.fromList(other.pixels);

  bool contains(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  int get(int x, int y) => contains(x, y) ? pixels[y * width + x] : 0;

  bool isOpaque(int x, int y) => get(x, y) >>> 24 != 0;

  void set(int x, int y, int color) {
    if (contains(x, y)) pixels[y * width + x] = color;
  }

  /// Sets a pixel only where something is already drawn.
  void tint(int x, int y, int color) {
    if (isOpaque(x, y)) set(x, y, color);
  }

  void fill(int color) => pixels.fillRange(0, pixels.length, color);

  void rect(int x, int y, int w, int h, int color) {
    for (var j = y; j < y + h; j++) {
      for (var i = x; i < x + w; i++) {
        set(i, j, color);
      }
    }
  }

  void line(int x0, int y0, int x1, int y1, int color) {
    final dx = (x1 - x0).abs();
    final dy = -(y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx + dy;
    while (true) {
      set(x0, y0, color);
      if (x0 == x1 && y0 == y1) return;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x0 += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y0 += sy;
      }
    }
  }

  void ellipse(double cx, double cy, double rx, double ry, int color) {
    for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
      for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
        final dx = (x + 0.5 - cx) / rx;
        final dy = (y + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1) set(x, y, color);
      }
    }
  }

  /// Fills an ellipse shaded like a ball lit from the top left. [ramp] runs
  /// from dark to light. [jitter] roughens the shading, e.g. for leaves.
  void shadedEllipse(
    double cx,
    double cy,
    double rx,
    double ry,
    List<int> ramp, {
    Random? random,
    double jitter = 0,
    double light = 0,
  }) {
    const lx = -0.5, ly = -0.7, lz = 0.5;
    for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
      for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
        final dx = (x + 0.5 - cx) / rx;
        final dy = (y + 0.5 - cy) / ry;
        final d2 = dx * dx + dy * dy;
        if (d2 > 1) continue;
        final dz = sqrt(1 - d2);
        var intensity = (dx * lx + dy * ly + dz * lz) * 0.5 + 0.5 + light;
        if (random != null && jitter > 0) {
          intensity += (random.nextDouble() - 0.5) * jitter;
        }
        final index = (intensity * ramp.length).floor().clamp(0, ramp.length - 1);
        set(x, y, ramp[index]);
      }
    }
  }

  /// Draws [other] on top with its top-left corner at (x, y).
  void stamp(PixelCanvas other, int x, int y) {
    for (var j = 0; j < other.height; j++) {
      for (var i = 0; i < other.width; i++) {
        final c = other.pixels[j * other.width + i];
        if (c >>> 24 != 0) set(x + i, y + j, c);
      }
    }
  }

  /// Adds a 1-pixel outline around everything drawn so far.
  void outline(int color) {
    final source = Uint32List.fromList(pixels);
    bool opaque(int x, int y) => contains(x, y) && source[y * width + x] >>> 24 != 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (opaque(x, y)) continue;
        if (opaque(x - 1, y) || opaque(x + 1, y) || opaque(x, y - 1) || opaque(x, y + 1)) {
          pixels[y * width + x] = color;
        }
      }
    }
  }

  PixelCanvas mirrored() {
    final result = PixelCanvas(width, height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        result.pixels[y * width + (width - 1 - x)] = pixels[y * width + x];
      }
    }
    return result;
  }

  /// Rasterises the canvas into an image with one image pixel per canvas pixel.
  ui.Image toImage() {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..isAntiAlias = false;
    for (var y = 0; y < height; y++) {
      var x = 0;
      while (x < width) {
        final c = pixels[y * width + x];
        var run = 1;
        while (x + run < width && pixels[y * width + x + run] == c) {
          run++;
        }
        if (c >>> 24 != 0) {
          paint.color = ui.Color(c);
          canvas.drawRect(ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), run.toDouble(), 1), paint);
        }
        x += run;
      }
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }
}

/// Builds a sprite from rows of characters, one per pixel, using [palette]
/// to look up each character's colour. Unknown characters are transparent.
PixelCanvas spriteFromRows(List<String> rows, Map<String, int> palette) {
  final canvas = PixelCanvas(rows.first.length, rows.length);
  for (var y = 0; y < rows.length; y++) {
    final row = rows[y];
    for (var x = 0; x < row.length; x++) {
      final color = palette[row[x]];
      if (color != null) canvas.set(x, y, color);
    }
  }
  return canvas;
}

/// Mixes two colours; [t] = 0 gives [a], 1 gives [b].
int mixColor(int a, int b, double t) {
  int channel(int shift) {
    final ca = (a >> shift) & 0xFF;
    final cb = (b >> shift) & 0xFF;
    return (ca + (cb - ca) * t).round().clamp(0, 255);
  }

  return (channel(24) << 24) | (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

int lighten(int color, double t) => mixColor(color, 0xFFFFFFFF | (color & 0xFF000000), t);

int darken(int color, double t) => mixColor(color, 0xFF000000 | (color & 0xFF000000), t);
