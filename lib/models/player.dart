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
  String selectedTool;

  // Stats
  int level;
  int experience;
  int experienceToNextLevel;

  // Accumulates time spent starving so damage is dealt once per interval.
  double _starvationTimer = 0;

  static const double baseSpeed = 4.0;
  static const double tiredSpeed = 2.0;

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
    this.selectedTool = 'none',
    this.level = 1,
    this.experience = 0,
    this.experienceToNextLevel = 100,
  }) : inventory = inventory ??
            {
              'wood': 0,
              'stone': 0,
              'apple': 0,
              'berry': 0,
              'fish': 0,
              'axe': 1,
              'pickaxe': 1,
              'fishing_rod': 1,
              'seeds': 0,
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
  void updateStats(double dt, {required bool moving}) {
    // A full stomach lasts roughly eight minutes.
    hunger = (hunger - 0.2 * dt).clamp(0, maxHunger.toDouble());

    // Walking tires the player faster than standing still.
    final drain = moving ? 0.4 : 0.05;
    energy = (energy - drain * dt).clamp(0, maxEnergy.toDouble());

    // Starving costs 1 health every 2 seconds.
    if (hunger <= 10) {
      _starvationTimer += dt;
      while (_starvationTimer >= 2) {
        _starvationTimer -= 2;
        takeDamage(1);
      }
    } else {
      _starvationTimer = 0;
    }

    speed = energy <= 20 ? tiredSpeed : baseSpeed;
  }

  void rest() {
    energy = (energy + 10).clamp(0, maxEnergy.toDouble());
    hunger = (hunger - 1).clamp(0, maxHunger.toDouble());
  }

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
      selectedTool: selectedTool,
      level: level,
      experience: experience,
      experienceToNextLevel: experienceToNextLevel,
    );
  }
}
