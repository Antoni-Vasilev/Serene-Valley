# Serene Valley

A peaceful 2D pixel art open-world survival game built with Flutter.

## Game Features

### Core Gameplay
- **Open World**: Explore a procedurally generated world with forests, rivers, mountains, and villages
- **Survival Elements**: Manage health, hunger, and energy levels
- **Day/Night Cycle**: Dynamic time system with beautiful sunrise and sunset transitions
- **Crafting System**: Create tools and items from gathered resources
- **Inventory Management**: Collect and manage various items

### Peaceful Gameplay
- **Resource Gathering**: Chop trees, mine rocks, fish, and pick berries
- **Crafting**: Create tools, weapons, and utility items
- **Exploration**: Discover villages, caves, rivers, and lakes
- **Wildlife**: Observe rabbits, deer, and birds in their natural habitat

### Controls

#### Keyboard
- **W/Arrow Up**: Move up
- **S/Arrow Down**: Move down
- **A/Arrow Left**: Move left
- **D/Arrow Right**: Move right
- **E**: Interact with objects
- **I**: Toggle inventory
- **C**: Toggle crafting menu
- **M**: Toggle map
- **ESC**: Pause game
- **SPACE**: Rest (restore energy)
- **1-5**: Quick select tools

#### Touch (Mobile)
- **Left side of screen**: Virtual joystick for movement
- **Right side of screen**: Interaction button
- **Tap**: Open menus

### Game Mechanics

#### Player Stats
- **Health**: Decreases when hungry or injured. Restore by eating food.
- **Hunger**: Decreases over time. Must be kept above 10 to avoid health loss.
- **Energy**: Decreases with movement. Affects movement speed when low.
- **Level**: Gain experience to level up, increasing max stats.

#### Resources
- **Wood**: From trees (using axe)
- **Stone**: From rocks (using pickaxe)
- **Berries**: From berry bushes
- **Fish**: From fishing in water
- **Apples**: Found in villages

#### Crafting Recipes
- **Stick**: 1 Wood
- **Fishing Rod**: 2 Sticks + 1 Wood
- **Wooden Sword**: 2 Wood + 1 Stick
- **Campfire**: 5 Wood + 3 Stone

### World Features
- **Forests**: Dense with trees and berry bushes
- **Rivers**: Flowing water with fish
- **Lakes**: Calm water bodies
- **Mountains**: Rocky terrain with stone
- **Villages**: Safe areas with wooden structures
- **Caves**: Mysterious entrances to explore

## Installation

1. Ensure you have Flutter installed on your system
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the game

## Platform Support
- Android
- iOS
- Web
- Windows
- macOS
- Linux

## Development

### Project Structure
```
lib/
├── main.dart           # App entry point
├── models/
│   ├── player.dart     # Player model
│   ├── world.dart      # World generation and management
│   └── game_state.dart # Game state management
├── widgets/
│   ├── player_widget.dart  # Player rendering
│   ├── world_widget.dart   # World rendering
│   ├── tile_widget.dart    # Tile rendering
│   └── hud_widget.dart     # HUD and UI elements
├── screens/
│   └── game_screen.dart    # Main game screen
└── utils/
    └── helpers.dart        # Helper functions
```

### Adding New Features
1. Add new tile types in `world.dart`
2. Create corresponding tile rendering in `tile_widget.dart`
3. Add new items to player inventory in `player.dart`
4. Update crafting recipes in `hud_widget.dart`

## Customization

### World Generation
Modify parameters in `world.dart` to change:
- World size
- Terrain distribution
- Resource density
- Village locations

### Game Balance
Adjust values in `player.dart` and `game_state.dart` to change:
- Player stats
- Resource gathering rates
- Experience gains
- Crafting recipes

## License
MIT License

## Credits
Created with Flutter and Dart.
