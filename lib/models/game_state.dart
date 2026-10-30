import 'package:flutter/material.dart';
import 'dart:math';
import 'farm.dart';
import 'items.dart';
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
  static const int saveVersion = 1;
  // How close (in tiles) the player must be to interact with something.
  static const double reach = 1.4;
  static const double _hitbox = 0.28;

  static const Map<String, Map<String, int>> recipes = {
    'stick': {'wood': 1},
    'fishing_rod': {'stick': 2, 'wood': 1},
    'campfire': {'wood': 5, 'stone': 3},
    'wooden_sword': {'wood': 2, 'stick': 1},
  };
  static const Map<String, int> _craftXp = {
    'stick': 2,
    'fishing_rod': 10,
    'campfire': 15,
    'wooden_sword': 10,
  };

  Player player;
  World world;

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
  // Whether the player has seen the end-of-chapter screen.
  bool chapterCelebrated = false;

  bool confirmSleep = false;
  // Counts down from 2 seconds through the fade-out and fade-in of sleeping.
  double sleepTimer = 0;
  bool _sleepApplied = false;

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

  GameState._loaded(this.world, this.player, this.questIndex, this.questAccepted, this.chapterCelebrated)
      : cameraOffset = player.position {
    // The app may have closed before the chapter ending was shown.
    showChapterComplete = chapterComplete && !chapterCelebrated;
    _unstickPlayer();
    cameraOffset = player.position;
    _updateTarget();
  }

  // ---------------------------------------------------------------------------
  // Quests

  Quest? get currentQuest => questIndex < Quest.chapter.length ? Quest.chapter[questIndex] : null;

  bool get chapterComplete => currentQuest == null;

  bool get questReady {
    final quest = currentQuest;
    return questAccepted &&
        quest != null &&
        quest.requires.entries.every((e) => player.count(e.key) >= e.value);
  }

  /// Where the quest arrow points: the elder, when there is something to
  /// tell or hand in.
  Offset? get questTargetPosition {
    if (chapterComplete || (questAccepted && !questReady)) return null;
    return world.npc(Npc.elderId)?.position;
  }

  void acceptQuest() {
    questAccepted = true;
    _sound('accept');
    notifyListeners();
  }

  void handInQuest() {
    final quest = currentQuest;
    if (quest == null || !questReady) return;

    quest.requires.forEach(player.removeItem);
    _xp(quest.xp);
    _applyQuestReward(quest.id);
    _sound('quest');
    questIndex++;
    // The elder hands out the next task straight away.
    questAccepted = true;

    final next = currentQuest;
    dialogReply = next == null ? quest.done : '${quest.done}\n\n${next.intro}';
    _chapterJustCompleted = next == null;
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
    }
  }

  // ---------------------------------------------------------------------------
  // Dialog

  /// What the villager in the open conversation says.
  String get dialogText {
    final id = dialogNpcId;
    if (id == null) return '';
    if (dialogReply != null) return dialogReply!;
    final quest = currentQuest;
    if (id != Npc.elderId || quest == null) return Npc.line(id, questIndex);
    if (!questAccepted) return quest.intro;
    if (questReady) return 'You brought everything I asked for. Shall we get to work?';
    return quest.reminder;
  }

  void _openDialog(String npcId) {
    dialogNpcId = npcId;
    dialogReply = null;
    _sound('open');
  }

  void closeDialog() {
    dialogNpcId = null;
    dialogReply = null;
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
    chapterCelebrated = true;
    _saveRequested = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Game loop

  bool get isSleeping => sleepTimer > 0;

  bool get isMenuOpen =>
      showInventory ||
      showCrafting ||
      showMap ||
      isPaused ||
      dialogNpcId != null ||
      showChapterComplete ||
      confirmSleep ||
      isSleeping;

  bool get nearFire => _distanceToNearestFire() <= 3;

  /// Advances the simulation by [dt] seconds.
  void update(double dt) {
    if (isSleeping) {
      _updateSleep(dt);
      notifyListeners();
      return;
    }
    if (isMenuOpen) return;

    clock += dt;
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
      cold: !warm && world.getLightLevel() < 0.5,
    );
    if (player.isDead) {
      _respawn();
    }

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
    for (final c in [
      Offset(p.dx - r, p.dy - r),
      Offset(p.dx + r, p.dy - r),
      Offset(p.dx - r, p.dy + r),
      Offset(p.dx + r, p.dy + r),
    ]) {
      if (!world.isWalkable(c.dx.floor(), c.dy.floor())) return false;
    }
    return true;
  }

  /// Moves the player out of anything that became solid around them.
  void _unstickPlayer() {
    if (!_canStandAt(player.position)) {
      player.position = world.nearestReachableTile(player.position) + const Offset(0.5, 0.5);
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
    player.position = world.playerSpawn + const Offset(0.5, 0.5);
    _unstickPlayer();
    _sound('deny');
    _showAction('You fainted and woke up in the village...');
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

    void offer(Offset tile, Interaction Function() make) {
      final d = (tile + const Offset(0.5, 0.5) - p).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = make();
      }
    }

    Point<int> tileOf(Offset o) => Point(o.dx.toInt(), o.dy.toInt());

    for (final npc in world.npcs) {
      offer(npc.position, () => Interaction('talk', 'Talk', tileOf(npc.position), key: npc.id));
    }
    for (final e in world.trees.entries) {
      offer(e.value, () => Interaction('chop', 'Chop', tileOf(e.value), key: e.key));
    }
    for (final e in world.rocks.entries) {
      offer(e.value, () => Interaction('mine', 'Mine', tileOf(e.value), key: e.key));
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
    for (final fire in world.fires) {
      offer(fire, () => Interaction('cook', 'Cook', tileOf(fire)));
    }
    offer(world.bed, () => Interaction('sleep', 'Sleep', tileOf(world.bed)));
    for (final cave in world.caveEntrances) {
      offer(cave, () => Interaction('cave', 'Look', tileOf(cave)));
    }
    for (final e in world.animals.entries) {
      offer(e.value, () => Interaction('watch', 'Watch', tileOf(e.value), key: e.key));
    }

    // Tiles around the player: farmland, water and the broken bridge.
    final here = _playerTile;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final x = here.x + dx;
        final y = here.y + dy;
        final tile = world.getTileAt(x, y);
        final spot = Offset(x.toDouble(), y.toDouble());
        if (tile == 'farmland') {
          offer(spot, () => _farmInteraction(x, y));
        } else if (tile == 'water') {
          if (world.isBridgeSite(x, y)) {
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
        _gather(t, world.trees, 'wood', 3);
        break;
      case 'mine':
        _gather(t, world.rocks, 'stone', 2);
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
        _showAction('A cold draft blows out of the dark cave. Better not go in without a light.');
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

  /// Chopping and mining take three hits; the last one yields [amount].
  void _gather(Interaction t, Map<String, Offset> source, String item, int amount) {
    if (!_useEnergy(1.5)) return;
    _sound(item == 'wood' ? 'chop' : 'mine');
    final key = t.key!;
    shakeKey = key;
    shakeTime = 0.25;
    final hits = (_hits[key] ?? 0) + 1;
    if (hits < 3) {
      _hits[key] = hits;
      return;
    }
    _hits.remove(key);
    source.remove(key);
    _gain(item, amount, t.tile);
    _xp(5);
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
    for (final fire in world.fires) {
      best = min(best, (fire + const Offset(0.5, 0.5) - player.position).distance);
    }
    return best;
  }

  bool get canSleepHere =>
      (world.bed + const Offset(0.5, 0.5) - player.position).distance <= 1.6 ||
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

  /// Eats food, places a campfire, or explains what the item is for.
  void useItem(String id) {
    final info = Items.of(id);
    if (player.count(id) == 0) return;
    if (info.isFood) {
      player.consumeFood(id, info.hunger, info.health);
      inventoryNote = 'You ate ${info.name.toLowerCase()}. +${info.hunger} hunger';
      _sound('eat');
    } else if (id == 'campfire') {
      _placeCampfire();
    } else {
      inventoryNote = '${info.name}: ${info.description}';
      _sound('open');
    }
    notifyListeners();
  }

  void _placeCampfire() {
    showInventory = false;
    final tile = _facingTile();
    if (!world.canPlaceCampfire(tile.x, tile.y, from: _playerTile) || _hitboxOverlaps(tile)) {
      _showAction("You can't place a campfire there. Face an open spot that isn't in anyone's way.");
      _sound('deny');
      return;
    }
    player.removeItem('campfire', 1);
    world.placeCampfire(tile.x, tile.y);
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

  bool canCraft(String id) => recipes[id]!.entries.every((e) => player.count(e.key) >= e.value);

  void craftItem(String id) {
    final recipe = recipes[id];
    if (recipe == null || !canCraft(id)) return;
    recipe.forEach(player.removeItem);
    player.addItem(id, 1);
    _sound('craft');
    _xp(_craftXp[id] ?? 0);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Menus

  void toggleInventory() {
    if (isSleeping) return;
    showInventory = !showInventory;
    _sound(showInventory ? 'open' : 'close');
    showCrafting = false;
    showMap = false;
    inventoryNote = null;
    _updateTarget();
    notifyListeners();
  }

  void toggleCrafting() {
    if (isSleeping) return;
    showCrafting = !showCrafting;
    _sound(showCrafting ? 'open' : 'close');
    showInventory = false;
    showMap = false;
    _updateTarget();
    notifyListeners();
  }

  void toggleMap() {
    if (isSleeping) return;
    showMap = !showMap;
    _sound(showMap ? 'open' : 'close');
    showInventory = false;
    showCrafting = false;
    _updateTarget();
    notifyListeners();
  }

  void togglePause() {
    if (isSleeping) return;
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
        'player': player.toJson(),
        'quest': {'index': questIndex, 'accepted': questAccepted, 'celebrated': chapterCelebrated},
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != saveVersion) {
      throw FormatException('Unsupported save version ${json['version']}');
    }
    final quest = json['quest'] as Map<String, dynamic>;
    return GameState._loaded(
      World.fromJson(json['world'] as Map<String, dynamic>),
      Player.fromJson(json['player'] as Map<String, dynamic>),
      quest['index'] as int,
      quest['accepted'] as bool,
      quest['celebrated'] as bool? ?? false,
    );
  }
}
