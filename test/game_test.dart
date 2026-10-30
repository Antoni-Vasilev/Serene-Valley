import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:serene_valley/models/farm.dart';
import 'package:serene_valley/models/game_state.dart';
import 'package:serene_valley/models/npc.dart';
import 'package:serene_valley/models/quest.dart';
import 'package:serene_valley/models/world.dart';
import 'package:serene_valley/services/save_service.dart';

/// Puts the player on a free tile next to [tile] and updates their target.
void standNextTo(GameState state, Offset tile) {
  final x = tile.dx.toInt();
  final y = tile.dy.toInt();
  for (final d in const [Point(0, 1), Point(-1, 0), Point(1, 0), Point(0, -1)]) {
    if (state.world.isWalkable(x + d.x, y + d.y)) {
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

void main() {
  group('World generation', () {
    test('the river cuts off the east bank until the bridge is rebuilt', () {
      for (var seed = 0; seed < 10; seed++) {
        final world = World(seed: seed)..generate();
        final spawn = tileOf(world.playerSpawn);
        final westBank = world.reachableTiles(spawn);
        final withBridge = world.reachableTiles(spawn, assumeBridge: true);

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
      expect(state.dialogText, Quest.chapter.first.intro);
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
      expect(state.dialogReply, contains(Quest.chapter[1].intro));
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
      expect(state.chapterComplete, isTrue);
      state.closeDialog();
      expect(state.showChapterComplete, isTrue);
      expect(state.questTargetPosition, isNull);
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
      expect(summary.progress, Quest.chapter.first.title);
      expect((await service.load())!.world.tiles, state.world.tiles);

      storage.data = '{"version": 999}';
      expect(await service.load(), isNull);
      storage.data = 'not json';
      expect(await service.load(), isNull);
      expect(await SaveService(storage: _BrokenStorage()).load(), isNull);
    });

    test('the chapter ending is shown after loading if it was missed', () {
      final state = GameState(worldSeed: 2)..questIndex = Quest.chapter.length;
      final missed = GameState.fromJson(jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>);
      expect(missed.showChapterComplete, isTrue);

      missed.closeChapterComplete();
      final seen = GameState.fromJson(jsonDecode(jsonEncode(missed.toJson())) as Map<String, dynamic>);
      expect(seen.showChapterComplete, isFalse);
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
