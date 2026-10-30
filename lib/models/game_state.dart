import 'package:flutter/material.dart';
import 'dart:math';
import 'farm.dart';
import 'items.dart';
import 'level.dart';
import 'mine.dart';
import 'npc.dart';
import 'player.dart';
import 'quest.dart';
import 'world.dart';

/// What the action button does right now.
class Interaction {
  final String type;
  final String label;
  // Tile of the target, used for highlighting it.
  final Point<int> tile;
  // Object key, villager id or crop key, depending on [type].
  final String? key;

  const Interaction(this.type, this.label, this.tile, {this.key});
}

/// A short text that rises from a spot in the world, like "+3 Wood".
class FloatingText {
  static const double lifetime = 1.4;

  final String text;
  // In tile units.
  final Offset position;
  final Color color;
  double age = 0;

  FloatingText(this.text, this.position, this.color);
}

class GameState with ChangeNotifier {
  static const int saveVersion = 2;
  // How close (in tiles) the player must be to interact with something.
  static const double reach = 1.4;
  static const double _hitbox = 0.28;
  // How long one torch burns, in seconds.
  static const double torchSeconds = 150;
  // How long climbing into or out of the mine takes, in seconds.
  static const double _travelSeconds = 0.8;

  static const Map<String, Map<String, int>> recipes = {
    'stick': {'wood': 1},
    'fishing_rod': {'stick': 2, 'wood': 1},
    'campfire': {'wood': 5, 'stone': 3},
    'wooden_sword': {'wood': 2, 'stick': 1},
    'torch': {'resin': 1, 'stick': 1},
    'iron_axe': {'iron_ingot': 2, 'stick': 2},
    'iron_pickaxe': {'iron_ingot': 3, 'stick': 2},
    'lantern': {'iron_ingot': 1, 'crystal': 2},
  };
  // How many items one craft makes, where it is more than one.
  static const Map<String, int> craftYield = {'torch': 2};
  static const Map<String, int> _craftXp = {
    'stick': 2,
    'fishing_rod': 10,
    'campfire': 15,
    'wooden_sword': 10,
    'torch': 4,
    'iron_axe': 25,
    'iron_pickaxe': 25,
    'lantern': 30,
  };

  Player player;
  // The valley, where the village is. Its clock is the game's clock.
  World world;
  // The old mine under the eastern hills, dug out the first time someone
  // climbs down.
  Mine? mine;
  bool underground = false;

  // Game state
  bool isPaused = false;
  bool showInventory = false;
  bool showCrafting = false;
  bool showMap = false;
  String currentAction = 'none';
  // Feedback shown inside the inventory, e.g. what was just eaten.
  String? inventoryNote;

  // Camera: the world position (in tiles) shown at the centre of the screen.
  Offset cameraOffset;
  double cameraZoom = 2.0;

  // Movement requested by the controls, each axis in -1..1.
  Offset moveInput = Offset.zero;
  bool isMoving = false;
  // Seconds spent walking; drives the walk animation.
  double walkTime = 0;
  // Seconds of play; drives the other animations.
  double clock = 0;

  Interaction? target;

  // Quests
  int questIndex = 0;
  bool questAccepted = false;

  // Open conversation, and the elder's reply after a quest is handed in.
  String? dialogNpcId;
  String? dialogReply;
  bool showChapterComplete = false;
  bool _chapterJustCompleted = false;
  // How many chapter endings the player has seen.
  int chaptersCelebrated = 0;

  bool confirmSleep = false;
  // Counts down from 2 seconds through the fade-out and fade-in of sleeping.
  double sleepTimer = 0;
  bool _sleepApplied = false;

  // Counts down through the fade while climbing into or out of the mine.
  double travelTimer = 0;
  bool _travelDown = false;
  bool _travelApplied = false;

  final List<FloatingText> floatingTexts = [];
  // The tree or rock that was just hit, which shakes briefly.
  String? shakeKey;
  double shakeTime = 0;
  final Map<String, int> _hits = {};

  final Random _random = Random();
  final List<String> _sounds = [];
  bool _disposed = false;
  int _actionMessageId = 0;
  double _autosaveTimer = 0;
  bool _saveRequested = false;

  GameState({int? worldSeed})
      : world = World(seed: worldSeed),
        player = Player(position: Offset.zero),
        cameraOffset = Offset.zero {
    world.generate();
    player.position = world.playerSpawn + const Offset(0.5, 0.5);
    cameraOffset = player.position;
    _updateTarget();
  }

  GameState._loaded(
    this.world,
    this.mine,
    this.underground,
    this.player,
    this.questIndex,
    this.questAccepted,
    this.chaptersCelebrated,
  ) : cameraOffset = player.position {
    // The app may have closed before a chapter ending was shown.
    showChapterComplete = chaptersDone > chaptersCelebrated;
    _unstickPlayer();
    cameraOffset = player.position;
    _updateTarget();
  }

  /// The map the player is on.
  Level get level => underground ? mine! : world;

  // ---------------------------------------------------------------------------
  // Quests

  Quest? get currentQuest => questIndex < Quest.all.length ? Quest.all[questIndex] : null;

  /// The chapter being played, or the last one once the story is done.
  int get chapter => currentQuest?.chapter ?? Quest.chapterCount;

  /// How many chapters have been played to the end.
  int get chaptersDone {
    final quest = currentQuest;
    return quest == null ? Quest.chapterCount : quest.chapter - 1;
  }

  /// Whether every quest of every chapter is done.
  bool get storyComplete => currentQuest == null;

  /// The chapter whose ending is shown next.
  int get celebratingChapter => min(chaptersCelebrated + 1, Quest.chapterCount);

  bool get questReady {
    final quest = currentQuest;
    if (!questAccepted || quest == null) return false;
    final meet = quest.meet;
    return quest.requires.entries.every((e) => player.count(e.key) >= e.value) &&
        // Someone to find has to be back in the village.
        (meet == null || world.npc(meet) != null);
  }

  /// Whether the elder has a task to give, or one to take back.
  bool get elderHasNews => currentQuest != null && (!questAccepted || questReady);

  /// Where the quest arrow points: the elder when there is news for him (or
  /// the ladder, from down in the mine), and the mine when the task is there.
  Offset? get questTargetPosition {
    final quest = currentQuest;
    if (quest == null) return null;
    if (elderHasNews) {
      if (!underground) return world.npc(Npc.elderId)?.position;
      final ladder = mine!.ladder;
      return Offset(ladder.x.toDouble(), ladder.y.toDouble());
    }
    if (!underground && (quest.id == Quest.ore || quest.id == Quest.miner)) return world.mineEntrance;
    return null;
  }

  /// Whether the story has reached the quest [id].
  bool _reached(String id) => questIndex >= Quest.all.indexWhere((q) => q.id == id);

  void acceptQuest() {
    questAccepted = true;
    _sound('accept');
    notifyListeners();
  }

  void handInQuest() {
    final quest = currentQuest;
    if (quest == null || !questReady) return;

    if (!quest.keep) quest.requires.forEach(player.removeItem);
    _xp(quest.xp);
    _applyQuestReward(quest.id);
    _sound('quest');
    questIndex++;

    // The elder hands out the next task of the chapter straight away. A new
    // chapter begins after its ending has been celebrated.
    final next = currentQuest;
    if (next != null && next.chapter == quest.chapter) {
      questAccepted = true;
      dialogReply = '${quest.done}\n\n${next.intro}';
    } else {
      questAccepted = false;
      dialogReply = quest.done;
      _chapterJustCompleted = true;
    }
    _saveRequested = true;
    notifyListeners();
  }

  void _applyQuestReward(String questId) {
    switch (questId) {
      case Quest.bridge:
        world.buildBridge();
        break;
      case Quest.fire:
        world.buildFirePit();
        _unstickPlayer();
        break;
      case Quest.feast:
        world.unlockFarm();
        player.addItem('watering_can', 1);
        player.addItem('seeds', 5);
        break;
      case Quest.light:
        world.mineOpen = true;
        break;
      case Quest.forge:
        world.buildForge();
        _unstickPlayer();
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Dialog

  /// Who the open conversation is with.
  Npc? get dialogNpc {
    final id = dialogNpcId;
    return id == null ? null : level.npc(id);
  }

  /// What the villager in the open conversation says.
  String get dialogText {
    final id = dialogNpcId;
    if (id == null) return '';
    if (dialogReply != null) return dialogReply!;
    if (id == Npc.bramId && underground) return Npc.bramFound;
    final quest = currentQuest;
    if (id != Npc.elderId || quest == null) return Npc.line(id, questIndex);
    if (!questAccepted) return quest.intro;
    if (questReady) return quest.ready;
    return quest.reminder;
  }

  void _openDialog(String npcId) {
    dialogNpcId = npcId;
    dialogReply = null;
    _sound('open');
  }

  void closeDialog() {
    final id = dialogNpcId;
    dialogNpcId = null;
    dialogReply = null;
    if (id == Npc.bramId && underground) _bramGoesHome();
    if (_chapterJustCompleted) {
      _chapterJustCompleted = false;
      showChapterComplete = true;
      _sound('fanfare');
    } else {
      _sound('close');
    }
    _updateTarget();
    notifyListeners();
  }

  void closeChapterComplete() {
    showChapterComplete = false;
    chaptersCelebrated = chaptersDone;
    _saveRequested = true;
    notifyListeners();
  }

  /// Bram, found at last, makes his own way back to the village.
  void _bramGoesHome() {
    final mine = this.mine!;
    mine.npcs.removeWhere((n) => n.id == Npc.bramId);
    mine.refreshSolid();
    world.npcs.add(Npc.create(Npc.bramId, world.minerHome));
    world.refreshSolid();
    _sound('accept');
    _showAction('Bram heads for the ladder. Tell Elder Rowan the good news!');
    _saveRequested = true;
  }

  // ---------------------------------------------------------------------------
  // Game loop

  bool get isSleeping => sleepTimer > 0;

  bool get isTravelling => travelTimer > 0;

  bool get isMenuOpen =>
      showInventory ||
      showCrafting ||
      showMap ||
      isPaused ||
      dialogNpcId != null ||
      showChapterComplete ||
      confirmSleep ||
      isSleeping ||
      isTravelling;

  bool get nearFire => _distanceToNearestFire() <= 3;

  /// Advances the simulation by [dt] seconds.
  void update(double dt) {
    if (isSleeping) {
      _updateSleep(dt);
      notifyListeners();
      return;
    }
    if (isTravelling) {
      _updateTravel(dt);
      notifyListeners();
      return;
    }
    if (isMenuOpen) return;

    clock += dt;
    // Time passes in the valley while the player is underground too.
    world.updateTime(dt);

    isMoving = moveInput != Offset.zero;
    if (isMoving) {
      _movePlayer(moveInput, dt);
      walkTime += dt;
    }

    final warm = nearFire;
    player.updateStats(
      dt,
      moving: isMoving,
      nearFire: warm,
      cold: !warm && !underground && world.getLightLevel() < 0.5,
    );
    if (player.isDead) {
      _respawn();
    }

    _updateLight(dt);
    if (underground) mine!.explore(player.position, max(2.0, lightRadius));
    _updateEffects(dt);
    _updateTarget();
    _updateCamera(dt);

    _autosaveTimer += dt;
    if (_autosaveTimer >= 30) {
      _autosaveTimer = 0;
      _saveRequested = true;
    }

    notifyListeners();
  }

  void _updateEffects(double dt) {
    for (final text in floatingTexts) {
      text.age += dt;
    }
    floatingTexts.removeWhere((t) => t.age >= FloatingText.lifetime);
    shakeTime = max(0, shakeTime - dt);
  }

  void _movePlayer(Offset direction, double dt) {
    if (direction.distance > 1) {
      direction = direction / direction.distance;
    }
    final step = direction * player.speed * dt;

    // Resolve each axis separately so the player slides along walls.
    _moveAxis(step.dx, horizontal: true, perpendicular: step.dy);
    _moveAxis(step.dy, horizontal: false, perpendicular: step.dx);

    if (direction.dx.abs() > direction.dy.abs()) {
      player.updateDirection(direction.dx > 0 ? 'right' : 'left');
    } else {
      player.updateDirection(direction.dy > 0 ? 'down' : 'up');
    }
  }

  void _moveAxis(double amount, {required bool horizontal, required double perpendicular}) {
    if (amount == 0) return;
    final delta = horizontal ? Offset(amount, 0) : Offset(0, amount);
    if (_tryMove(delta)) return;

    // Blocked. If a small sidestep clears the obstacle, e.g. at a doorway,
    // slide towards the gap so the player doesn't have to line up exactly.
    final signs = perpendicular < 0 ? const [-1.0, 1.0] : const [1.0, -1.0];
    for (final offset in const [0.1, 0.2, 0.3, 0.4]) {
      for (final sign in signs) {
        final side = horizontal ? Offset(0, offset * sign) : Offset(offset * sign, 0);
        if (_canStandAt(player.position + side) && _canStandAt(player.position + side + delta)) {
          final slide = min(amount.abs(), offset) * sign;
          _tryMove(horizontal ? Offset(0, slide) : Offset(slide, 0));
          return;
        }
      }
    }
  }

  bool _tryMove(Offset delta) {
    final next = player.position + delta;
    if (!_canStandAt(next)) return false;
    player.position = next;
    return true;
  }

  bool _canStandAt(Offset p) {
    // Check the corners of a slightly smaller-than-tile hitbox.
    const r = _hitbox;
    final level = this.level;
    for (final c in [
      Offset(p.dx - r, p.dy - r),
      Offset(p.dx + r, p.dy - r),
      Offset(p.dx - r, p.dy + r),
      Offset(p.dx + r, p.dy + r),
    ]) {
      if (!level.isWalkable(c.dx.floor(), c.dy.floor())) return false;
    }
    return true;
  }

  /// Moves the player out of anything that became solid around them.
  void _unstickPlayer() {
    if (!_canStandAt(player.position)) {
      player.position = level.nearestReachableTile(player.position) + const Offset(0.5, 0.5);
    }
  }

  void _updateCamera(double dt) {
    // Frame-rate independent smoothing.
    final t = 1 - pow(0.001, dt).toDouble();
    cameraOffset = Offset.lerp(cameraOffset, player.position, t)!;
  }

  void _respawn() {
    player.health = (player.maxHealth / 2).ceil();
    player.hunger = player.maxHunger / 2;
    player.energy = player.maxEnergy / 2;
    if (underground) {
      underground = false;
      _hits.clear();
    }
    player.position = world.playerSpawn + const Offset(0.5, 0.5);
    _unstickPlayer();
    _sound('deny');
    _showAction('You fainted and woke up in the village...');
  }

  // ---------------------------------------------------------------------------
  // Light

  bool get _isDark => underground || world.getLightLevel() < 0.6;

  /// What the player holds up to see by in the dark: 'lantern', 'torch' or
  /// null. Torches only burn in the dark, and a lantern makes them needless.
  String? get heldLight {
    if (!_isDark) return null;
    if (player.count('lantern') > 0) return 'lantern';
    return player.torchTime > 0 ? 'torch' : null;
  }

  bool get torchLit => heldLight == 'torch';

  /// How far the player's light reaches, in tiles. A torch dims as it
  /// burns down.
  double get lightRadius => switch (heldLight) {
        'lantern' => 5.5,
        'torch' => 4.5 * (0.55 + 0.45 * min(1.0, player.torchTime / 20)),
        _ => underground ? 1.4 : 2.2,
      };

  /// Whether the player has something to light the way with.
  bool get hasLight => player.count('lantern') > 0 || player.torchTime > 0 || player.count('torch') > 0;

  void _updateLight(double dt) {
    if (!torchLit) return;
    player.torchTime = max(0.0, player.torchTime - dt);
    if (player.torchTime > 0) return;
    _sound('fizzle');
    if (!underground) {
      _showAction('Your torch burned out.');
    } else if (player.count('torch') > 0) {
      _lightTorch();
      _showAction('Your torch burned out, so you light a new one.');
    } else {
      _showAction('Your last torch burned out! Find your way back to the ladder.');
    }
  }

  void _lightTorch() {
    player.removeItem('torch', 1);
    player.torchTime = torchSeconds;
    _sound('torch');
  }

  // ---------------------------------------------------------------------------
  // The mine

  void _travel({required bool down}) {
    travelTimer = _travelSeconds;
    _travelDown = down;
    _travelApplied = false;
    _sound('climb');
    _updateTarget();
  }

  void _updateTravel(double dt) {
    travelTimer = max(0, travelTimer - dt);
    // Change places while the screen is dark.
    if (!_travelApplied && travelTimer <= _travelSeconds / 2) {
      _travelApplied = true;
      _travelDown ? _arriveInMine() : _arriveInValley();
    }
    if (!isTravelling) _updateTarget();
  }

  void _arriveInMine() {
    final mine = this.mine ??= (Mine(seed: world.seed + 1)..generate());
    underground = true;
    _hits.clear();
    player.position = Offset(mine.arrival.x + 0.5, mine.arrival.y + 0.5);
    player.direction = 'down';
    cameraOffset = player.position;
    if (player.count('lantern') == 0 && player.torchTime == 0 && player.count('torch') > 0) {
      _lightTorch();
      _showAction('You light a torch and climb down into the old mine.');
    } else {
      _showAction('You climb down into the old mine.');
    }
    mine.explore(player.position, lightRadius);
    _saveRequested = true;
  }

  void _arriveInValley() {
    underground = false;
    _hits.clear();
    final entrance = world.mineEntrance;
    player.position = entrance == null
        ? world.playerSpawn + const Offset(0.5, 0.5)
        : entrance + const Offset(0.5, 1.5);
    player.direction = 'down';
    _unstickPlayer();
    cameraOffset = player.position;
    _saveRequested = true;
  }

  // ---------------------------------------------------------------------------
  // Interaction

  Point<int> get _playerTile => Point(player.position.dx.floor(), player.position.dy.floor());

  void _updateTarget() {
    target = isMenuOpen ? null : _findTarget();
  }

  /// The closest thing within reach that the player can interact with.
  Interaction? _findTarget() {
    final p = player.position;
    Interaction? best;
    double bestDistance = reach;

    // A [bias] favours the way in or out over whatever else is close by.
    void offer(Offset tile, Interaction Function() make, {double bias = 0}) {
      final d = (tile + const Offset(0.5, 0.5) - p).distance - bias;
      if (d < bestDistance) {
        bestDistance = d;
        best = make();
      }
    }

    Point<int> tileOf(Offset o) => Point(o.dx.toInt(), o.dy.toInt());

    final level = this.level;
    for (final npc in level.npcs) {
      offer(npc.position, () => Interaction('talk', 'Talk', tileOf(npc.position), key: npc.id));
    }
    for (final e in level.rocks.entries) {
      offer(e.value, () => Interaction('mine', 'Mine', tileOf(e.value), key: e.key));
    }
    for (final fire in level.fires) {
      offer(fire, () => Interaction('cook', 'Cook', tileOf(fire)));
    }

    if (level is Mine) {
      for (final e in level.webs.entries) {
        offer(e.value, () => Interaction('cut', 'Cut', tileOf(e.value), key: e.key));
      }
      for (final e in level.rubble.entries) {
        offer(e.value, () => Interaction('clear', 'Break', tileOf(e.value), key: e.key));
      }
      final ladder = level.ladder;
      offer(Offset(ladder.x.toDouble(), ladder.y.toDouble()), () => Interaction('climb', 'Climb', ladder), bias: 0.3);
    } else {
      for (final e in world.trees.entries) {
        offer(e.value, () => Interaction('chop', 'Chop', tileOf(e.value), key: e.key));
      }
      for (final e in world.plants.entries) {
        if (e.key.startsWith('berry_bush') && world.hasFruit(e.key)) {
          offer(e.value, () => Interaction('pick', 'Pick', tileOf(e.value), key: e.key));
        } else if (e.key.startsWith('grass_tall')) {
          offer(e.value, () => Interaction('search', 'Search', tileOf(e.value), key: e.key));
        }
      }
      for (final e in world.appleTrees.entries) {
        if (world.hasFruit(e.key)) {
          offer(e.value, () => Interaction('pick_apple', 'Pick', tileOf(e.value), key: e.key));
        }
      }
      offer(world.bed, () => Interaction('sleep', 'Sleep', tileOf(world.bed)));
      for (final (i, cave) in world.caveEntrances.indexed) {
        offer(cave, () {
          if (i > 0) return Interaction('cave', 'Look', tileOf(cave));
          return world.mineOpen
              ? Interaction('enter', 'Enter', tileOf(cave))
              : Interaction('mine_closed', 'Look', tileOf(cave));
        }, bias: i == 0 ? 0.3 : 0);
      }
      for (final t in world.forgeTiles) {
        offer(Offset(t.x.toDouble(), t.y.toDouble()), () {
          return world.forgeBuilt ? Interaction('smelt', 'Smelt', t) : Interaction('forge_ruin', 'Look', t);
        });
      }
      for (final e in world.animals.entries) {
        offer(e.value, () => Interaction('watch', 'Watch', tileOf(e.value), key: e.key));
      }
    }

    // Tiles around the player: farmland, water and the broken bridge.
    final here = _playerTile;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final x = here.x + dx;
        final y = here.y + dy;
        final tile = level.getTileAt(x, y);
        final spot = Offset(x.toDouble(), y.toDouble());
        if (tile == 'farmland') {
          offer(spot, () => _farmInteraction(x, y));
        } else if (tile == 'water') {
          if (!underground && world.isBridgeSite(x, y)) {
            offer(spot, () => Interaction('bridge_site', 'Look', Point(x, y)));
          } else {
            offer(spot, () => Interaction('fish', 'Fish', Point(x, y)));
          }
        }
      }
    }
    return best;
  }

  Interaction _farmInteraction(int x, int y) {
    final key = World.cropKey(x, y);
    final crop = world.crops[key];
    final tile = Point(x, y);
    if (crop == null) return Interaction('plant', 'Plant', tile, key: key);
    if (crop.isRipe) return Interaction('harvest', 'Harvest', tile, key: key);
    if (!crop.watered) return Interaction('water', 'Water', tile, key: key);
    return Interaction('growing', 'Growing', tile, key: key);
  }

  void interact() {
    if (isMenuOpen) return;
    final t = target;
    if (t == null) {
      _showAction('Nothing to interact with here.');
      _sound('deny');
      notifyListeners();
      return;
    }

    switch (t.type) {
      case 'talk':
        _openDialog(t.key!);
        break;
      case 'chop':
        final tree = world.trees[t.key!]!;
        final pine = world.isPine(tree.dx.toInt(), tree.dy.toInt());
        _gather(t, world.trees, {'wood': 3, if (pine) 'resin': 1}, hits: _has('iron_axe') ? 2 : 3, sound: 'chop');
        break;
      case 'mine':
        final key = t.key!;
        final items = key.startsWith('iron')
            ? {'iron_ore': 1}
            : key.startsWith('crystal')
                ? {'crystal': 1}
                : {'stone': 2};
        final broke = _gather(t, level.rocks, items, hits: _has('iron_pickaxe') ? 2 : 3, sound: 'mine');
        if (broke && key.startsWith('crystal')) _sound('chime');
        break;
      case 'pick':
        _sound('pick');
        world.pickFruit(t.key!);
        _gain('berry', 2, t.tile);
        _xp(2);
        break;
      case 'pick_apple':
        _sound('pick');
        world.pickFruit(t.key!);
        _gain('apple', 1 + _random.nextInt(2), t.tile);
        _xp(2);
        break;
      case 'search':
        _sound('pick');
        world.plants.remove(t.key);
        if (_random.nextDouble() < 0.4) {
          _gain('seeds', 1, t.tile);
        } else {
          _float('Nothing here', t.tile, Colors.white70);
        }
        break;
      case 'fish':
        _fish(t);
        break;
      case 'cook':
        _cook(t);
        break;
      case 'sleep':
        requestSleep();
        break;
      case 'plant':
        if (player.count('seeds') == 0) {
          _showAction('You have no seeds. Search the tall grass to find some.');
          _sound('deny');
        } else {
          player.removeItem('seeds', 1);
          world.crops[t.key!] = Crop();
          _sound('plant');
          _float('Planted', t.tile, Colors.lightGreenAccent);
        }
        break;
      case 'water':
        world.crops[t.key!]!.watered = true;
        _sound('water');
        _float('Watered', t.tile, Colors.lightBlueAccent);
        break;
      case 'growing':
        _showAction('It needs time to grow. Water it again once it has grown.');
        break;
      case 'harvest':
        _sound('pick');
        world.crops.remove(t.key);
        _gain('carrot', 2, t.tile);
        _gain('seeds', 1 + _random.nextInt(2), t.tile, below: true);
        _xp(5);
        break;
      case 'bridge_site':
        _showAction('The bridge is broken. Elder Rowan wants to rebuild it.');
        _sound('open');
        break;
      case 'cave':
        _showAction('A shallow cave. A cold draft blows out of the dark.');
        _sound('open');
        break;
      case 'mine_closed':
        _showAction(_reached(Quest.light)
            ? 'The old mine is boarded up. Elder Rowan has the key.'
            : 'An old mine, boarded up since the storm. A cold draft blows through the planks.');
        _sound('open');
        break;
      case 'enter':
        if (hasLight) {
          _travel(down: true);
        } else {
          _showAction("It's pitch dark down there. Bring a torch.");
          _sound('deny');
        }
        break;
      case 'climb':
        _travel(down: false);
        break;
      case 'cut':
        _cutWeb(t);
        break;
      case 'clear':
        _breakRubble(t);
        break;
      case 'smelt':
        _smelt(t);
        break;
      case 'forge_ruin':
        _showAction(_reached(Quest.forge)
            ? 'The old forge, cold and crumbling. Elder Rowan wants it rebuilt.'
            : 'An old forge, cold and crumbling.');
        _sound('open');
        break;
      case 'watch':
        _showAction(_animalLine(t.key!));
        _sound('open');
        break;
    }
    _updateTarget();
    notifyListeners();
  }

  bool _has(String item) => player.count(item) > 0;

  /// Chopping and mining take a few [hits]; the last one yields [items].
  /// Returns whether the thing came down.
  bool _gather(
    Interaction t,
    Map<String, Offset> source,
    Map<String, int> items, {
    required int hits,
    required String sound,
  }) {
    if (!_useEnergy(1.5)) return false;
    _sound(sound);
    final key = t.key!;
    shakeKey = key;
    shakeTime = 0.25;
    final count = (_hits[key] ?? 0) + 1;
    if (count < hits) {
      _hits[key] = count;
      return false;
    }
    _hits.remove(key);
    source.remove(key);
    var below = false;
    for (final e in items.entries) {
      _gain(e.key, e.value, t.tile, below: below);
      below = true;
    }
    _xp(5);
    return true;
  }

  void _cutWeb(Interaction t) {
    if (!_has('wooden_sword')) {
      _showAction('A thick cobweb blocks the shaft. A sword would cut right through it.');
      _sound('deny');
      return;
    }
    final mine = this.mine!;
    mine.webs.remove(t.key);
    mine.refreshSolid();
    _sound('swish');
    _float('Cut!', t.tile, Colors.white);
    _xp(5);
    _saveRequested = true;
  }

  void _breakRubble(Interaction t) {
    if (!_has('iron_pickaxe')) {
      _showAction('Fallen rocks block the shaft. Only an iron pickaxe could break through.');
      _sound('deny');
      return;
    }
    final mine = this.mine!;
    if (_gather(t, mine.rubble, {'stone': 3}, hits: 3, sound: 'mine')) {
      mine.refreshSolid();
      _sound('crumble');
      _saveRequested = true;
    }
  }

  void _smelt(Interaction t) {
    if (!_has('iron_ore')) {
      _showAction('Bring iron ore from the mine to smelt it here.');
      _sound('deny');
      return;
    }
    if (!_has('wood')) {
      _showAction('The forge burns one piece of wood for each ingot.');
      _sound('deny');
      return;
    }
    player.removeItem('iron_ore', 1);
    player.removeItem('wood', 1);
    _sound('smelt');
    _gain('iron_ingot', 1, t.tile);
    _xp(4);
  }

  void _fish(Interaction t) {
    if (player.count('fishing_rod') == 0) {
      _showAction('You need a fishing rod. Craft one from sticks and wood.');
      _sound('deny');
      return;
    }
    if (!_useEnergy(1)) return;
    _sound('splash');
    if (_random.nextDouble() < 0.35) {
      _gain('fish', 1, t.tile);
      _xp(3);
    } else {
      _float('Nothing bites...', t.tile, Colors.white70);
      _sound('nibble');
    }
  }

  void _cook(Interaction t) {
    if (player.count('fish') == 0) {
      _showAction('Catch some fish, then cook them here. You can also sleep by the fire.');
      _sound('deny');
      return;
    }
    player.removeItem('fish', 1);
    _sound('sizzle');
    _gain('cooked_fish', 1, t.tile);
    _xp(2);
  }

  bool _useEnergy(double amount) {
    if (player.energy < 5) {
      _showAction('Too tired to work. Rest by a fire or sleep in your bed.');
      _sound('deny');
      return false;
    }
    player.energy = max(0, player.energy - amount);
    return true;
  }

  String _animalLine(String key) {
    if (key.startsWith('rabbit')) return 'The rabbit twitches its nose and watches you.';
    if (key.startsWith('deer')) return 'The deer lifts its head, then calmly goes back to grazing.';
    return 'The bird chirps a little song.';
  }

  void _gain(String item, int amount, Point<int> tile, {bool below = false}) {
    player.addItem(item, amount);
    _sound('pickup');
    final info = Items.of(item);
    _float('+$amount ${info.name}', tile, info.color, below: below);
  }

  void _float(String text, Point<int> tile, Color color, {bool below = false}) {
    floatingTexts.add(FloatingText(text, Offset(tile.x + 0.5, tile.y + (below ? 0.5 : 0.0)), color));
  }

  void _showAction(String message) {
    currentAction = message;
    final id = ++_actionMessageId;
    Future.delayed(const Duration(seconds: 3), () {
      // Only clear if no newer message replaced this one.
      if (!_disposed && id == _actionMessageId) {
        currentAction = 'none';
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Sleeping

  double _distanceToNearestFire() {
    var best = double.infinity;
    for (final fire in level.fires) {
      best = min(best, (fire + const Offset(0.5, 0.5) - player.position).distance);
    }
    return best;
  }

  bool get canSleepHere =>
      (!underground && (world.bed + const Offset(0.5, 0.5) - player.position).distance <= 1.6) ||
      _distanceToNearestFire() <= 2.5;

  void requestSleep() {
    if (isMenuOpen) return;
    if (!canSleepHere) {
      _showAction('You can only sleep in your bed or next to a campfire.');
      _sound('deny');
    } else {
      confirmSleep = true;
      _sound('open');
      _updateTarget();
    }
    notifyListeners();
  }

  void cancelSleep() {
    confirmSleep = false;
    _sound('close');
    _updateTarget();
    notifyListeners();
  }

  void sleep() {
    confirmSleep = false;
    sleepTimer = 2.0;
    _sound('sleep');
    _sleepApplied = false;
    notifyListeners();
  }

  void _updateSleep(double dt) {
    sleepTimer = max(0, sleepTimer - dt);
    // Skip time while the screen is fully dark.
    if (!_sleepApplied && sleepTimer <= 1.0) {
      _sleepApplied = true;
      final night = !world.isDay;
      world.advanceHours(night ? _hoursUntilMorning() : 3);
      player.sleep(night: night);
      _saveRequested = true;
      _showAction(night ? 'Good morning! Day ${world.day} begins.' : 'You feel rested after a nap.');
    }
    if (!isSleeping) _updateTarget();
  }

  double _hoursUntilMorning() {
    final t = world.timeOfDay;
    return t >= 6 ? 24 - t + 6 : 6 - t;
  }

  // ---------------------------------------------------------------------------
  // Inventory and crafting

  /// Eats food, places a campfire, lights a torch, or explains what the item
  /// is for.
  void useItem(String id) {
    final info = Items.of(id);
    if (player.count(id) == 0) return;
    if (info.isFood) {
      player.consumeFood(id, info.hunger, info.health);
      inventoryNote = 'You ate ${info.name.toLowerCase()}. +${info.hunger} hunger';
      _sound('eat');
    } else if (id == 'campfire') {
      _placeCampfire();
    } else if (id == 'torch') {
      if (_has('lantern')) {
        inventoryNote = 'Your lantern already lights the way.';
        _sound('open');
      } else if (player.torchTime > 0) {
        inventoryNote = 'You already have a torch lit.';
        _sound('open');
      } else if (!_isDark) {
        inventoryNote = "It's bright enough out here. A torch only burns in the dark.";
        _sound('deny');
      } else {
        _lightTorch();
        inventoryNote = 'You light a torch.';
      }
    } else {
      inventoryNote = '${info.name}: ${info.description}';
      _sound('open');
    }
    notifyListeners();
  }

  void _placeCampfire() {
    showInventory = false;
    final tile = _facingTile();
    if (!level.canPlaceCampfire(tile.x, tile.y, from: _playerTile) || _hitboxOverlaps(tile)) {
      _showAction("You can't place a campfire there. Face an open spot that isn't in anyone's way.");
      _sound('deny');
      return;
    }
    player.removeItem('campfire', 1);
    level.placeCampfire(tile.x, tile.y);
    _sound('place');
    _showAction('Campfire placed. Cook fish and sleep beside it.');
    _updateTarget();
  }

  Point<int> _facingTile() {
    final here = _playerTile;
    switch (player.direction) {
      case 'up':
        return Point(here.x, here.y - 1);
      case 'left':
        return Point(here.x - 1, here.y);
      case 'right':
        return Point(here.x + 1, here.y);
      default:
        return Point(here.x, here.y + 1);
    }
  }

  bool _hitboxOverlaps(Point<int> tile) {
    final p = player.position;
    return p.dx + _hitbox > tile.x &&
        p.dx - _hitbox < tile.x + 1 &&
        p.dy + _hitbox > tile.y &&
        p.dy - _hitbox < tile.y + 1;
  }

  /// Whether the story has shown the player how to make [id] yet.
  bool recipeUnlocked(String id) => switch (id) {
        'torch' => _reached(Quest.light),
        'iron_axe' || 'iron_pickaxe' || 'lantern' => world.forgeBuilt,
        _ => true,
      };

  bool canCraft(String id) =>
      recipeUnlocked(id) && recipes[id]!.entries.every((e) => player.count(e.key) >= e.value);

  void craftItem(String id) {
    final recipe = recipes[id];
    if (recipe == null || !canCraft(id)) return;
    recipe.forEach(player.removeItem);
    player.addItem(id, craftYield[id] ?? 1);
    _sound('craft');
    _xp(_craftXp[id] ?? 0);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Menus

  // No menus while the screen fades for sleep or for the climb.
  bool get _busy => isSleeping || isTravelling;

  void toggleInventory() {
    if (_busy) return;
    showInventory = !showInventory;
    _sound(showInventory ? 'open' : 'close');
    showCrafting = false;
    showMap = false;
    inventoryNote = null;
    _updateTarget();
    notifyListeners();
  }

  void toggleCrafting() {
    if (_busy) return;
    showCrafting = !showCrafting;
    _sound(showCrafting ? 'open' : 'close');
    showInventory = false;
    showMap = false;
    _updateTarget();
    notifyListeners();
  }

  void toggleMap() {
    if (_busy) return;
    showMap = !showMap;
    _sound(showMap ? 'open' : 'close');
    showInventory = false;
    showCrafting = false;
    _updateTarget();
    notifyListeners();
  }

  void togglePause() {
    if (_busy) return;
    isPaused = !isPaused;
    _sound(isPaused ? 'open' : 'close');
    _updateTarget();
    notifyListeners();
  }

  /// Closes whatever panel is open; returns false if none was.
  bool closeOverlay() {
    if (dialogNpcId != null) {
      closeDialog();
    } else if (showChapterComplete) {
      closeChapterComplete();
    } else if (confirmSleep) {
      cancelSleep();
    } else if (showInventory || showCrafting || showMap) {
      showInventory = showCrafting = showMap = false;
      _updateTarget();
      notifyListeners();
    } else {
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Saving

  /// Sounds that happened since the last call, named after the files in
  /// assets/audio, for the screen to play.
  List<String> takeSounds() {
    final sounds = List.of(_sounds);
    _sounds.clear();
    return sounds;
  }

  void _sound(String name) => _sounds.add(name);

  /// Adds experience, and celebrates reaching a new level.
  void _xp(int amount) {
    final level = player.level;
    player.addExperience(amount);
    if (player.level > level) {
      _sound('levelup');
      _float('Level up!', _playerTile, const Color(0xFFFFD54F));
    }
  }

  /// Whether something worth saving happened since the last call.
  bool takeSaveRequest() {
    final requested = _saveRequested;
    _saveRequested = false;
    return requested;
  }

  Map<String, dynamic> toJson() => {
        'version': saveVersion,
        'world': world.toJson(),
        if (mine case final mine?) 'mine': mine.toJson(),
        'underground': underground,
        'player': player.toJson(),
        'quest': {'index': questIndex, 'accepted': questAccepted, 'celebrated': chaptersCelebrated},
      };

  /// Loads a save, including those from before chapter 2 (version 1).
  factory GameState.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version != 1 && version != saveVersion) {
      throw FormatException('Unsupported save version $version');
    }
    final quest = json['quest'] as Map<String, dynamic>;
    final index = quest['index'] as int;
    // Version 1 saved whether the one chapter ending had been seen.
    final celebrated = quest['celebrated'];
    final chaptersCelebrated = celebrated is int ? celebrated : (celebrated == true ? 1 : 0);
    // A version 1 save past the end of chapter 1 waits for chapter 2 to be
    // offered.
    final accepted = (quest['accepted'] as bool) && !(version == 1 && index >= Quest.ofChapter(1).length);
    final mineJson = json['mine'] as Map<String, dynamic>?;
    final mine = mineJson == null ? null : Mine.fromJson(mineJson);
    final world = World.fromJson(json['world'] as Map<String, dynamic>);
    final player = Player.fromJson(json['player'] as Map<String, dynamic>);
    // Campfires that stand where the forge and Bram belong go back in the bag.
    final returned = world.clearStoryGround();
    if (returned > 0) player.addItem('campfire', returned);
    return GameState._loaded(
      world,
      mine,
      mine != null && (json['underground'] as bool? ?? false),
      player,
      index,
      accepted,
      chaptersCelebrated,
    );
  }
}
