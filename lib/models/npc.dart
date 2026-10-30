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

  /// What a villager says, given how far the chapter has progressed
  /// (the index of the current quest, or the quest count when it's done).
  static String line(String id, int stage) {
    final lines = _lines[id] ?? const ['...'];
    return lines[stage.clamp(0, lines.length - 1)];
  }

  static const Map<String, List<String>> _lines = {
    miraId: [
      "Since the storm we can't reach the stone hills across the river. Talk to Elder Rowan, he has a plan.",
      'You fixed the bridge! The hills to the east are full of rocks. Bring your pickaxe.',
      "The fire is so warm. If you're tired, rest beside it. You can sleep there through the night.",
      'Plant, water, wait. Crops grow while you sleep, so water them before bed!',
      'Fresh carrots! It feels like the old days again.',
    ],
    tomId: [
      'The bridge used to stand right here. Without it, I can only fish from this bank.',
      "Ha, I can cross again! Stand at the water's edge with your rod and be patient.",
      'Not every cast catches something. Cooked fish fills you up much more than raw.',
      'Run out of seeds? Search the tall grass, they hide in there.',
      'Come fish with me anytime, friend.',
    ],
    // While the chapter is in progress the elder talks about the current quest.
    elderId: [
      'The valley is alive again. Rest, explore and enjoy it. New adventures are coming.',
    ],
  };
}
