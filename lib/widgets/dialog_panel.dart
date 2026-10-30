import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/items.dart';
import '../models/npc.dart';
import '../models/quest.dart';
import '../graphics/textures.dart';

const _panelColor = Color(0xFF2B2118);
const _accent = Color(0xFFFFD54F);

/// Conversation with a villager. The elder's version also shows the current
/// quest and lets the player accept it or hand it in.
class DialogPanel extends StatelessWidget {
  final GameState gameState;

  const DialogPanel({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    final npc = gameState.world.npc(gameState.dialogNpcId!)!;
    final isElder = npc.id == Npc.elderId;
    final quest = gameState.currentQuest;
    final replying = gameState.dialogReply != null;

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
              child: const ColoredBox(color: Colors.black38),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Material(
                color: _panelColor,
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Portrait(look: npc.look),
                          const SizedBox(width: 12),
                          Text(
                            npc.name,
                            style: const TextStyle(color: _accent, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
                          child: Text(
                            gameState.dialogText,
                            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                          ),
                        ),
                      ),
                      if (isElder && quest != null) ...[
                        const SizedBox(height: 12),
                        _QuestBox(gameState: gameState, quest: quest, isNew: replying),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (final b in buttons) ...[const SizedBox(width: 8), b],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onPressed, {bool primary = false}) {
    return primary
        ? ElevatedButton(onPressed: onPressed, child: Text(label))
        : TextButton(onPressed: onPressed, child: Text(label, style: const TextStyle(color: Colors.white70)));
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isNew ? 'New task' : 'Task'}: ${quest.title}',
            style: const TextStyle(color: _accent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          for (final e in quest.requires.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Items.of(e.key).icon, color: Items.of(e.key).color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(Items.of(e.key).name, style: const TextStyle(color: Colors.white)),
                  ),
                  Text(
                    '${player.count(e.key).clamp(0, e.value)} / ${e.value}',
                    style: TextStyle(
                      color: player.count(e.key) >= e.value ? Colors.lightGreenAccent : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (player.count(e.key) >= e.value)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.check, color: Colors.lightGreenAccent, size: 16),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A villager's face for the dialog panel.
class Portrait extends StatelessWidget {
  final CharacterLook look;

  const Portrait({super.key, required this.look});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withValues(alpha: 0.5)),
      ),
      child: CustomPaint(painter: _PortraitPainter(look)),
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
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
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
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Material(
            color: _panelColor,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bedtime, color: _accent, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    night ? 'Sleep until morning?' : 'Take a nap?',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    night ? 'You will wake up at 06:00, fully rested.' : 'Three hours pass and your energy is restored.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: gameState.cancelSleep,
                        child: const Text('Not now', style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: gameState.sleep, child: const Text('Sleep')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChapterCompletePanel extends StatelessWidget {
  final GameState gameState;

  const ChapterCompletePanel({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.85),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.celebration, color: _accent, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'Chapter 1 complete!',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The Valley Awakens',
                    style: TextStyle(color: _accent, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'You rebuilt the bridge, lit the village fire, fed everyone and brought in the first harvest.\n\n'
                    'Thanks for playing the first version of Serene Valley. The story continues in the next update!',
                    style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Day ${gameState.world.day}  ·  Level ${gameState.player.level}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: gameState.closeChapterComplete,
                    child: const Text('Keep playing'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
