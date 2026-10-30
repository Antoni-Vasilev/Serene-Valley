import 'package:flutter/material.dart';
import '../graphics/textures.dart';
import '../graphics/ui_textures.dart';
import '../models/game_state.dart';
import '../models/items.dart';
import '../models/npc.dart';
import '../models/quest.dart';
import 'pixel_ui.dart';

/// Conversation with a villager. The elder's version also shows the current
/// quest and lets the player accept it or hand it in.
class DialogPanel extends StatefulWidget {
  final GameState gameState;

  const DialogPanel({super.key, required this.gameState});

  @override
  State<DialogPanel> createState() => _DialogPanelState();
}

class _DialogPanelState extends State<DialogPanel> {
  // The text the player tapped to see in full.
  String? _skipped;

  GameState get gameState => widget.gameState;

  @override
  Widget build(BuildContext context) {
    final npc = gameState.world.npc(gameState.dialogNpcId!)!;
    final isElder = npc.id == Npc.elderId;
    final quest = gameState.currentQuest;
    final replying = gameState.dialogReply != null;
    final text = gameState.dialogText;

    final List<Widget> buttons;
    if (replying) {
      buttons = [_button('OK', gameState.closeDialog, primary: true)];
    } else if (isElder && quest != null && !gameState.questAccepted) {
      buttons = [
        _button('Not now', gameState.closeDialog),
        _button('Accept', gameState.acceptQuest, primary: true),
      ];
    } else if (isElder && gameState.questReady) {
      buttons = [
        _button('Later', gameState.closeDialog),
        _button('Give', gameState.handInQuest, primary: true),
      ];
    } else {
      buttons = [_button('Close', gameState.closeDialog, primary: true)];
    }

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: replying ? null : gameState.closeDialog,
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: PixelPanel(
                frame: PixelFrame.parchment,
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Portrait(look: npc.look),
                        const SizedBox(width: 10),
                        Flexible(
                          child: PixelPanel(
                            frame: PixelFrame.plate,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            child: Text(
                              npc.name,
                              style: pixelText(18, bold: true, color: UiColors.gold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => setState(() => _skipped = text),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 210),
                        child: SingleChildScrollView(child: _TypedText(text, instant: _skipped == text)),
                      ),
                    ),
                    if (isElder && quest != null) ...[
                      const SizedBox(height: 10),
                      _QuestBox(gameState: gameState, quest: quest, isNew: replying),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: buttons,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onPressed, {bool primary = false}) {
    return PixelButton(
      onPressed: onPressed,
      style: primary ? PixelButtonStyle.gold : PixelButtonStyle.wood,
      child: Text(label),
    );
  }
}

/// Text that writes itself out letter by letter, like a story being told.
/// The full text is laid out from the start so the box doesn't grow.
class _TypedText extends StatelessWidget {
  final String text;
  final bool instant;

  const _TypedText(this.text, {required this.instant});

  @override
  Widget build(BuildContext context) {
    final style = pixelText(16, color: UiColors.ink);
    if (instant) return Text(text, style: style);
    return TweenAnimationBuilder<int>(
      key: ValueKey(text),
      tween: IntTween(begin: 0, end: text.length),
      duration: Duration(milliseconds: 18 * text.length),
      builder: (context, shown, _) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: text.substring(0, shown)),
            TextSpan(text: text.substring(shown), style: const TextStyle(color: Colors.transparent)),
          ],
        ),
        style: style,
      ),
    );
  }
}

class _QuestBox extends StatelessWidget {
  final GameState gameState;
  final Quest quest;
  final bool isNew;

  const _QuestBox({required this.gameState, required this.quest, required this.isNew});

  @override
  Widget build(BuildContext context) {
    final player = gameState.player;
    return PixelPanel(
      frame: PixelFrame.note,
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PixelIcon('flag', size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${isNew ? 'New task' : 'Task'}: ${quest.title}',
                  style: pixelText(15, bold: true, color: const Color(0xFFB0401C)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final e in quest.requires.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  PixelIcon(UiTextures.itemIcon(e.key), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(Items.of(e.key).name, style: pixelText(15, color: UiColors.ink))),
                  Text(
                    '${player.count(e.key).clamp(0, e.value)} / ${e.value}',
                    style: pixelText(
                      15,
                      bold: true,
                      color: player.count(e.key) >= e.value ? const Color(0xFF3E8A2E) : UiColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A villager's face in a little frame.
class Portrait extends StatelessWidget {
  final CharacterLook look;

  const Portrait({super.key, required this.look});

  @override
  Widget build(BuildContext context) {
    final px = uiPixel(context);
    return PixelPanel(
      frame: PixelFrame.slot,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 12 * px * 1.5,
        height: 12 * px * 1.5,
        child: CustomPaint(painter: _PortraitPainter(look)),
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  final CharacterLook look;

  _PortraitPainter(this.look);

  @override
  void paint(Canvas canvas, Size size) {
    // Zoom in on the head and shoulders.
    final image = Textures.instance.character(look)['down']!.first;
    canvas.drawImageRect(
      image,
      const Rect.fromLTWH(2, 0, 12, 12),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter oldDelegate) => oldDelegate.look != look;
}

class SleepPrompt extends StatelessWidget {
  final GameState gameState;

  const SleepPrompt({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    final night = !gameState.world.isDay;
    return PixelModal(
      onDismiss: gameState.cancelSleep,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PixelIcon('moon', size: 40),
          const SizedBox(height: 10),
          Text(
            night ? 'Sleep until morning?' : 'Take a nap?',
            style: pixelText(22, bold: true, color: UiColors.gold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            night ? 'You will wake up at 06:00, fully rested.' : 'Three hours pass and your energy is restored.',
            style: pixelText(15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              PixelButton(onPressed: gameState.cancelSleep, child: const Text('Not now')),
              PixelButton(onPressed: gameState.sleep, style: PixelButtonStyle.gold, child: const Text('Sleep')),
            ],
          ),
        ],
      ),
    );
  }
}

class ChapterCompletePanel extends StatelessWidget {
  final GameState gameState;

  const ChapterCompletePanel({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return PixelModal(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PixelIcon('star', size: 30),
              SizedBox(width: 8),
              PixelIcon('star', size: 44),
              SizedBox(width: 8),
              PixelIcon('star', size: 30),
            ],
          ),
          const SizedBox(height: 12),
          Text('Chapter 1 complete!', style: pixelText(28, bold: true, color: UiColors.gold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('The Valley Awakens', style: pixelText(17, color: UiColors.faded)),
          const SizedBox(height: 16),
          Text(
            'You rebuilt the bridge, lit the village fire, fed everyone and brought in the first harvest.\n\n'
            'Thanks for playing the first version of Serene Valley. The story continues in the next update!',
            style: pixelText(16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            'Day ${gameState.world.day}  ·  Level ${gameState.player.level}',
            style: pixelText(15, bold: true),
          ),
          const SizedBox(height: 18),
          PixelButton(
            onPressed: gameState.closeChapterComplete,
            style: PixelButtonStyle.gold,
            child: const Text('Keep playing'),
          ),
        ],
      ),
    );
  }
}
