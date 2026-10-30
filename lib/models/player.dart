import 'dart:math';
import 'dart:ui';

class Player {
  // Position of the player's centre, in tile units.
  Offset position;
  // Movement speed in tiles per second.
  double speed;
  int health;
  int maxHealth;
  double hunger;
  int maxHunger;
  double energy;
  int maxEnergy;
  String direction;

  // Inventory
  Map<String, int> inventory;
  // Seconds left on the torch in hand; 0 when none is lit.
  double torchTime;

  // Stats
  int level;
  int experience;
  int experienceToNextLevel;

  // Accumulates time so health changes once per interval.
  double _healthTimer = 0;

  static const double baseSpeed = 4.0;
  static const double tiredSpeed = 2.5;

  Player({
    required this.position,
    this.speed = baseSpeed,
    this.health = 100,
    this.maxHealth = 100,
    this.hunger = 100,
    this.maxHunger = 100,
    this.energy = 100,
    this.maxEnergy = 100,
    this.direction = 'down',
    Map<String, int>? inventory,
    this.level = 1,
    this.experience = 0,
    this.experienceToNextLevel = 100,
    this.torchTime = 0,
  }) : inventory = inventory ??
            {
              'axe': 1,
              'pickaxe': 1,
              'fishing_rod': 1,
              'berry': 3,
            };

  bool get isDead => health <= 0;

  int count(String item) => inventory[item] ?? 0;

  void updateDirection(String newDirection) {
    direction = newDirection;
  }

  void takeDamage(int amount) {
    health = (health - amount).clamp(0, maxHealth);
  }

  void heal(int amount) {
    health = (health + amount).clamp(0, maxHealth);
  }

  void consumeFood(String foodType, int hungerRestore, int healthRestore) {
    if (count(foodType) > 0) {
      inventory[foodType] = count(foodType) - 1;
      hunger = (hunger + hungerRestore).clamp(0, maxHunger.toDouble());
      heal(healthRestore);
    }
  }

  void addItem(String item, int amount) {
    inventory[item] = count(item) + amount;
  }

  void removeItem(String item, int amount) {
    inventory[item] = (count(item) - amount).clamp(0, 1 << 30);
  }

  void addExperience(int amount) {
    experience += amount;
    if (experience >= experienceToNextLevel) {
      levelUp();
    }
  }

  void levelUp() {
    while (experience >= experienceToNextLevel) {
      experience -= experienceToNextLevel;
      level++;
      experienceToNextLevel = (experienceToNextLevel * 1.5).ceil();
      maxHealth = (maxHealth * 1.1).ceil();
      maxHunger = (maxHunger * 1.1).ceil();
      maxEnergy = (maxEnergy * 1.1).ceil();
      health = maxHealth;
      hunger = maxHunger.toDouble();
      energy = maxEnergy.toDouble();
    }
  }

  /// Advances survival stats by [dt] seconds.
  ///
  /// Sitting by a fire restores energy; walking tires the player, and the
  /// cold away from a fire at night tires them twice as fast.
  void updateStats(double dt, {required bool moving, bool nearFire = false, bool cold = false}) {
    // A full stomach lasts about eleven minutes.
    hunger = max(0, hunger - 0.15 * dt);

    if (nearFire && !moving) {
      energy = min(maxEnergy.toDouble(), energy + 3 * dt);
    } else {
      var drain = moving ? 0.35 : 0.03;
      if (cold) drain *= 2;
      energy = max(0, energy - drain * dt);
    }

    if (hunger <= 10) {
      // Starving costs 1 health every 2 seconds.
      _healthTimer += dt;
      while (_healthTimer >= 2) {
        _healthTimer -= 2;
        takeDamage(1);
      }
    } else if (hunger > 50 && health < maxHealth) {
      // A full stomach slowly heals 1 health every 6 seconds.
      _healthTimer += dt;
      while (_healthTimer >= 6) {
        _healthTimer -= 6;
        heal(1);
      }
    } else {
      _healthTimer = 0;
    }

    speed = energy <= 20 ? tiredSpeed : baseSpeed;
  }

  /// Restores energy after a night's sleep or a shorter nap.
  void sleep({required bool night}) {
    energy = maxEnergy.toDouble();
    hunger = max(0, hunger - (night ? 10 : 5));
    if (hunger > 20) heal(night ? 20 : 5);
  }

  Map<String, dynamic> toJson() => {
        'x': position.dx,
        'y': position.dy,
        'health': health,
        'maxHealth': maxHealth,
        'hunger': hunger,
        'maxHunger': maxHunger,
        'energy': energy,
        'maxEnergy': maxEnergy,
        'direction': direction,
        'inventory': inventory,
        'level': level,
        'experience': experience,
        'experienceToNextLevel': experienceToNextLevel,
        'torch': torchTime,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        position: Offset((json['x'] as num).toDouble(), (json['y'] as num).toDouble()),
        health: json['health'] as int,
        maxHealth: json['maxHealth'] as int,
        hunger: (json['hunger'] as num).toDouble(),
        maxHunger: json['maxHunger'] as int,
        energy: (json['energy'] as num).toDouble(),
        maxEnergy: json['maxEnergy'] as int,
        direction: json['direction'] as String,
        inventory: {
          for (final e in (json['inventory'] as Map).entries) e.key as String: (e.value as num).toInt(),
        },
        level: json['level'] as int,
        experience: json['experience'] as int,
        experienceToNextLevel: json['experienceToNextLevel'] as int,
        torchTime: (json['torch'] as num?)?.toDouble() ?? 0,
      );

  Player copy() {
    return Player(
      position: position,
      speed: speed,
      health: health,
      maxHealth: maxHealth,
      hunger: hunger,
      maxHunger: maxHunger,
      energy: energy,
      maxEnergy: maxEnergy,
      direction: direction,
      inventory: Map.from(inventory),
      level: level,
      experience: experience,
      experienceToNextLevel: experienceToNextLevel,
      torchTime: torchTime,
    );
  }
}
