import 'package:flutter/material.dart';

/// Draws the player sprite. All coordinates are in tile units: the sprite
/// fills the 1x1 square whose top-left corner is [origin].
class PlayerSprite {
  static const Color _body = Color(0xFF4CAF50);
  static const Color _skin = Color(0xFFFFD700);
  static const Color _hat = Color(0xFF8B4513);
  static const Color _legs = Colors.blue;
  static const Color _eyes = Color(0xFF2D1B0E);

  static final Paint _paint = Paint();

  static void paint(Canvas canvas, Offset origin, String direction, double walkPhase) {
    final x = origin.dx;
    final y = origin.dy;

    // Shadow
    _paint.color = Colors.black.withValues(alpha: 0.25);
    canvas.drawOval(Rect.fromLTWH(x + 0.2, y + 0.85, 0.6, 0.15), _paint);

    // Legs alternate while walking.
    final stride = 0.06 * walkPhase;
    _paint.color = _legs;
    canvas.drawRect(Rect.fromLTWH(x + 0.3, y + 0.65 + stride, 0.15, 0.25 - stride), _paint);
    canvas.drawRect(Rect.fromLTWH(x + 0.55, y + 0.65 - stride, 0.15, 0.25 + stride), _paint);

    // Body
    _paint.color = _body;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 0.25, y + 0.38, 0.5, 0.35), const Radius.circular(0.08)),
      _paint,
    );

    // Head
    _paint.color = _skin;
    canvas.drawOval(Rect.fromLTWH(x + 0.3, y + 0.1, 0.4, 0.32), _paint);

    // Hat
    _paint.color = _hat;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 0.25, y + 0.05, 0.5, 0.13), const Radius.circular(0.06)),
      _paint,
    );

    // Eyes show which way the player is facing; none when facing away.
    _paint.color = _eyes;
    const e = 0.06;
    switch (direction) {
      case 'down':
        canvas.drawRect(Rect.fromLTWH(x + 0.38, y + 0.24, e, e), _paint);
        canvas.drawRect(Rect.fromLTWH(x + 0.56, y + 0.24, e, e), _paint);
        break;
      case 'left':
        canvas.drawRect(Rect.fromLTWH(x + 0.34, y + 0.24, e, e), _paint);
        break;
      case 'right':
        canvas.drawRect(Rect.fromLTWH(x + 0.60, y + 0.24, e, e), _paint);
        break;
    }
  }
}
