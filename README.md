# Serene Valley

A peaceful 2D pixel art open-world survival game built with Flutter.

## Chapter 1: The Valley Awakens

A great storm has swept through the valley. The bridge is gone, the village fire pit lies in ruins and the
stores are empty. Help Elder Rowan bring the village back to life:

1. **The Broken Bridge**: bring 10 wood to rebuild the bridge and open the road to the eastern hills.
2. **Warmth for the Village**: bring 8 stone from the hills and 5 wood to light the village fire.
3. **A Meal for Everyone**: catch fish, cook them on the fire and bring 5 cooked fish.
4. **The First Harvest**: plant the old farm field, tend it and bring 5 carrots.

## Chapter 2: The Old Mine

The best iron in the valley lies in the old mine under the eastern hills, boarded up since the storm. Old Bram,
the village miner, went down before the storm and never came back.

1. **A Light in the Dark**: chop pine trees for resin and show Elder Rowan 3 torches. You keep them, and he
   gives you the key to the mine.
2. **Into the Old Mine**: climb down into the dark and bring back 5 iron ore.
3. **The Village Forge**: bring 10 stone and 6 wood to rebuild the forge by the plaza. Smelt ore there and
   craft iron tools.
4. **The Lost Miner**: cut through the cobweb, break through the fallen rocks and find Bram in the deepest
   part of the mine. He makes his own way home to the village.

The quest tracker under the stats bar always shows what to do next. A yellow `!` above Elder Rowan means he
has a task for you, `?` means you have what he asked for, and an arrow at the edge of the screen points the
way back to him.

## Game Features

### Core Gameplay
- **Open World**: Explore a procedurally generated valley split by a river, with forests, lakes, rocky hills,
  caves and a village, and the old mine beneath it
- **Quests**: A story chain that changes the world as you go: the bridge, the fire and the farm appear when
  you complete them
- **Villagers**: Elder Rowan gives the quests; Mira, Old Tom and, once he is home, Bram have tips that change
  as the story moves on
- **Survival Elements**: Manage health, hunger and energy
- **Day/Night Cycle**: A day lasts ten minutes. Nights are dark and cold; fires, torches and lanterns light up
  the dark
- **Crafting System**: Create tools and items from gathered resources
- **Farming**: Plant seeds, water them and harvest carrots
- **Saving**: The game saves automatically and can be continued from the title screen
- **Music and Sound**: Gentle 8-bit tunes for day and night and an echoing one for the mine, birds and
  crickets, dripping tunnels, the river and crackling fires nearby, and sounds for everything you do. Music and sounds can be switched off from the title screen or the
  pause menu

### Peaceful Gameplay
- **Resource Gathering**: Chop trees, mine rocks, fish, pick berries and apples, search tall grass for seeds
- **Cooking**: Cook raw fish on any fire for a much more filling meal
- **Exploration**: Discover the village, the eastern hills, rivers, lakes, caves and the tunnels of the old mine
- **Wildlife**: Watch rabbits, deer and birds in their natural habitat

### Controls

#### Touch (Mobile)
- **Joystick** (bottom left): Move
- **Action button** (bottom right): Do what its label says: Talk, Chop, Mine, Fish, Cook, Plant, Water, Harvest,
  Enter, Climb, Cut, Break, Smelt... Tools are used automatically, the best one you have.
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
- **Wood**: From trees (three hits with the axe, two with the iron axe)
- **Pine resin**: From pine trees in the forest, along with their wood
- **Stone**: From rocks in the eastern hills and the mine (three hits with the pickaxe, two with the iron one)
- **Iron ore**: From the rusty-streaked rocks in the mine. Smelt it at the forge into iron ingots, one piece of
  wood for each
- **Crystals**: From the glowing clusters deep in the mine
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
- **Wooden Sword**: 2 Wood + 1 Stick (it cuts through cobwebs)
- **Torch** (makes 2): 1 Pine resin + 1 Stick
- **Iron Axe**: 2 Iron ingots + 2 Sticks
- **Iron Pickaxe**: 3 Iron ingots + 2 Sticks (it also breaks fallen rocks)
- **Lantern**: 1 Iron ingot + 2 Crystals

New recipes appear in the crafting menu as the story reveals them.

#### The Old Mine
The mine is a second map under the hills, in three parts, one below the other. A cobweb closes the shaft down
to the middle part and fallen rocks the one down to the deepest. Down there it is truly dark: only what you
bring lights the way.
- You need a torch to go down. One is lit as you climb down, and the next one when it burns out; each burns
  for two and a half minutes, dimming at the end. A torch can also be lit from the inventory at night.
- A lantern never goes out and lights more than a torch.
- Glowing mushrooms, crystals and the daylight down the ladder shaft give a little light of their own.
- Campfires work underground too, for cooking, warmth and sleep.
- The map shows the tunnels you have seen, and the arrow points back to the ladder when Elder Rowan is waiting.

### World Features
- **River**: Runs through the whole valley; the only crossing is the bridge east of the village
- **Village**: Your house with your bed, Mira's and Elder Rowan's houses, the plaza with the fire pit,
  the farm field and an apple orchard
- **Forests**: Dense with trees and berry bushes
- **Eastern Hills**: Rocky terrain with stone, beyond the river
- **Lakes**: Calm water bodies, good for fishing
- **Caves**: Entrances in the hills; the one with the timber frame leads into the old mine
- **Forge**: East of the plaza; in ruins until you rebuild it

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
│   ├── game_state.dart     # Game loop, interactions, quests, light, sleeping, saving
│   ├── level.dart          # What every map shares: tiles, walking, reachability, campfires
│   ├── world.dart          # The valley: generation, terrain, objects and time
│   ├── mine.dart           # The old mine: tunnels, obstacles, ore and what has been explored
│   ├── player.dart         # Player stats and inventory
│   ├── quest.dart          # The chapters and their quests
│   ├── npc.dart            # Villagers and what they say
│   ├── farm.dart           # Crop growth
│   └── items.dart          # Item names, icons and food values
├── services/
│   └── save_service.dart   # Saving and loading the game
├── audio/
│   └── sound.dart          # Music, ambience and sound effects
├── graphics/
│   ├── textures.dart       # Every texture, generated once at startup
│   ├── pixel_canvas.dart   # Small pixel buffer for drawing pixel art in code
│   ├── palette.dart        # Colour ramps shared by all the art
│   ├── terrain_art.dart    # Tiles and the overlays that blend them together
│   ├── object_art.dart     # Trees, rocks, plants, fires, houses and more
│   ├── character_art.dart  # Villagers, the player and animals
│   ├── ui_art.dart         # Icons, frames, buttons and the title scene
│   ├── icon_art.dart       # The app icon
│   └── ui_textures.dart    # Interface images, generated once at startup
├── screens/
│   ├── title_screen.dart   # Title screen with Continue / New game
│   └── game_screen.dart    # Game loop, input and touch controls
├── widgets/
│   ├── world_widget.dart   # World rendering (CustomPainter)
│   ├── tile_widget.dart    # Tile colours for the map
│   ├── hud_widget.dart     # HUD, inventory, crafting and pause menus
│   ├── dialog_panel.dart   # Conversations, sleep prompt, chapter end
│   ├── map_overlay.dart    # Maps of the valley and the mine
│   ├── pixel_ui.dart       # Pixel-art panels, buttons, icons and bars
│   └── sound_toggles.dart  # Music and sound on/off buttons
└── utils/
    └── helpers.dart        # Helper functions
```

### Tests
Run `flutter test`. The tests cover generating the valley and the mine, both chapters played through, torches
and darkness, survival mechanics, saving (including saves from before chapter 2) and the main screens on small
and large phones.

### Graphics
All the pixel art is drawn in code: no image files are needed. Textures are 16 pixels per tile and are drawn
scaled up without smoothing, at a whole number of screen pixels per texture pixel, so they stay crisp on any
phone. Colours come from the ramps in `palette.dart`; characters are drawn from small text templates in
`character_art.dart`, where each letter stands for a colour.

### Interface
The interface is pixel art too: wooden and parchment frames, buttons and icons are drawn in `ui_art.dart` and
sliced into nine so their borders stay sharp at any size. The reusable widgets (`PixelPanel`, `PixelButton`,
`PixelIcon`, `PixelBar`, `PixelWindow`) live in `widgets/pixel_ui.dart`. Text uses the Pixelify Sans font.

### Sound
All music and sound is synthesised by `tool/generate_audio.dart` from notes and recipes written in code, like
an 8-bit console would, and saved as WAV files in `assets/audio`. After changing it, regenerate with:

```
dart run tool/generate_audio.dart
```

The script also checks that every note of the melodies sounds at the right pitch.

### App Icon
The launcher icon is pixel art from `lib/graphics/icon_art.dart`. After changing it, regenerate the Android
icons with:

```
flutter test tool/generate_icons.dart
```

### Adding New Features
1. Add new tile types in `world.dart` or `mine.dart`, their texture in `terrain_art.dart` and their map colour
   in `tile_widget.dart`
2. Add new items in `items.dart` and recipes in `GameState.recipes`
3. Add new quests to `Quest.all` and their rewards in `GameState._applyQuestReward`
4. Bump `GameState.saveVersion` when the save format changes, and keep loading the older versions

## Customization

### World Generation
Modify parameters in `world.dart` (and `mine.dart` for the mine) to change:
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
