import 'package:flutter/material.dart';

enum ItemKind { material, food, tool, placeable }

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
      description: 'A toy-like sword. The valley is peaceful, for now.',
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
