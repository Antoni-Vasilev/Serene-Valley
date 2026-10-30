import 'package:flutter/material.dart';

enum ItemKind { material, food, tool, placeable, light }

class ItemInfo {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final ItemKind kind;
  final String description;
  // Food only: how much hunger and health eating one restores.
  final int hunger;
  final int health;

  const ItemInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.kind,
    required this.description,
    this.hunger = 0,
    this.health = 0,
  });

  bool get isFood => kind == ItemKind.food;
}

class Items {
  static const Map<String, ItemInfo> all = {
    'wood': ItemInfo(
      id: 'wood',
      name: 'Wood',
      icon: Icons.nature,
      color: Color(0xFFB07A45),
      kind: ItemKind.material,
      description: 'Chopped from trees. Used for building and crafting.',
    ),
    'stone': ItemInfo(
      id: 'stone',
      name: 'Stone',
      icon: Icons.landscape,
      color: Color(0xFFB0B0B0),
      kind: ItemKind.material,
      description: 'Mined from rocks in the eastern hills.',
    ),
    'stick': ItemInfo(
      id: 'stick',
      name: 'Sticks',
      icon: Icons.linear_scale,
      color: Color(0xFFC89B6D),
      kind: ItemKind.material,
      description: 'Crafted from wood.',
    ),
    'seeds': ItemInfo(
      id: 'seeds',
      name: 'Carrot seeds',
      icon: Icons.grass,
      color: Color(0xFF9CCC65),
      kind: ItemKind.material,
      description: 'Plant them on the farm field.',
    ),
    'berry': ItemInfo(
      id: 'berry',
      name: 'Berries',
      icon: Icons.local_florist,
      color: Color(0xFFE57373),
      kind: ItemKind.food,
      description: 'A small snack from berry bushes.',
      hunger: 10,
      health: 2,
    ),
    'apple': ItemInfo(
      id: 'apple',
      name: 'Apples',
      icon: Icons.apple,
      color: Color(0xFFEF5350),
      kind: ItemKind.food,
      description: 'Grows on the apple trees in the village.',
      hunger: 20,
      health: 5,
    ),
    'fish': ItemInfo(
      id: 'fish',
      name: 'Raw fish',
      icon: Icons.set_meal,
      color: Color(0xFF64B5F6),
      kind: ItemKind.food,
      description: 'Edible raw, but much better cooked on a fire.',
      hunger: 12,
    ),
    'cooked_fish': ItemInfo(
      id: 'cooked_fish',
      name: 'Cooked fish',
      icon: Icons.restaurant,
      color: Color(0xFFFFB74D),
      kind: ItemKind.food,
      description: 'A filling, warm meal.',
      hunger: 35,
      health: 10,
    ),
    'carrot': ItemInfo(
      id: 'carrot',
      name: 'Carrots',
      icon: Icons.eco,
      color: Color(0xFFFF9800),
      kind: ItemKind.food,
      description: 'Fresh from your own field.',
      hunger: 20,
      health: 5,
    ),
    'campfire': ItemInfo(
      id: 'campfire',
      name: 'Campfire',
      icon: Icons.fireplace,
      color: Color(0xFFFF7043),
      kind: ItemKind.placeable,
      description: 'Place it to cook, keep warm and sleep anywhere.',
    ),
    'axe': ItemInfo(
      id: 'axe',
      name: 'Axe',
      icon: Icons.carpenter,
      color: Color(0xFFE0E0E0),
      kind: ItemKind.tool,
      description: 'Used automatically to chop trees.',
    ),
    'pickaxe': ItemInfo(
      id: 'pickaxe',
      name: 'Pickaxe',
      icon: Icons.hardware,
      color: Color(0xFFE0E0E0),
      kind: ItemKind.tool,
      description: 'Used automatically to mine rocks.',
    ),
    'fishing_rod': ItemInfo(
      id: 'fishing_rod',
      name: 'Fishing rod',
      icon: Icons.phishing,
      color: Color(0xFFE0E0E0),
      kind: ItemKind.tool,
      description: 'Used automatically when you fish by the water.',
    ),
    'watering_can': ItemInfo(
      id: 'watering_can',
      name: 'Watering can',
      icon: Icons.water_drop,
      color: Color(0xFF4FC3F7),
      kind: ItemKind.tool,
      description: 'Used automatically to water your crops.',
    ),
    'wooden_sword': ItemInfo(
      id: 'wooden_sword',
      name: 'Wooden sword',
      icon: Icons.shield,
      color: Color(0xFFC89B6D),
      kind: ItemKind.tool,
      description: 'The valley is peaceful, but it cuts through cobwebs nicely.',
    ),
    'resin': ItemInfo(
      id: 'resin',
      name: 'Pine resin',
      icon: Icons.water_drop,
      color: Color(0xFFF2B33D),
      kind: ItemKind.material,
      description: 'Sticky resin from pine trees. It burns well.',
    ),
    'torch': ItemInfo(
      id: 'torch',
      name: 'Torch',
      icon: Icons.local_fire_department,
      color: Color(0xFFFF8A3D),
      kind: ItemKind.light,
      description: 'Lights up the dark for a few minutes. Lit by itself in the mine.',
    ),
    'iron_ore': ItemInfo(
      id: 'iron_ore',
      name: 'Iron ore',
      icon: Icons.terrain,
      color: Color(0xFFD07A44),
      kind: ItemKind.material,
      description: 'Rock with rusty streaks, from the old mine. Smelt it at the forge.',
    ),
    'iron_ingot': ItemInfo(
      id: 'iron_ingot',
      name: 'Iron ingot',
      icon: Icons.view_agenda,
      color: Color(0xFFB4C4D8),
      kind: ItemKind.material,
      description: 'Smelted iron, ready for crafting.',
    ),
    'crystal': ItemInfo(
      id: 'crystal',
      name: 'Crystal',
      icon: Icons.diamond,
      color: Color(0xFFB89CFF),
      kind: ItemKind.material,
      description: 'A softly glowing crystal from deep in the mine.',
    ),
    'iron_axe': ItemInfo(
      id: 'iron_axe',
      name: 'Iron axe',
      icon: Icons.carpenter,
      color: Color(0xFFB4C4D8),
      kind: ItemKind.tool,
      description: 'Fells a tree in two swings. Used automatically.',
    ),
    'iron_pickaxe': ItemInfo(
      id: 'iron_pickaxe',
      name: 'Iron pickaxe',
      icon: Icons.hardware,
      color: Color(0xFFB4C4D8),
      kind: ItemKind.tool,
      description: 'Breaks a rock in two hits, and even fallen rocks. Used automatically.',
    ),
    'lantern': ItemInfo(
      id: 'lantern',
      name: 'Lantern',
      icon: Icons.light,
      color: Color(0xFFD8C8FF),
      kind: ItemKind.tool,
      description: 'A crystal lantern that never goes out. Lights the dark wherever you go.',
    ),
  };

  static ItemInfo of(String id) =>
      all[id] ??
      ItemInfo(
        id: id,
        name: id.replaceAll('_', ' '),
        icon: Icons.inventory,
        color: Colors.white,
        kind: ItemKind.material,
        description: '',
      );
}
