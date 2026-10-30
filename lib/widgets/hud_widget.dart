import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/world.dart';

class HUDWidget extends StatelessWidget {
  final Player player;
  final GameState gameState;
  final Function(String) onToolSelected;
  final Function(String) onFoodEaten;
  final Function() onInventoryToggle;
  final Function() onCraftingToggle;
  final Function() onMapToggle;

  const HUDWidget({
    super.key,
    required this.player,
    required this.gameState,
    required this.onToolSelected,
    required this.onFoodEaten,
    required this.onInventoryToggle,
    required this.onCraftingToggle,
    required this.onMapToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top bar - stats
        _buildStatsBar(context),
        
        // Action message
        if (gameState.currentAction != 'none')
          _buildActionMessage(),
        
        // Bottom bar - controls
        _buildControlBar(context),
        
        // Inventory overlay
        if (gameState.showInventory)
          _buildInventoryOverlay(context),
        
        // Crafting overlay
        if (gameState.showCrafting)
          _buildCraftingOverlay(context),
        
        // Map overlay
        if (gameState.showMap)
          _buildMapOverlay(context),
        
        // Pause menu
        if (gameState.isPaused)
          _buildPauseMenu(context),
      ],
    );
  }

  Widget _buildStatsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black.withOpacity(0.7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Health
          _buildStatIcon(
            Icons.favorite,
            Colors.red,
            player.health,
            player.maxHealth,
            'Health',
          ),
          
          // Hunger
          _buildStatIcon(
            Icons.fastfood,
            Colors.orange,
            player.hunger,
            player.maxHunger,
            'Hunger',
          ),
          
          // Energy
          _buildStatIcon(
            Icons.bolt,
            Colors.yellow,
            player.energy,
            player.maxEnergy,
            'Energy',
          ),
          
          // Level
          _buildLevelIndicator(),
          
          // Time
          _buildTimeIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatIcon(IconData icon, Color color, int current, int max, String label) {
    double percentage = current / max;
    
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        SizedBox(
          width: 60,
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[800],
            color: color,
            minHeight: 8,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$current/$max',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLevelIndicator() {
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.yellow, size: 20),
        const SizedBox(width: 4),
        Text(
          'Lvl ${player.level}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(width: 4),
        Text(
          'XP: ${player.experience}/${player.experienceToNextLevel}',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildTimeIndicator() {
    String timeString = '${gameState.world.timeOfDay.floor()}:00';
    IconData icon = gameState.world.isDay ? Icons.wb_sunny : Icons.nightlight_round;
    Color color = gameState.world.isDay ? Colors.yellow : Colors.blue;
    
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          timeString,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildActionMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withOpacity(0.7),
      child: Text(
        gameState.currentAction,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildControlBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black.withOpacity(0.7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(Icons.arrow_upward, 'Up', () {}),
          _buildControlButton(Icons.inventory, 'Inventory', onInventoryToggle),
          _buildControlButton(Icons.build, 'Craft', onCraftingToggle),
          _buildControlButton(Icons.map, 'Map', onMapToggle),
          _buildSelectedToolIndicator(),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, Function() onPressed) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
          tooltip: label,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSelectedToolIndicator() {
    String toolName = player.selectedTool;
    IconData icon = _getToolIcon(toolName);
    
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        Text(
          toolName.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        if (player.inventory[toolName]! > 0 || toolName == 'none')
          Text(
            toolName == 'none' ? '' : '${player.inventory[toolName]}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
      ],
    );
  }

  IconData _getToolIcon(String tool) {
    switch (tool) {
      case 'axe':
        return Icons.agriculture;
      case 'pickaxe':
        return Icons.minimize;
      case 'fishing_rod':
        return Icons.catching_pokemon;
      case 'stick':
        return Icons.linear_scale;
      case 'wooden_sword':
        return Icons.yard;
      case 'campfire':
        return Icons.fireplace;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildInventoryOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Column(
          children: [
            // Title
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.brown[800],
              child: const Row(
                children: [
                  Icon(Icons.inventory, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Inventory',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
            
            // Inventory grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: player.inventory.length,
                itemBuilder: (context, index) {
                  String item = player.inventory.keys.elementAt(index);
                  int count = player.inventory.values.elementAt(index);
                  
                  if (count <= 0) return Container();
                  
                  return _buildInventoryItem(item, count);
                },
              ),
            ),
            
            // Close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: onInventoryToggle,
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItem(String item, int count) {
    IconData icon = _getItemIcon(item);
    String displayName = item.replaceAll('_', ' ');
    
    return GestureDetector(
      onTap: () {
        if (item == 'apple' || item == 'berry' || item == 'fish') {
          onFoodEaten(item);
        } else {
          onToolSelected(item);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: player.selectedTool == item ? Colors.yellow : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              displayName,
              style: const TextStyle(color: Colors.white, fontSize: 10),
              textAlign: TextAlign.center,
            ),
            Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getItemIcon(String item) {
    switch (item) {
      case 'wood':
        return Icons.nature;
      case 'stone':
        return Icons.landscape;
      case 'apple':
        return Icons.apple;
      case 'berry':
        return Icons.local_florist;
      case 'fish':
        return Icons.catching_pokemon;
      case 'axe':
        return Icons.agriculture;
      case 'pickaxe':
        return Icons.minimize;
      case 'fishing_rod':
        return Icons.catching_pokemon;
      case 'stick':
        return Icons.linear_scale;
      case 'seeds':
        return Icons.grass;
      case 'wooden_sword':
        return Icons.yard;
      case 'campfire':
        return Icons.fireplace;
      default:
        return Icons.inventory;
    }
  }

  Widget _buildCraftingOverlay(BuildContext context) {
    List<Map<String, dynamic>> recipes = [
      {
        'name': 'Stick',
        'id': 'stick',
        'ingredients': {'wood': 1},
        'icon': Icons.linear_scale,
      },
      {
        'name': 'Wooden Sword',
        'id': 'wooden_sword',
        'ingredients': {'wood': 2, 'stick': 1},
        'icon': Icons.yard,
      },
      {
        'name': 'Campfire',
        'id': 'campfire',
        'ingredients': {'wood': 5, 'stone': 3},
        'icon': Icons.fireplace,
      },
      {
        'name': 'Fishing Rod',
        'id': 'fishing_rod',
        'ingredients': {'stick': 2, 'wood': 1},
        'icon': Icons.catching_pokemon,
      },
    ];

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Column(
          children: [
            // Title
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.brown[800],
              child: const Row(
                children: [
                  Icon(Icons.build, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Crafting',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
            
            // Recipes list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  var recipe = recipes[index];
                  bool canCraft = _canCraftRecipe(recipe['ingredients']);
                  
                  return Card(
                    color: Colors.grey[800],
                    child: ListTile(
                      leading: Icon(recipe['icon'], color: Colors.white),
                      title: Text(
                        recipe['name'],
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _formatIngredients(recipe['ingredients']),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: canCraft 
                          ? IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => gameState.craftItem(recipe['id']),
                            )
                          : const Icon(Icons.close, color: Colors.red),
                    ),
                  );
                },
              ),
            ),
            
            // Close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: onCraftingToggle,
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canCraftRecipe(Map<String, int> ingredients) {
    for (var entry in ingredients.entries) {
      if ((player.inventory[entry.key] ?? 0) < entry.value) {
        return false;
      }
    }
    return true;
  }

  String _formatIngredients(Map<String, int> ingredients) {
    return ingredients.entries
        .map((e) => '${e.key.replaceAll('_', ' ')}: ${e.value}')
        .join(', ');
  }

  Widget _buildMapOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Column(
          children: [
            // Title
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.brown[800],
              child: const Row(
                children: [
                  Icon(Icons.map, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Map',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
            
            // Map content
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CustomPaint(
                  painter: MapPainter(
                    world: gameState.world,
                    playerPosition: gameState.player.position,
                    tileSize: 4,
                  ),
                ),
              ),
            ),
            
            // Close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: onMapToggle,
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseMenu(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Paused',
                style: TextStyle(color: Colors.white, fontSize: 32),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: gameState.togglePause,
                child: const Text('Resume'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Save Game'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Main Menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final World world;
  final Offset playerPosition;
  final double tileSize;

  MapPainter({
    required this.world,
    required this.playerPosition,
    required this.tileSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.green[900]!
      ..style = PaintingStyle.fill;

    final playerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final villagePaint = Paint()
      ..color = Colors.brown
      ..style = PaintingStyle.fill;

    final waterPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // Draw map
    double scaleX = size.width / world.width;
    double scaleY = size.height / world.height;
    double scale = scaleX < scaleY ? scaleX : scaleY;
    
    double offsetX = (size.width - world.width * scale) / 2;
    double offsetY = (size.height - world.height * scale) / 2;

    // Draw tiles
    for (int y = 0; y < world.height; y++) {
      for (int x = 0; x < world.width; x++) {
        String tile = world.getTileAt(x, y);
        
        if (tile == 'water') {
          canvas.drawRect(
            Rect.fromLTWH(
              offsetX + x * scale,
              offsetY + y * scale,
              scale,
              scale,
            ),
            waterPaint,
          );
        } else if (tile == 'wood_floor' || tile == 'wood_wall') {
          canvas.drawRect(
            Rect.fromLTWH(
              offsetX + x * scale,
              offsetY + y * scale,
              scale,
              scale,
            ),
            villagePaint,
          );
        }
      }
    }

    // Draw village locations
    for (var location in world.villageLocations) {
      canvas.drawRect(
        Rect.fromLTWH(
          offsetX + location.dx * scale - 2,
          offsetY + location.dy * scale - 2,
          scale + 4,
          scale + 4,
        ),
        villagePaint,
      );
    }

    // Draw player position
    canvas.drawRect(
      Rect.fromLTWH(
        offsetX + playerPosition.dx * scale - 3,
        offsetY + playerPosition.dy * scale - 3,
        scale + 6,
        scale + 6,
      ),
      playerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
