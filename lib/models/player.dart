import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';

class Player {
  Offset position;
  double speed;
  int health;
  int maxHealth;
  int hunger;
  int maxHunger;
  int energy;
  int maxEnergy;
  String direction;
  
  // Inventory
  Map<String, int> inventory;
  String selectedTool;
  
  // Stats
  int level;
  int experience;
  int experienceToNextLevel;

  Player({
    required this.position,
    this.speed = 2.0,
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
  }) : inventory = inventory ?? {
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

  void move(Offset delta) {
    position += delta * speed;
  }

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
    if (inventory[foodType]! > 0) {
      inventory[foodType] = inventory[foodType]! - 1;
      hunger = (hunger + hungerRestore).clamp(0, maxHunger);
      heal(healthRestore);
    }
  }

  void addItem(String item, int count) {
    inventory[item] = (inventory[item] ?? 0) + count;
  }

  void removeItem(String item, int count) {
    inventory[item] = (inventory[item] ?? 0) - count;
    if (inventory[item]! < 0) inventory[item] = 0;
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
      hunger = maxHunger;
      energy = maxEnergy;
    }
  }

  void updateStats() {
    // Decrease hunger over time
    hunger = (hunger - 0.1).clamp(0.0, maxHunger.toDouble()).floor();
    
    // Decrease energy over time
    energy = (energy - 0.05).clamp(0.0, maxEnergy.toDouble()).floor();
    
    // If hunger is too low, take damage
    if (hunger <= 10) {
      takeDamage(1);
    }
    
    // If energy is too low, move slower
    if (energy <= 20) {
      speed = 1.0;
    } else {
      speed = 2.0;
    }
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
