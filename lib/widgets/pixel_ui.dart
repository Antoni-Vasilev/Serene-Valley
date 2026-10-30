import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../graphics/ui_textures.dart';

/// Logical pixels per pixel of interface art, rounded so each art pixel
/// covers a whole number of device pixels.
double uiPixel(BuildContext context) => uiPixelFor(MediaQuery.devicePixelRatioOf(context));

double uiPixelFor(double devicePixelRatio) => max(2, (3 * devicePixelRatio).round()) / devicePixelRatio;

class UiColors {
  static const cream = Color(0xFFF3E3C3);
  static const ink = Color(0xFF3B2A1E);
  static const inkSoft = Color(0xFF7A5A3E);
  static const gold = Color(0xFFFFD54F);
  static const shadow = Color(0xFF140D08);
  static const faded = Color(0xFFA8957A);
  static const good = Color(0xFF9AE07A);
  static const dim = Color(0xA0000000);
}

/// Text in the pixel font. Light text gets a hard drop shadow.
TextStyle pixelText(double size, {Color color = UiColors.cream, bool bold = false, bool? shadow}) {
  final withShadow = shadow ?? color.computeLuminance() > 0.4;
  return TextStyle(
    fontFamily: 'Pixelify',
    fontSize: size,
    height: 1.2,
    color: color,
    fontVariations: [FontVariation('wght', bold ? 700 : 500)],
    shadows: withShadow ? [Shadow(color: UiColors.shadow, offset: Offset(0, max(1, size / 9)))] : null,
  );
}

class _NineSlice extends CustomPainter {
  final ui.Image image;
  final int border;
  final double pixel;

  _NineSlice(this.image, this.border, this.pixel);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(pixel);
    final dst = Rect.fromLTWH(0, 0, max(size.width / pixel, 2.0 * border), max(size.height / pixel, 2.0 * border));
    final centre = Rect.fromLTWH(
      border.toDouble(),
      border.toDouble(),
      image.width - 2.0 * border,
      image.height - 2.0 * border,
    );
    canvas.drawImageNine(image, centre, dst, Paint()..filterQuality = FilterQuality.none);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NineSlice old) => old.image != image || old.border != border || old.pixel != pixel;
}

/// A framed panel, e.g. a wooden window or a paper note.
class PixelPanel extends StatelessWidget {
  final PixelFrame frame;
  final Widget? child;
  final EdgeInsetsGeometry padding;

  const PixelPanel({
    super.key,
    this.frame = PixelFrame.wood,
    this.child,
    this.padding = const EdgeInsets.all(6),
  });

  @override
  Widget build(BuildContext context) {
    final px = uiPixel(context);
    return CustomPaint(
      painter: _NineSlice(UiTextures.instance.frame(frame), frame.border, px),
      child: Padding(
        padding: EdgeInsets.all(frame.border * px),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// An icon from the interface art. [size] is the width of a 12-pixel icon;
/// larger art keeps the same pixel size.
class PixelIcon extends StatelessWidget {
  final String name;
  final double size;
  final double opacity;

  const PixelIcon(this.name, {super.key, this.size = 24, this.opacity = 1});

  @override
  Widget build(BuildContext context) {
    final image = UiTextures.instance.icon(name);
    final scale = size / 12;
    return RawImage(
      image: image,
      width: image.width * scale,
      height: image.height * scale,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      opacity: opacity < 1 ? AlwaysStoppedAnimation(opacity) : null,
    );
  }
}

/// A meter, e.g. for health, filled to [value] (0-1).
class PixelBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;

  const PixelBar({super.key, required this.value, required this.color, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _BarPainter(value.clamp(0.0, 1.0), color, uiPixel(context)),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double value;
  final Color color;
  final double pixel;

  _BarPainter(this.value, this.color, this.pixel);

  @override
  void paint(Canvas canvas, Size size) {
    _NineSlice(UiTextures.instance.frame(PixelFrame.bar), PixelFrame.bar.border, pixel).paint(canvas, size);
    final inset = PixelFrame.bar.border * pixel;
    final inner = Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset);
    // Whole art pixels only, so the fill steps like the art around it.
    final filled = (inner.width * value / pixel).round() * pixel;
    if (filled <= 0) return;
    final paint = Paint();
    paint.color = color;
    canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, filled, inner.height), paint);
    paint.color = Color.lerp(color, Colors.white, 0.4)!;
    canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, filled, pixel), paint);
    paint.color = Color.lerp(color, Colors.black, 0.35)!;
    canvas.drawRect(Rect.fromLTWH(inner.left, inner.bottom - pixel, filled, pixel), paint);
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.value != value || old.color != color || old.pixel != pixel;
}

/// A chunky button that sinks in while pressed. Disabled without [onPressed].
class PixelButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final PixelButtonStyle style;
  final String? tooltip;
  final EdgeInsets padding;

  const PixelButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style = PixelButtonStyle.wood,
    this.tooltip,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  void _setDown(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final style = enabled ? widget.style : PixelButtonStyle.stone;
    final pressed = _down && enabled;
    final px = uiPixel(context);
    final textColor = switch (style) {
      PixelButtonStyle.gold => UiColors.ink,
      PixelButtonStyle.stone => const Color(0xFFD0D0D6),
      PixelButtonStyle.wood => UiColors.cream,
    };

    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setDown(true) : null,
      onTapUp: enabled ? (_) => _setDown(false) : null,
      onTapCancel: enabled ? () => _setDown(false) : null,
      onTap: widget.onPressed,
      child: CustomPaint(
        painter: _NineSlice(UiTextures.instance.button(style, pressed: pressed), 4, px),
        child: Padding(
          // The face of the button moves down two pixels when pressed.
          padding: widget.padding +
              EdgeInsets.fromLTRB(3 * px, (pressed ? 4 : 2) * px, 3 * px, (pressed ? 2 : 4) * px),
          child: DefaultTextStyle(
            style: pixelText(16, color: textColor, bold: true),
            textAlign: TextAlign.center,
            child: Opacity(opacity: enabled ? 1 : 0.7, child: widget.child),
          ),
        ),
      ),
    );
    button = Semantics(button: true, enabled: enabled, child: button);
    final tooltip = widget.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// A full-screen menu window with a title and a close button. Must be placed
/// directly in a [Stack].
class PixelWindow extends StatelessWidget {
  final String title;
  final String icon;
  final Widget child;
  final VoidCallback onClose;

  const PixelWindow({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: UiColors.dim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: PixelPanel(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      PixelIcon(icon, size: 26),
                      const SizedBox(width: 10),
                      Expanded(child: Text(title, style: pixelText(24, bold: true, color: UiColors.gold))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: child),
                  const SizedBox(height: 8),
                  PixelButton(onPressed: onClose, child: const Text('Close')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small centred panel over a dimmed screen.
class PixelModal extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDismiss;

  const PixelModal({super.key, required this.child, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: ColoredBox(
          color: UiColors.dim,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                // Taps on the panel itself don't dismiss it.
                child: GestureDetector(
                  onTap: () {},
                  child: PixelPanel(padding: const EdgeInsets.all(12), child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
