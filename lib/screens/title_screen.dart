import 'package:flutter/material.dart';
import '../graphics/textures.dart';
import '../graphics/ui_textures.dart';
import '../models/game_state.dart';
import '../services/save_service.dart';
import '../widgets/pixel_ui.dart';
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
    // Draw the game's textures now, so starting to play doesn't stutter.
    WidgetsBinding.instance.addPostFrameCallback((_) => Textures.instance);
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
        barrierColor: UiColors.dim,
        builder: (context) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              type: MaterialType.transparency,
              child: PixelPanel(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Start a new game?',
                        style: pixelText(22, bold: true, color: UiColors.gold)),
                    const SizedBox(height: 8),
                    Text('Your current progress will be lost.',
                        style: pixelText(16), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        PixelButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        PixelButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: PixelButtonStyle.gold,
                          child: const Text('New game'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
        builder: (_) =>
            GameScreen(gameState: state, saveService: widget.saveService),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      backgroundColor: const Color(0xFF1F2547),
      body: Stack(
        children: [
          Positioned.fill(
            child: RawImage(
              image: UiTextures.instance.titleScene,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Serene\nValley',
                      textAlign: TextAlign.center,
                      style: pixelText(56,
                              bold: true, color: UiColors.cream, shadow: false)
                          .copyWith(
                        height: 1.0,
                        // A hard outline all round, like the art.
                        shadows: const [
                          Shadow(color: UiColors.shadow, offset: Offset(3, 0)),
                          Shadow(color: UiColors.shadow, offset: Offset(-3, 0)),
                          Shadow(color: UiColors.shadow, offset: Offset(0, 3)),
                          Shadow(color: UiColors.shadow, offset: Offset(0, -3)),
                          Shadow(color: UiColors.shadow, offset: Offset(3, 6)),
                          Shadow(
                              color: Color(0xFF8A3A2A), offset: Offset(0, 7)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    PixelPanel(
                      frame: PixelFrame.plate,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      child: Text('Chapter 1: The Valley Awakens',
                          style: pixelText(16, color: UiColors.gold)),
                    ),
                    const SizedBox(height: 36),
                    if (_loading)
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(color: UiColors.cream),
                      )
                    else ...[
                      if (summary != null)
                        _MenuButton(
                          icon: 'flag',
                          label: 'Continue',
                          detail:
                              'Day ${summary.day}  ·  Level ${summary.level}  ·  ${summary.progress}',
                          style: PixelButtonStyle.gold,
                          onPressed: _continue,
                        ),
                      const SizedBox(height: 12),
                      _MenuButton(
                        icon: 'star',
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
  final String icon;
  final String label;
  final String? detail;
  final PixelButtonStyle style;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.icon,
    required this.label,
    this.detail,
    this.style = PixelButtonStyle.wood,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        style == PixelButtonStyle.gold ? UiColors.ink : UiColors.cream;
    return SizedBox(
      width: 290,
      child: PixelButton(
        onPressed: onPressed,
        style: style,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            PixelIcon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: pixelText(22, bold: true, color: color)),
                  if (detail != null)
                    Text(detail!,
                        style: pixelText(13, color: color),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
