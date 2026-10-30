import 'package:flutter/material.dart';

/// How a character is drawn.
class CharacterLook {
  final Color body;
  final Color skin;
  final Color hat;
  final Color legs;
  final Color? beard;

  const CharacterLook({
    required this.body,
    this.skin = const Color(0xFFFFD7A8),
    required this.hat,
    this.legs = const Color(0xFF5D4037),
    this.beard,
  });

  /// The player: brown hair, green shirt and blue trousers.
  static const player = CharacterLook(
    body: Color(0xFF4CAF50),
    skin: Color(0xFFF2C29A),
    hat: Color(0xFF7A4A2A),
    legs: Color(0xFF3F6FB5),
  );
}

class Npc {
  final String id;
  final String name;
  // Tile the villager stands on.
  final Offset position;
  final CharacterLook look;

  const Npc({
    required this.id,
    required this.name,
    required this.position,
    required this.look,
  });

  static const elderId = 'elder';
  static const miraId = 'mira';
  static const tomId = 'tom';
  static const bramId = 'bram';

  static Npc create(String id, Offset position) {
    switch (id) {
      case elderId:
        return Npc(
          id: id,
          name: 'Elder Rowan',
          position: position,
          look: const CharacterLook(
            body: Color(0xFF6A4C93),
            hat: Color(0xFFE0E0E0),
            beard: Color(0xFFF5F5F5),
          ),
        );
      case miraId:
        return Npc(
          id: id,
          name: 'Mira',
          position: position,
          look: const CharacterLook(
            body: Color(0xFFD45A5A),
            hat: Color(0xFF6D4C41),
            legs: Color(0xFF455A64),
          ),
        );
      case bramId:
        // An iron helmet, a leather work coat and a big copper beard.
        return Npc(
          id: id,
          name: 'Bram',
          position: position,
          look: const CharacterLook(
            body: Color(0xFF7E5A36),
            hat: Color(0xFF5E6670),
            legs: Color(0xFF3B4650),
            beard: Color(0xFFC0662C),
          ),
        );
      default:
        return Npc(
          id: id,
          name: 'Old Tom',
          position: position,
          look: const CharacterLook(
            body: Color(0xFF3F72AF),
            hat: Color(0xFFF2C14E),
            beard: Color(0xFF9E9E9E),
          ),
        );
    }
  }

  /// What a villager says, given how far the story has progressed (the index
  /// of the current quest, or the number of quests once all are done).
  static String line(String id, int stage) {
    final lines = _lines[id];
    if (lines == null) return '...';
    // The latest line the story has reached.
    return lines.lastWhere((l) => l.$1 <= stage, orElse: () => lines.first).$2;
  }

  /// What Bram says when he is found in the mine.
  static const bramFound = "A light! Oh, thank goodness. The storm brought the tunnel down behind me, and I've "
      'lived on mushrooms and dripping water ever since. Rowan sent you? Then lead on, friend. I\'m going home!';

  /// Lines by the stage of the story from which they are said.
  static const Map<String, List<(int, String)>> _lines = {
    miraId: [
      (0, "Since the storm we can't reach the stone hills across the river. Talk to Elder Rowan, he has a plan."),
      (1, 'You fixed the bridge! The hills to the east are full of rocks. Bring your pickaxe.'),
      (2, "The fire is so warm. If you're tired, rest beside it. You can sleep there through the night."),
      (3, 'Plant, water, wait. Crops grow while you sleep, so water them before bed!'),
      (4, 'Fresh carrots, just like the old days! Now Rowan wants the old mine opened. You will need torches.'),
      (5, "The old mine gives me the shivers. Take spare torches, it's darker down there than any night."),
      (6, 'The forge used to ring all day when I was little. It would be lovely to hear it again.'),
      (7, 'Poor Bram... If fallen rocks are in your way down there, only an iron pickaxe will get you through.'),
      (8, "Bram is home! He's been telling stories all evening. You're the talk of the village."),
    ],
    tomId: [
      (0, 'The bridge used to stand right here. Without it, I can only fish from this bank.'),
      (1, "Ha, I can cross again! Stand at the water's edge with your rod and be patient."),
      (2, 'Not every cast catches something. Cooked fish fills you up much more than raw.'),
      (3, 'Run out of seeds? Search the tall grass, they hide in there.'),
      (4, "Pine trees in the forest are full of resin. Mind your fingers, it's sticky!"),
      (5, 'Iron ore has rusty red streaks in it. Bram taught me that, back in the day.'),
      (6, 'With an iron axe you could fell a tree in two swings. Imagine that!'),
      (7, "If anyone could last down there, it's Bram. Cobwebs in the way? A wooden sword cuts right through."),
      (8, 'Bram owes me a fishing trip. Twenty years he has been promising!'),
    ],
    bramId: [
      (0, "Go on, tell Rowan I'm back! Then let's get this forge roaring like the old days."),
      (8, "Two crystals and an iron ingot make a lantern that never goes out. An old miner's trick."),
    ],
    // While the story goes on, the elder talks about the current quest.
    elderId: [
      (0, 'The valley is alive again and the mine rings with work. Rest, explore and enjoy it. New adventures are coming.'),
    ],
  };
}
