# Serene Valley

A peaceful 2D pixel art open-world survival game built with Flutter.

## Chapter 1: The Valley Awakens

A great storm has swept through the valley. The bridge is gone, the village fire pit lies in ruins and the
stores are empty. Help Elder Rowan bring the village back to life:

1. **The Broken Bridge**: bring 10 wood to rebuild the bridge and open the road to the eastern hills.
2. **Warmth for the Village**: bring 8 stone from the hills and 5 wood to light the village fire.
3. **A Meal for Everyone**: catch fish, cook them on the fire and bring 5 cooked fish.
4. **The First Harvest**: plant the old farm field, tend it and bring 5 carrots.

The quest tracker under the stats bar always shows what to do next. A yellow `!` above Elder Rowan means he
has a task for you, `?` means you have what he asked for, and an arrow at the edge of the screen points the
way back to him.

## Game Features

### Core Gameplay
- **Open World**: Explore a procedurally generated valley split by a river, with forests, lakes, rocky hills,
  caves and a village
- **Quests**: A story chain that changes the world as you go: the bridge, the fire and the farm appear when
  you complete them
- **Villagers**: Elder Rowan gives the quests; Mira and Old Tom have tips that change as the story moves on
- **Survival Elements**: Manage health, hunger and energy
- **Day/Night Cycle**: A day lasts ten minutes. Nights are dark and cold, and fires light up the dark
- **Crafting System**: Create tools and items from gathered resources
- **Farming**: Plant seeds, water them and harvest carrots
- **Saving**: The game saves automatically and can be continued from the title screen

### Peaceful Gameplay
- **Resource Gathering**: Chop trees, mine rocks, fish, pick berries and apples, search tall grass for seeds
- **Cooking**: Cook raw fish on any fire for a much more filling meal
- **Exploration**: Discover the village, the eastern hills, rivers, lakes and caves
- **Wildlife**: Watch rabbits, deer and birds in their natural habitat

### Controls

#### Touch (Mobile)
- **Joystick** (bottom left): Move
- **Action button** (bottom right): Do what its label says: Talk, Chop, Mine, Fish, Cook, Plant, Water, Harvest...
  Tools are used automatically.
- **Bottom bar**: Items, Craft, Map, Sleep, Pause
- **Back button**: Close the open menu, or pause

#### Keyboard
- **W/A/S/D or arrow keys**: Move
- **E**: Interact
- **I**: Toggle inventory
- **C**: Toggle crafting menu
- **M**: Toggle map
- **SPACE**: Sleep (in bed or by a fire)
- **ESC**: Close the open menu, or pause

### Game Mechanics

#### Player Stats
- **Health**: Slowly recovers while you are well fed. Lost when starving.
- **Hunger**: Decreases over time. Keep it above 10 to avoid losing health.
- **Energy**: Decreases as you walk and work, and twice as fast in the cold at night. Below 20 you move
  slower, and below 5 you are too tired to work. Rest by a fire or sleep to recover.
- **Level**: Gain experience to level up, increasing max stats.

If your health runs out, you faint and wake up in the village.

#### Sleeping
Sleep in your bed (in your house in the village) or next to a fire. At night you sleep until 06:00; during
the day you take a three-hour nap. Either way your energy is fully restored.

#### Resources
- **Wood**: From trees (three hits with the axe)
- **Stone**: From rocks in the eastern hills (three hits with the pickaxe)
- **Berries**: From berry bushes; they grow back after a day
- **Apples**: From the apple trees in the village orchard; they grow back after a day
- **Fish**: From fishing by any water. Cook it on a fire.
- **Carrot seeds**: From Elder Rowan, from tall grass and from every harvest

#### Food
| Food        | Hunger | Health |
|-------------|--------|--------|
| Berries     | +10    | +2     |
| Raw fish    | +12    |        |
| Apples      | +20    | +5     |
| Carrots     | +20    | +5     |
| Cooked fish | +35    | +10    |

#### Farming
Plant carrot seeds on the farm field, then water them. A watered crop grows to its next stage after three
in-game hours and needs water again. After three stages the carrots are ripe; harvesting gives 2 carrots and
1-2 seeds. Crops keep growing while you sleep, so water them before bed.

#### Crafting Recipes
- **Stick**: 1 Wood
- **Fishing Rod**: 2 Sticks + 1 Wood
- **Campfire**: 5 Wood + 3 Stone (place it from the inventory to cook, keep warm and sleep anywhere)
- **Wooden Sword**: 2 Wood + 1 Stick

### World Features
- **River**: Runs through the whole valley; the only crossing is the bridge east of the village
- **Village**: Your house with your bed, Mira's and Elder Rowan's houses, the plaza with the fire pit,
  the farm field and an apple orchard
- **Forests**: Dense with trees and berry bushes
- **Eastern Hills**: Rocky terrain with stone, beyond the river
- **Lakes**: Calm water bodies, good for fishing
- **Caves**: Mysterious entrances in the hills

## Installation

1. Ensure you have Flutter installed on your system
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the game

To build an Android APK, run `flutter build apk --release`. The release build is signed with the debug key so
it can be installed directly; set up a real signing config before publishing to Google Play.

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
├── main.dart               # App entry point
├── models/
│   ├── game_state.dart     # Game loop, interactions, quests, sleeping, saving
│   ├── world.dart          # World generation, terrain, objects and time
│   ├── player.dart         # Player stats and inventory
│   ├── quest.dart          # The chapter's quest chain
│   ├── npc.dart            # Villagers and what they say
│   ├── farm.dart           # Crop growth
│   └── items.dart          # Item names, icons and food values
├── services/
│   └── save_service.dart   # Saving and loading the game
├── graphics/
│   ├── textures.dart       # Every texture, generated once at startup
│   ├── pixel_canvas.dart   # Small pixel buffer for drawing pixel art in code
│   ├── palette.dart        # Colour ramps shared by all the art
│   ├── terrain_art.dart    # Tiles and the overlays that blend them together
│   ├── object_art.dart     # Trees, rocks, plants, fires, houses and more
│   ├── character_art.dart  # Villagers, the player and animals
│   ├── ui_art.dart         # Icons, frames, buttons and the title scene
│   └── ui_textures.dart    # Interface images, generated once at startup
├── screens/
│   ├── title_screen.dart   # Title screen with Continue / New game
│   └── game_screen.dart    # Game loop, input and touch controls
├── widgets/
│   ├── world_widget.dart   # World rendering (CustomPainter)
│   ├── tile_widget.dart    # Tile colours for the map
│   ├── hud_widget.dart     # HUD, inventory, crafting and pause menus
│   ├── dialog_panel.dart   # Conversations, sleep prompt, chapter end
│   ├── map_overlay.dart    # World map
│   └── pixel_ui.dart       # Pixel-art panels, buttons, icons and bars
└── utils/
    └── helpers.dart        # Helper functions
```

### Tests
Run `flutter test`. The tests cover world generation, the whole quest chain, survival mechanics, saving and
the main screens on small and large phones.

### Graphics
All the pixel art is drawn in code: no image files are needed. Textures are 16 pixels per tile and are drawn
scaled up without smoothing, at a whole number of screen pixels per texture pixel, so they stay crisp on any
phone. Colours come from the ramps in `palette.dart`; characters are drawn from small text templates in
`character_art.dart`, where each letter stands for a colour.

### Interface
The interface is pixel art too: wooden and parchment frames, buttons and icons are drawn in `ui_art.dart` and
sliced into nine so their borders stay sharp at any size. The reusable widgets (`PixelPanel`, `PixelButton`,
`PixelIcon`, `PixelBar`, `PixelWindow`) live in `widgets/pixel_ui.dart`. Text uses the Pixelify Sans font.

### Adding New Features
1. Add new tile types in `world.dart`, their texture in `terrain_art.dart` and their map colour in `tile_widget.dart`
2. Add new items in `items.dart` and recipes in `GameState.recipes`
3. Add new quests to `Quest.chapter` and their rewards in `GameState._applyQuestReward`

## Customization

### World Generation
Modify parameters in `world.dart` to change:
- World size
- Terrain distribution
- Resource density
- Village layout

### Game Balance
Adjust values in `player.dart`, `items.dart`, `quest.dart` and `game_state.dart` to change:
- Player stats and how fast they drain
- Food values
- Quest requirements and rewards
- Crafting recipes

## License
MIT License

## Credits
Created with Flutter and Dart.

Interface font: [Pixelify Sans](https://github.com/eifetx/Pixelify-Sans), © 2021 The Pixelify Sans Project Authors, licensed under the
SIL Open Font License 1.1 (see `assets/fonts/OFL.txt`).
