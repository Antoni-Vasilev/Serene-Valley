import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:serene_valley/models/farm.dart';
import 'package:serene_valley/models/game_state.dart';
import 'package:serene_valley/models/level.dart';
import 'package:serene_valley/models/mine.dart';
import 'package:serene_valley/models/npc.dart';
import 'package:serene_valley/models/quest.dart';
import 'package:serene_valley/models/world.dart';
import 'package:serene_valley/services/save_service.dart';

/// Puts the player on a free tile next to [tile] and updates their target.
void standNextTo(GameState state, Offset tile) {
  final x = tile.dx.toInt();
  final y = tile.dy.toInt();
  for (final d in const [Point(0, 1), Point(-1, 0), Point(1, 0), Point(0, -1)]) {
    if (state.level.isWalkable(x + d.x, y + d.y)) {
      state.player.position = Offset(x + d.x + 0.5, y + d.y + 0.5);
      state.update(0);
      return;
    }
  }
  fail('Nothing walkable next to $tile');
}

/// Puts the player in the middle of [tile] and updates their target.
void standOn(GameState state, Point<int> tile) {
  state.player.position = Offset(tile.x + 0.5, tile.y + 0.5);
  state.update(0);
}

void talkToElder(GameState state) {
  standNextTo(state, state.world.npc(Npc.elderId)!.position);
  expect(state.target?.type, 'talk');
  state.interact();
  expect(state.dialogNpcId, Npc.elderId);
}

Point<int> tileOf(Offset o) => Point(o.dx.toInt(), o.dy.toInt());

/// Steps up to the thing [key] at [position], from above if possible, and
/// uses it [times] times.
void hit(GameState state, String key, Offset position, {int times = 1}) {
  final x = position.dx.toInt();
  final y = position.dy.toInt();
  for (final d in const [Point(0, -1), Point(0, 1), Point(-1, 0), Point(1, 0)]) {
    if (!state.level.isWalkable(x + d.x, y + d.y)) continue;
    standOn(state, Point(x + d.x, y + d.y));
    if (state.target?.key != key) continue;
    for (var i = 0; i < times; i++) {
      state.player.energy = state.player.maxEnergy.toDouble();
      state.interact();
    }
    return;
  }
  fail('Could not get to $key');
}

/// Lets the fade of climbing in or out of the mine play out.
void travel(GameState state) {
  for (var i = 0; i < 60 && state.isTravelling; i++) {
    state.update(1 / 30);
  }
}

void enterMine(GameState state) {
  final entrance = state.world.mineEntrance!;
  standOn(state, Point(entrance.dx.toInt(), entrance.dy.toInt() + 1));
  expect(state.target?.type, 'enter');
  state.interact();
  travel(state);
  expect(state.underground, isTrue);
}

void leaveMine(GameState state) {
  standOn(state, state.mine!.arrival);
  expect(state.target?.type, 'climb');
  state.interact();
  travel(state);
  expect(state.underground, isFalse);
}

void main() {
  _chapterTwo();

  group('World generation', () {
    test('the river cuts off the east bank until the bridge is rebuilt', () {
      for (var seed = 0; seed < 10; seed++) {
        final world = World(seed: seed)..generate();
        final spawn = tileOf(world.playerSpawn);
        final westBank = world.reachableTiles(spawn);
        final withBridge = world.reachableTiles(spawn, cleared: true);

        expect(world.isWalkable(spawn.x, spawn.y), isTrue, reason: 'seed $seed');
        expect(world.rocks.values.where((r) => westBank.contains(tileOf(r))), isEmpty, reason: 'seed $seed');
        expect(world.rocks.values.where((r) => withBridge.contains(tileOf(r))).length, greaterThanOrEqualTo(12),
            reason: 'seed $seed');
        expect(world.trees.values.where((t) => westBank.contains(tileOf(t))).length, greaterThanOrEqualTo(15),
            reason: 'seed $seed');
        for (final p in world.bridgeTiles) {
          expect(world.getTileAt(p.x, p.y), 'water', reason: 'seed $seed');
        }
      }
    });

    test('no stray stone tiles block walking around the village side', () {
      for (var seed = 0; seed < 10; seed++) {
        final world = World(seed: seed)..generate();
        final westBank = world.reachableTiles(tileOf(world.playerSpawn));
        for (final p in westBank) {
          for (final n in [Point(p.x + 1, p.y), Point(p.x - 1, p.y), Point(p.x, p.y + 1), Point(p.x, p.y - 1)]) {
            expect(world.getTileAt(n.x, n.y), isNot('stone'), reason: 'seed $seed at $n');
          }
        }
      }
    });

    test('the village has its villagers, bed, fire pit and farm', () {
      final world = World(seed: 42)..generate();
      final spawn = tileOf(world.playerSpawn);
      final reachable = world.reachableTiles(spawn);

      for (final id in [Npc.elderId, Npc.miraId, Npc.tomId]) {
        expect(world.npc(id), isNotNull);
      }
      expect(world.farmArea.width * world.farmArea.height, 24);
      // The farm field can be entered through the gate.
      expect(reachable.contains(Point(world.farmArea.left.toInt(), world.farmArea.top.toInt())), isTrue);
      // The bed is inside the player's house, reachable through the door.
      final bed = tileOf(world.bed);
      expect(reachable.contains(Point(bed.x + 1, bed.y)), isTrue);
    });

    test('the same seed always makes the same world', () {
      final a = World(seed: 123)..generate();
      final b = World(seed: 123)..generate();
      expect(a.tiles, b.tiles);
      expect(a.trees.keys, b.trees.keys);
    });
  });

  group('Quests', () {
    test('the player starts next to Elder Rowan, who has a task', () {
      final state = GameState(worldSeed: 1);
      expect(state.target?.type, 'talk');
      expect(state.questTargetPosition, state.world.npc(Npc.elderId)!.position);

      state.interact();
      expect(state.dialogText, Quest.all.first.intro);
      state.acceptQuest();
      state.closeDialog();
      expect(state.questAccepted, isTrue);
      // Nothing to report until the wood is collected.
      expect(state.questTargetPosition, isNull);
    });

    test('the whole chapter can be played through', () {
      final state = GameState(worldSeed: 7);
      final world = state.world;
      final player = state.player;

      // The Broken Bridge
      talkToElder(state);
      state.acceptQuest();
      state.closeDialog();
      player.addItem('wood', 10);
      expect(state.questReady, isTrue);
      talkToElder(state);
      state.handInQuest();
      expect(world.bridgeBuilt, isTrue);
      for (final p in world.bridgeTiles) {
        expect(world.isWalkable(p.x, p.y), isTrue);
      }
      expect(state.dialogReply, contains(Quest.all[1].intro));
      state.closeDialog();

      // Warmth for the Village
      player.addItem('stone', 8);
      player.addItem('wood', 5);
      talkToElder(state);
      state.handInQuest();
      state.closeDialog();
      expect(world.fires, contains(world.firePit));

      // A Meal for Everyone: cook fish on the new fire.
      player.addItem('fish', 5);
      standNextTo(state, world.firePit);
      for (var i = 0; i < 5; i++) {
        expect(state.target?.type, 'cook');
        state.interact();
      }
      expect(player.count('cooked_fish'), 5);
      expect(player.count('fish'), 0);
      talkToElder(state);
      state.handInQuest();
      state.closeDialog();
      expect(world.farmUnlocked, isTrue);
      expect(player.count('watering_can'), 1);
      expect(player.count('seeds'), 5);

      // The First Harvest: plant five carrots and tend them until ripe.
      final field = [
        for (int y = world.farmArea.top.toInt(); y < world.farmArea.bottom; y++)
          for (int x = world.farmArea.left.toInt(); x < world.farmArea.right; x++) Point(x, y),
      ].take(5).toList();
      for (final tile in field) {
        standOn(state, tile);
        expect(state.target?.type, 'plant');
        state.interact();
      }
      expect(player.count('seeds'), 0);
      for (var stage = 0; stage < Crop.ripeStage; stage++) {
        for (final tile in field) {
          standOn(state, tile);
          expect(state.target?.type, 'water');
          state.interact();
        }
        world.advanceHours(Crop.hoursPerStage);
      }
      for (final tile in field) {
        standOn(state, tile);
        expect(state.target?.type, 'harvest');
        state.interact();
      }
      expect(player.count('carrot'), 10);
      expect(player.count('seeds'), greaterThanOrEqualTo(5));

      talkToElder(state);
      state.handInQuest();
      expect(state.chaptersDone, 1);
      state.closeDialog();
      expect(state.showChapterComplete, isTrue);
      expect(state.celebratingChapter, 1);
      state.closeChapterComplete();

      // Chapter 2 begins with a new task from the elder.
      expect(state.currentQuest!.id, Quest.light);
      expect(state.questAccepted, isFalse);
      expect(state.questTargetPosition, world.npc(Npc.elderId)!.position);
    });
  });

  group('Survival', () {
    test('stats drain slowly instead of once per frame', () {
      final state = GameState(worldSeed: 4);
      for (var i = 0; i < 60; i++) {
        state.update(1 / 60);
      }
      expect(state.player.hunger, greaterThan(99));
      expect(state.player.energy, greaterThan(99));
      expect(state.player.health, state.player.maxHealth);
    });

    test('movement is scaled by elapsed time', () {
      final state = GameState(worldSeed: 3);
      final start = state.player.position;
      state.moveInput = const Offset(0, 1);
      state.update(0.1);
      // 4 tiles/second for 0.1s, or less if something is in the way.
      expect((state.player.position - start).distance, lessThanOrEqualTo(0.41));
    });

    test('doorways can be walked through without lining up exactly', () {
      final state = GameState(worldSeed: 5);
      final village = state.world.villageCenter;
      // The player's front door is one tile above the spawn point.
      final doorY = village.dy - 3;
      state.player.position += const Offset(-0.25, 0);
      state.moveInput = const Offset(0, -1);
      for (var i = 0; i < 60; i++) {
        state.update(1 / 60);
      }
      expect(state.player.position.dy, lessThan(doorY));
    });

    test('sleeping by the fire skips to the morning', () {
      final state = GameState(worldSeed: 3);
      state.world.buildFirePit();
      standNextTo(state, state.world.firePit);
      state.world.advanceHours(16); // 22:00
      state.player.energy = 10;

      state.requestSleep();
      expect(state.confirmSleep, isTrue);
      state.sleep();
      for (var i = 0; i < 150; i++) {
        state.update(1 / 60);
      }
      expect(state.isSleeping, isFalse);
      expect(state.world.day, 2);
      expect(state.world.timeOfDay, closeTo(6, 0.05));
      expect(state.player.energy, closeTo(state.player.maxEnergy, 0.5));
    });

    test('you can only sleep in bed or by a fire', () {
      final state = GameState(worldSeed: 3);
      standNextTo(state, state.world.npc(Npc.tomId)!.position);
      state.requestSleep();
      expect(state.confirmSleep, isFalse);
      expect(state.currentAction, contains('only sleep'));
    });

    test('crops only grow while watered', () {
      final crop = Crop();
      crop.advance(10);
      expect(crop.stage, 0);
      crop.watered = true;
      crop.advance(2);
      expect(crop.stage, 0);
      crop.advance(1.5);
      expect(crop.stage, 1);
      expect(crop.watered, isFalse);
      crop.advance(10);
      expect(crop.stage, 1);
    });

    test('berry bushes and apple trees bear fruit again after a day', () {
      final world = World(seed: 8)..generate();
      final key = world.appleTrees.keys.first;
      world.pickFruit(key);
      expect(world.hasFruit(key), isFalse);
      world.advanceHours(23);
      expect(world.hasFruit(key), isFalse);
      world.advanceHours(1.5);
      expect(world.hasFruit(key), isTrue);
    });

    test('trees take three hits to chop down', () {
      final state = GameState(worldSeed: 6);
      final world = state.world;
      // A tree away from water, with nothing else around it.
      final tree = world.trees.entries.firstWhere((e) {
        final x = e.value.dx.toInt();
        final y = e.value.dy.toInt();
        if (!world.isWalkable(x, y + 1)) return false;
        if (world.npcs.any((n) => (n.position - e.value).distance < 4)) return false;
        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
            if (world.getTileAt(x + dx, y + dy) == 'water') return false;
          }
        }
        return true;
      });
      world.plants.clear();
      world.animals.clear();
      world.rocks.clear();
      world.trees.removeWhere((k, v) => k != tree.key && (v - tree.value).distance < 3);
      state.player.position = tree.value + const Offset(0.5, 1.5);
      state.update(0);
      expect(state.target?.key, tree.key);

      state.interact();
      state.interact();
      expect(state.world.trees.containsKey(tree.key), isTrue);
      state.interact();
      expect(state.world.trees.containsKey(tree.key), isFalse);
      expect(state.player.count('wood'), 3);
    });
  });

  group('Sounds', () {
    test('actions and menus make sounds for the screen to play', () {
      final state = GameState(worldSeed: 1);
      state.takeSounds();

      state.toggleInventory();
      state.toggleInventory();
      expect(state.takeSounds(), ['open', 'close']);

      state.interact();
      state.acceptQuest();
      state.closeDialog();
      expect(state.takeSounds(), ['open', 'accept', 'close']);

      state.player.addItem('wood', 10);
      state.interact();
      state.handInQuest();
      expect(state.takeSounds(), ['open', 'quest']);
      expect(state.takeSounds(), isEmpty);
    });

    test('reaching a new level is celebrated', () {
      final state = GameState(worldSeed: 1);
      state.takeSounds();
      state.player.addItem('wood', 100);
      for (var i = 0; i < 12; i++) {
        state.craftItem('stick');
      }
      expect(state.player.level, 1);
      state.player.experience = state.player.experienceToNextLevel - 1;
      state.craftItem('stick');
      expect(state.player.level, 2);
      expect(state.takeSounds(), contains('levelup'));
      expect(state.floatingTexts.map((t) => t.text), contains('Level up!'));
    });
  });

  group('Items', () {
    test('crafting needs the ingredients and consumes them', () {
      final state = GameState(worldSeed: 5);
      state.craftItem('campfire');
      expect(state.player.count('campfire'), 0);

      state.player.addItem('wood', 3);
      state.craftItem('stick');
      state.craftItem('stick');
      state.craftItem('fishing_rod');
      expect(state.player.count('wood'), 0);
      expect(state.player.count('stick'), 0);
      expect(state.player.count('fishing_rod'), 2);
    });

    test('a campfire is placed in front of the player and blocks the way', () {
      final state = GameState(worldSeed: 9);
      state.player.addItem('campfire', 1);
      state.player.direction = 'down';
      final spot = Point(state.player.position.dx.floor(), state.player.position.dy.floor() + 1);

      state.useItem('campfire');
      expect(state.player.count('campfire'), 0);
      expect(state.world.campfires, [Offset(spot.x.toDouble(), spot.y.toDouble())]);
      expect(state.world.isWalkable(spot.x, spot.y), isFalse);
      expect(state.nearFire, isTrue);
    });

    test('eating restores hunger', () {
      final state = GameState(worldSeed: 5);
      state.player.hunger = 50;
      state.useItem('berry');
      expect(state.player.hunger, 60);
      expect(state.player.count('berry'), 2);
    });

    test('a campfire can never seal off the house, the farm or the villagers', () {
      for (final seed in [1, 5, 42]) {
        final state = GameState(worldSeed: seed);
        final world = state.world;
        final village = world.villageCenter;
        final vx = village.dx.toInt();
        final vy = village.dy.toInt();
        final from = world.spawnTile;

        // Not on the spot in front of the door, nor in the doorway itself.
        expect(world.canPlaceCampfire(from.x, from.y, from: Point(from.x + 1, from.y)), isFalse);
        expect(world.canPlaceCampfire(vx - 3, vy - 3, from: from), isFalse);

        // One fire in the two-tile farm gate is fine, but not a second one.
        expect(world.canPlaceCampfire(vx - 1, vy + 3, from: from), isTrue);
        world.placeCampfire(vx - 1, vy + 3);
        expect(world.canPlaceCampfire(vx, vy + 3, from: from), isFalse, reason: 'seed $seed');

        // Placing from the inventory in front of the door is refused too.
        state.player.addItem('campfire', 1);
        state.player.position = Offset(from.x + 0.5, from.y + 1.5);
        state.player.direction = 'up';
        state.useItem('campfire');
        expect(state.player.count('campfire'), 1);
        expect(state.currentAction, contains("can't place"));
      }
    });

    test('fainting always wakes you somewhere you can walk away from', () {
      final state = GameState(worldSeed: 1);
      state.world.campfires.add(state.world.playerSpawn);
      state.world.refreshSolid();
      state.player.health = 1;
      state.player.hunger = 0;
      for (var i = 0; i < 200; i++) {
        state.update(1 / 60);
      }
      final p = state.player.position;
      final tile = Point(p.dx.floor(), p.dy.floor());
      expect(state.world.isWalkable(tile.x, tile.y), isTrue);
      final reachable = state.world.reachableTiles(tile);
      expect(reachable.contains(Point(state.world.villageCenter.dx.toInt(), state.world.villageCenter.dy.toInt() + 1)),
          isTrue);
    });

    test('menus stay shut while sleeping', () {
      final state = GameState(worldSeed: 3);
      standNextTo(state, state.world.bed);
      state.requestSleep();
      state.sleep();
      state.toggleInventory();
      state.toggleMap();
      state.togglePause();
      expect(state.showInventory || state.showMap || state.isPaused, isFalse);
    });
  });

  group('Saving', () {
    test('a saved game loads with all progress intact', () {
      final state = GameState(worldSeed: 11);
      final world = state.world;
      state.questAccepted = true;
      state.player.addItem('wood', 10);
      state.handInQuest();
      state.closeDialog();
      world.unlockFarm();
      world.advanceHours(38.5);
      final cropTile = Point(world.farmArea.left.toInt(), world.farmArea.top.toInt());
      world.crops[World.cropKey(cropTile.x, cropTile.y)] = Crop(stage: 2, watered: true, growth: 1.5);
      world.pickFruit(world.appleTrees.keys.first);
      world.campfires.add(world.villageCenter + const Offset(5, -1));
      world.trees.remove(world.trees.keys.first);
      state.player.addItem('carrot', 4);
      state.player.hunger = 42.5;

      final loaded = GameState.fromJson(jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>);
      final w = loaded.world;
      expect(w.tiles, world.tiles);
      expect(w.trees.keys, world.trees.keys);
      expect(w.rocks, world.rocks);
      expect(w.plants, world.plants);
      expect(w.animals, world.animals);
      expect(w.appleTrees, world.appleTrees);
      expect(w.regrowTimers, world.regrowTimers);
      expect(w.bridgeBuilt, isTrue);
      expect(w.bridgeTiles, world.bridgeTiles);
      expect(w.farmUnlocked, isTrue);
      expect(w.farmArea, world.farmArea);
      final crop = w.crops[World.cropKey(cropTile.x, cropTile.y)]!;
      expect([crop.stage, crop.watered, crop.growth], [2, true, 1.5]);
      expect(w.campfires, world.campfires);
      expect(w.day, world.day);
      expect(w.timeOfDay, world.timeOfDay);
      expect(w.npcs.map((n) => n.position), world.npcs.map((n) => n.position));
      expect(w.bed, world.bed);
      expect(loaded.questIndex, 1);
      expect(loaded.questAccepted, isTrue);
      expect(loaded.player.inventory, state.player.inventory);
      expect(loaded.player.hunger, 42.5);
      expect(loaded.player.position, state.player.position);
    });

    test('the save service stores, summarises and ignores bad saves', () async {
      final storage = MemorySaveStorage();
      final service = SaveService(storage: storage);
      expect(await service.load(), isNull);

      final state = GameState(worldSeed: 2);
      await service.save(state);
      final summary = await service.summary();
      expect(summary!.day, 1);
      expect(summary.progress, Quest.all.first.title);
      expect(summary.chapter, 1);
      expect((await service.load())!.world.tiles, state.world.tiles);

      storage.data = '{"version": 999}';
      expect(await service.load(), isNull);
      storage.data = 'not json';
      expect(await service.load(), isNull);
      expect(await SaveService(storage: _BrokenStorage()).load(), isNull);
    });

    test('the chapter ending is shown after loading if it was missed', () {
      final state = GameState(worldSeed: 2)..questIndex = Quest.ofChapter(1).length;
      final missed = GameState.fromJson(jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>);
      expect(missed.showChapterComplete, isTrue);

      missed.closeChapterComplete();
      final seen = GameState.fromJson(jsonDecode(jsonEncode(missed.toJson())) as Map<String, dynamic>);
      expect(seen.showChapterComplete, isFalse);
    });
  });
}

void _chapterTwo() {
  group('The old mine', () {
    test('has three parts, closed off by a cobweb and fallen rocks', () {
      for (var seed = 0; seed < 20; seed++) {
        final mine = Mine(seed: seed)..generate();
        final start = mine.arrival;
        expect(mine.isWalkable(start.x, start.y), isTrue, reason: 'seed $seed');
        expect(mine.getTileAt(mine.ladder.x, mine.ladder.y), 'cave_wall', reason: 'seed $seed');
        expect(mine.webs, hasLength(1), reason: 'seed $seed');
        expect(mine.rubble, hasLength(1), reason: 'seed $seed');
        final bram = mine.npc(Npc.bramId)!;
        bool nextToBram(Set<Point<int>> area) => Level.around(bram.position).any(area.contains);

        final open = mine.reachableTiles(start);
        expect(nextToBram(open), isFalse, reason: 'seed $seed');
        final iron = mine.rocks.entries.where((e) => e.key.startsWith('iron') && open.contains(tileOf(e.value)));
        expect(iron.length, greaterThanOrEqualTo(6), reason: 'seed $seed');

        // Cutting the cobweb is not enough to reach Bram...
        mine.webs.clear();
        mine.refreshSolid();
        expect(nextToBram(mine.reachableTiles(start)), isFalse, reason: 'seed $seed');
        // ...but once the rocks are broken too, the whole mine is open.
        mine.rubble.clear();
        mine.refreshSolid();
        final all = mine.reachableTiles(start);
        expect(nextToBram(all), isTrue, reason: 'seed $seed');
        for (var y = 0; y < mine.height; y++) {
          for (var x = 0; x < mine.width; x++) {
            if (mine.isWalkable(x, y)) expect(all.contains(Point(x, y)), isTrue, reason: 'seed $seed at $x,$y');
          }
        }
      }
    });

    test('the same seed always digs the same mine', () {
      final a = Mine(seed: 5)..generate();
      final b = Mine(seed: 5)..generate();
      expect(a.tiles, b.tiles);
      expect(a.rocks, b.rocks);
      expect(a.npcs.single.position, b.npcs.single.position);
    });

    test('the valley always has a way into the mine, and room for the forge', () {
      for (var seed = 0; seed < 10; seed++) {
        final world = World(seed: seed)..generate();
        final entrance = world.mineEntrance!;
        final approach = Point(entrance.dx.toInt(), entrance.dy.toInt() + 1);
        expect(world.reachableTiles(world.spawnTile, cleared: true).contains(approach), isTrue, reason: 'seed $seed');
        for (final t in [...world.forgeTiles, tileOf(world.minerHome)]) {
          expect(world.getTileAt(t.x, t.y), 'grass', reason: 'seed $seed');
        }
      }
    });

    test('chapter 2 can be played through', () {
      final state = GameState(worldSeed: 7)
        ..questIndex = Quest.ofChapter(1).length
        ..chaptersCelebrated = 1;
      final world = state.world;
      final player = state.player;
      world.buildBridge();
      world.buildFirePit();

      // A Light in the Dark: torches from pine resin and sticks.
      talkToElder(state);
      expect(state.dialogText, Quest.all[4].intro);
      state.acceptQuest();
      state.closeDialog();
      player.addItem('resin', 2);
      player.addItem('stick', 2);
      state.craftItem('torch');
      state.craftItem('torch');
      expect(player.count('torch'), 4);
      talkToElder(state);
      state.handInQuest();
      state.closeDialog();
      expect(player.count('torch'), 4, reason: 'the elder only wanted to see them');
      expect(world.mineOpen, isTrue);

      // Into the Old Mine: a torch is lit on the way down.
      expect(state.questTargetPosition, world.mineEntrance);
      enterMine(state);
      expect(state.torchLit, isTrue);
      expect(player.count('torch'), 3);
      final mine = state.mine!;
      final open = mine.reachableTiles(mine.arrival);
      final ores = mine.rocks.entries.where((e) => e.key.startsWith('iron') && open.contains(tileOf(e.value)));
      for (final ore in ores.take(5).toList()) {
        hit(state, ore.key, ore.value, times: 3);
      }
      expect(player.count('iron_ore'), 5);
      // With the ore, the arrow points up the ladder.
      expect(state.questTargetPosition, Offset(mine.ladder.x.toDouble(), mine.ladder.y.toDouble()));
      leaveMine(state);
      talkToElder(state);
      state.handInQuest();
      state.closeDialog();

      // The Village Forge
      player.addItem('stone', 10);
      player.addItem('wood', 6);
      talkToElder(state);
      state.handInQuest();
      state.closeDialog();
      expect(world.forgeBuilt, isTrue);
      expect(state.recipeUnlocked('iron_pickaxe'), isTrue);

      // Smelt ore into ingots, then make an iron pickaxe and a sword.
      player.addItem('iron_ore', 3);
      player.addItem('wood', 3);
      final forge = world.forgeTiles.first;
      standNextTo(state, Offset(forge.x.toDouble(), forge.y.toDouble()));
      for (var i = 0; i < 3; i++) {
        expect(state.target?.type, 'smelt');
        state.interact();
      }
      expect(player.count('iron_ingot'), 3);
      player.addItem('stick', 3);
      player.addItem('wood', 2);
      state.craftItem('iron_pickaxe');
      state.craftItem('wooden_sword');
      expect(player.count('iron_pickaxe'), 1);
      expect(player.count('wooden_sword'), 1);

      // The Lost Miner: through the cobweb and the fallen rocks to Bram.
      enterMine(state);
      final rock = mine.rocks.entries.firstWhere((e) => e.key.startsWith('rock') && open.contains(tileOf(e.value)));
      hit(state, rock.key, rock.value, times: 2);
      expect(mine.rocks.containsKey(rock.key), isFalse, reason: 'iron breaks rocks in two hits');
      final web = mine.webs.entries.single;
      hit(state, web.key, web.value);
      expect(mine.webs, isEmpty);
      final fall = mine.rubble.entries.single;
      hit(state, fall.key, fall.value, times: 3);
      expect(mine.rubble, isEmpty);
      final bram = mine.npc(Npc.bramId)!;
      standNextTo(state, bram.position);
      expect(state.target?.key, Npc.bramId);
      state.interact();
      expect(state.dialogText, Npc.bramFound);
      state.closeDialog();
      expect(mine.npc(Npc.bramId), isNull);
      expect(world.npc(Npc.bramId)!.position, world.minerHome);
      expect(state.questReady, isTrue);
      leaveMine(state);
      talkToElder(state);
      state.handInQuest();
      expect(state.storyComplete, isTrue);
      state.closeDialog();
      expect(state.showChapterComplete, isTrue);
      expect(state.celebratingChapter, 2);
    });

    test('a light is needed to go down', () {
      final state = GameState(worldSeed: 3);
      state.world.mineOpen = true;
      final entrance = state.world.mineEntrance!;
      standOn(state, Point(entrance.dx.toInt(), entrance.dy.toInt() + 1));
      expect(state.target?.type, 'enter');
      state.interact();
      expect(state.isTravelling, isFalse);
      expect(state.currentAction, contains('pitch dark'));
    });

    test('torches burn down underground, and the next one is lit', () {
      final state = GameState(worldSeed: 3);
      state.world.mineOpen = true;
      state.player.addItem('torch', 2);
      enterMine(state);
      expect(state.player.count('torch'), 1);
      state.takeSounds();

      state.player.torchTime = 0.5;
      state.update(0.6);
      expect(state.player.count('torch'), 0);
      expect(state.player.torchTime, GameState.torchSeconds);
      expect(state.takeSounds(), containsAll(['fizzle', 'torch']));

      state.player.torchTime = 0.5;
      state.update(0.6);
      expect(state.heldLight, isNull);
      expect(state.currentAction, contains('last torch'));
      expect(state.lightRadius, lessThan(2));
    });

    test('torches only burn in the dark', () {
      final state = GameState(worldSeed: 3);
      state.player.addItem('torch', 1);
      state.useItem('torch');
      expect(state.player.count('torch'), 1, reason: 'too bright for a torch');
      state.world.advanceHours(16);
      state.useItem('torch');
      expect(state.torchLit, isTrue);
      state.update(1);
      expect(state.player.torchTime, closeTo(GameState.torchSeconds - 1, 0.01));
    });

    test('pines give resin, and an iron axe fells a tree in two swings', () {
      final state = GameState(worldSeed: 6);
      final world = state.world;
      world.plants.clear();
      world.animals.clear();
      world.rocks.clear();
      final pine = world.trees.entries.firstWhere((e) {
        final x = e.value.dx.toInt();
        final y = e.value.dy.toInt();
        if (!world.isPine(x, y) || world.npcs.any((n) => (n.position - e.value).distance < 4)) return false;
        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
            if (world.getTileAt(x + dx, y + dy) == 'water') return false;
          }
        }
        return true;
      });
      world.trees.removeWhere((k, v) => k != pine.key && (v - pine.value).distance < 3);
      state.player.addItem('iron_axe', 1);
      hit(state, pine.key, pine.value, times: 2);
      expect(world.trees.containsKey(pine.key), isFalse);
      expect(state.player.count('wood'), 3);
      expect(state.player.count('resin'), 1);
    });

    test('a campfire in the mine can never cut off the way deeper', () {
      final state = GameState(worldSeed: 4);
      state.world.mineOpen = true;
      state.player.addItem('torch', 1);
      enterMine(state);
      final mine = state.mine!;
      final shaft = mine.passages.first;
      mine.webs.clear();
      mine.frames.clear();
      mine.refreshSolid();
      // Not in the shaft, nor just below it, which would shut Bram in.
      expect(mine.canPlaceCampfire(shaft.x, shaft.y, from: Point(shaft.x, shaft.y - 1)), isFalse);
      expect(mine.canPlaceCampfire(shaft.x, shaft.y + 1, from: shaft), isFalse);
      // Somewhere roomy is fine.
      final (top, bottom) = Mine.parts.first;
      final roomy = [
        for (var y = top; y <= bottom; y++)
          for (var x = 2; x < mine.width - 2; x++)
            if ([for (var dy = -1; dy <= 1; dy++) for (var dx = -1; dx <= 1; dx++) Point(x + dx, y + dy)]
                .every((p) => mine.isWalkable(p.x, p.y)))
              Point(x, y),
      ].firstWhere((p) => mine.canPlaceCampfire(p.x, p.y, from: Point(p.x, p.y + 1)));
      mine.placeCampfire(roomy.x, roomy.y);
      expect(mine.isWalkable(roomy.x, roomy.y), isFalse);
    });

    test('a game saved in the mine loads back underground', () {
      final state = GameState(worldSeed: 4);
      state.world.mineOpen = true;
      state.player.addItem('torch', 3);
      enterMine(state);
      final mine = state.mine!;
      mine.webs.clear();
      mine.refreshSolid();
      state.player.torchTime = 42;

      final loaded = GameState.fromJson(jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>);
      final m = loaded.mine!;
      expect(loaded.underground, isTrue);
      expect(m.tiles, mine.tiles);
      expect(m.rocks, mine.rocks);
      expect(m.webs, isEmpty);
      expect(m.rubble, mine.rubble);
      expect(m.mushrooms, mine.mushrooms);
      expect(m.frames, mine.frames);
      expect(m.rails, mine.rails);
      expect(m.cart, mine.cart);
      expect(m.ladder, mine.ladder);
      expect(m.passages, mine.passages);
      expect(m.explored, mine.explored);
      expect(m.npcs.single.position, mine.npcs.single.position);
      expect(loaded.player.position, state.player.position);
      expect(loaded.player.torchTime, 42);
      expect(loaded.torchLit, isTrue);
      // Bram's tile is still solid after loading.
      final bram = tileOf(m.npcs.single.position);
      expect(m.isWalkable(bram.x, bram.y), isFalse);
    });

    test('older campfires where the forge and Bram belong go back in the bag', () {
      final state = GameState(worldSeed: 2);
      final world = state.world;
      final forge = world.forgeTiles.first;
      world.campfires.addAll([Offset(forge.x.toDouble(), forge.y.toDouble()), world.minerHome]);
      final json = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
      json['version'] = 1;

      final loaded = GameState.fromJson(json);
      expect(loaded.world.campfires, isEmpty);
      expect(loaded.player.count('campfire'), 2);
    });

    test('fires walled in by older ones do not stop new fires elsewhere', () {
      final world = World(seed: 2)..generate();
      final home = tileOf(world.minerHome);
      // Older campfires and the forge close in the spot where Bram will stand.
      for (final p in Level.neighbours(home)) {
        if (world.isWalkable(p.x, p.y)) world.campfires.add(Offset(p.x.toDouble(), p.y.toDouble()));
      }
      world.refreshSolid();
      expect(Level.neighbours(home).where((p) => world.isWalkable(p.x, p.y)), isEmpty);

      final village = world.villageCenter;
      final open = [
        for (var y = village.dy.toInt() + 10; y <= village.dy.toInt() + 13; y++)
          for (var x = village.dx.toInt() - 8; x <= village.dx.toInt() + 8; x++) Point(x, y),
      ];
      expect(open.any((p) => world.canPlaceCampfire(p.x, p.y, from: world.spawnTile)), isTrue);
    });

    test('no menus open during the climb', () {
      final state = GameState(worldSeed: 3);
      state.world.mineOpen = true;
      state.player.addItem('torch', 1);
      final entrance = state.world.mineEntrance!;
      standOn(state, Point(entrance.dx.toInt(), entrance.dy.toInt() + 1));
      state.interact();
      expect(state.isTravelling, isTrue);
      state.toggleInventory();
      state.toggleMap();
      state.togglePause();
      expect(state.showInventory || state.showMap || state.isPaused, isFalse);
      travel(state);
      expect(state.underground, isTrue);
    });

    test('saves from before chapter 2 load, and the new chapter is offered', () {
      final state = GameState(worldSeed: 2)
        ..questIndex = Quest.ofChapter(1).length
        ..questAccepted = true;
      final json = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
      // What a save looked like before chapter 2.
      json['version'] = 1;
      json.remove('underground');
      (json['quest'] as Map)['celebrated'] = true;
      (json['world'] as Map)
        ..remove('mineOpen')
        ..remove('forgeBuilt');
      (json['player'] as Map).remove('torch');

      final loaded = GameState.fromJson(json);
      expect(loaded.currentQuest!.id, Quest.light);
      expect(loaded.questAccepted, isFalse);
      expect(loaded.chaptersCelebrated, 1);
      expect(loaded.showChapterComplete, isFalse);
      expect(loaded.elderHasNews, isTrue);
      expect(loaded.world.mineOpen, isFalse);
      expect(loaded.world.forgeBuilt, isFalse);
      expect(loaded.world.mineEntrance, isNotNull);
      expect(loaded.player.torchTime, 0);
    });
  });
}

class _BrokenStorage implements SaveStorage {
  @override
  Future<String?> read() => Future.error(StateError('storage unavailable'));

  @override
  Future<void> write(String data) async {}

  @override
  Future<void> clear() async {}
}
