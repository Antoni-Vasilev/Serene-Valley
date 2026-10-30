import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../services/save_service.dart';
import 'game_screen.dart';

class TitleScreen extends StatefulWidget {
  final SaveService saveService;

  const TitleScreen({super.key, required this.saveService});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  SaveSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final summary = await widget.saveService.summary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _continue() async {
    setState(() => _loading = true);
    final state = await widget.saveService.load();
    if (!mounted) return;
    if (state == null) {
      await _refresh();
      return;
    }
    await _play(state);
  }

  Future<void> _newGame() async {
    if (_summary != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new game?'),
          content: const Text('Your current progress will be lost.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('New game')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _loading = true);
    final state = GameState();
    // Save right away so "Continue" works even if the app is closed at once.
    await widget.saveService.save(state);
    if (!mounted) return;
    await _play(state);
  }

  Future<void> _play(GameState state) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(gameState: state, saveService: widget.saveService),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _ValleyPainter())),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Serene Valley',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chapter 1: The Valley Awakens',
                      style: TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(color: Colors.black54, blurRadius: 6)]),
                    ),
                    const SizedBox(height: 40),
                    if (_loading)
                      const CircularProgressIndicator(color: Colors.white)
                    else ...[
                      if (summary != null)
                        _MenuButton(
                          icon: Icons.play_arrow,
                          label: 'Continue',
                          detail: 'Day ${summary.day}  ·  Level ${summary.level}  ·  ${summary.progress}',
                          onPressed: _continue,
                        ),
                      const SizedBox(height: 12),
                      _MenuButton(
                        icon: Icons.add,
                        label: 'New game',
                        onPressed: _newGame,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onPressed;

  const _MenuButton({required this.icon, required this.label, this.detail, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: Colors.white.withValues(alpha: 0.92),
          foregroundColor: const Color(0xFF3E2723),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (detail != null)
                    Text(detail!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sunset over rolling hills.
class _ValleyPainter extends CustomPainter {
  const _ValleyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B3A67), Color(0xFF8E6C9E), Color(0xFFF4A261)],
          stops: [0, 0.45, 0.75],
        ).createShader(rect),
    );

    final sun = Offset(size.width * 0.78, size.height * 0.3);
    canvas.drawCircle(
      sun,
      size.width * 0.16,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFE08A).withValues(alpha: 0.5), Colors.transparent],
        ).createShader(Rect.fromCircle(center: sun, radius: size.width * 0.16)),
    );
    canvas.drawCircle(sun, size.width * 0.08, Paint()..color = const Color(0xFFFFE08A));

    void hill(double baseline, double amplitude, double phase, Color color) {
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        final y = size.height * baseline + sin(x / size.width * 2 * pi + phase) * size.height * amplitude;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    hill(0.66, 0.03, 0.5, const Color(0xFF5B7F4E));
    hill(0.74, 0.04, 2.2, const Color(0xFF3F6B3A));
    hill(0.84, 0.03, 4.0, const Color(0xFF2E5230));

    // A few trees on the nearest hill.
    final trunk = Paint()..color = const Color(0xFF4E342E);
    final leaves = Paint()..color = const Color(0xFF1E3D22);
    for (final fx in const [0.08, 0.16, 0.85, 0.92]) {
      final x = size.width * fx;
      final y = size.height * 0.84 + sin(fx * 2 * pi + 4.0) * size.height * 0.03;
      canvas.drawRect(Rect.fromLTWH(x - 3, y - 14, 6, 16), trunk);
      canvas.drawCircle(Offset(x, y - 22), 14, leaves);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
