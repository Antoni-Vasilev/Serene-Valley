import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/items.dart';
import '../models/player.dart';
import 'dialog_panel.dart';
import 'map_overlay.dart';
import 'panel.dart';

class HUDWidget extends StatelessWidget {
  final GameState gameState;
  final VoidCallback onSave;
  final VoidCallback onMainMenu;

  const HUDWidget({
    super.key,
    required this.gameState,
    required this.onSave,
    required this.onMainMenu,
  });

  Player get player => gameState.player;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top bar - stats and the current quest
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatsBar(context),
                _buildQuestTracker(),
              ],
            ),
          ),
        ),

        // Action message
        if (gameState.currentAction != 'none')
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: SafeArea(child: Center(child: _buildActionMessage())),
          ),

        // Bottom bar - controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(top: false, child: _buildControlBar(context)),
        ),

        if (gameState.showInventory) _buildInventoryOverlay(context),
        if (gameState.showCrafting) _buildCraftingOverlay(context),
        if (gameState.showMap) MapOverlay(gameState: gameState),
        if (gameState.dialogNpcId != null) DialogPanel(gameState: gameState),
        if (gameState.confirmSleep) SleepPrompt(gameState: gameState),
        if (gameState.showChapterComplete) ChapterCompletePanel(gameState: gameState),
        if (gameState.isPaused) _buildPauseMenu(context),
        if (gameState.isSleeping) _buildSleepFade(),
      ],
    );
  }

  Widget _buildStatsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      color: Colors.black.withValues(alpha: 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildStatIcon(Icons.favorite, Colors.red, player.health.toDouble(), player.maxHealth, 'Health'),
              const SizedBox(width: 8),
              _buildStatIcon(Icons.fastfood, Colors.orange, player.hunger, player.maxHunger, 'Hunger'),
              const SizedBox(width: 8),
              _buildStatIcon(Icons.bolt, Colors.yellow, player.energy, player.maxEnergy, 'Energy'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildLevelIndicator()),
              _buildTimeIndicator(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatIcon(IconData icon, Color color, double current, int max, String label) {
    double percentage = (current / max).clamp(0.0, 1.0);

    return Expanded(
      child: Tooltip(
        message: label,
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Expanded(
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[800],
                color: color,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${current.ceil()}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
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
        Flexible(
          child: Text(
            'XP: ${player.experience}/${player.experienceToNextLevel}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeIndicator() {
    final world = gameState.world;
    final time = world.timeOfDay;
    final hours = time.floor().toString().padLeft(2, '0');
    final minutes = ((time - time.floor()) * 60).floor().toString().padLeft(2, '0');
    IconData icon = world.isDay ? Icons.wb_sunny : Icons.nightlight_round;
    Color color = world.isDay ? Colors.yellow : Colors.blue;

    return Row(
      children: [
        Text(
          'Day ${world.day}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          '$hours:$minutes',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildQuestTracker() {
    final quest = gameState.currentQuest;
    final String title;
    final String detail;
    bool highlight = true;
    if (quest == null) {
      title = 'Chapter 1 complete';
      detail = 'Explore the valley and enjoy it!';
      highlight = false;
    } else if (!gameState.questAccepted) {
      title = quest.title;
      detail = 'Talk to Elder Rowan in the village';
    } else if (gameState.questReady) {
      title = quest.title;
      detail = 'Return to Elder Rowan';
    } else {
      title = quest.title;
      detail = quest.requires.entries
          .map((e) => '${Items.of(e.key).name} ${min(player.count(e.key), e.value)}/${e.value}')
          .join('   ');
      highlight = false;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
      color: Colors.black.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.flag, color: highlight ? Colors.amber : Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  detail,
                  style: TextStyle(color: highlight ? Colors.amber : Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 118),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        gameState.currentAction,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildControlBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: Colors.black.withValues(alpha: 0.7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(Icons.inventory, 'Items', gameState.toggleInventory),
          _buildControlButton(Icons.build, 'Craft', gameState.toggleCrafting),
          _buildControlButton(Icons.map, 'Map', gameState.toggleMap),
          _buildControlButton(Icons.bedtime, 'Sleep', gameState.requestSleep),
          _buildControlButton(Icons.pause, 'Pause', gameState.togglePause),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, Function() onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
          tooltip: label,
          visualDensity: VisualDensity.compact,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildInventoryOverlay(BuildContext context) {
    final items = player.inventory.entries.where((e) => e.value > 0).toList();
    final note = gameState.inventoryNote;

    return FullScreenPanel(
      title: 'Inventory',
      icon: Icons.inventory,
      onClose: gameState.toggleInventory,
      child: Column(
        children: [
          // Eating changes the stats, so show them here too.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _buildStatIcon(Icons.favorite, Colors.red, player.health.toDouble(), player.maxHealth, 'Health'),
                const SizedBox(width: 8),
                _buildStatIcon(Icons.fastfood, Colors.orange, player.hunger, player.maxHunger, 'Hunger'),
                const SizedBox(width: 8),
                _buildStatIcon(Icons.bolt, Colors.yellow, player.energy, player.maxEnergy, 'Energy'),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _buildInventoryItem(items[index].key, items[index].value),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              note ?? 'Tap food to eat it, or a campfire to place it in front of you.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryItem(String item, int count) {
    final info = Items.of(item);
    final hint = switch (info.kind) {
      ItemKind.food => 'Eat',
      ItemKind.placeable => 'Place',
      _ => null,
    };

    return GestureDetector(
      onTap: () => gameState.useItem(item),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hint != null ? info.color.withValues(alpha: 0.6) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(info.icon, color: info.color, size: 26),
            const SizedBox(height: 4),
            Text(
              info.name,
              style: const TextStyle(color: Colors.white, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              hint == null ? '$count' : '$count · $hint',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCraftingOverlay(BuildContext context) {
    final recipes = GameState.recipes.entries.toList();

    return FullScreenPanel(
      title: 'Crafting',
      icon: Icons.build,
      onClose: gameState.toggleCrafting,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final id = recipes[index].key;
          final info = Items.of(id);
          final canCraft = gameState.canCraft(id);

          return Card(
            color: Colors.grey[800],
            child: ListTile(
              leading: Icon(info.icon, color: info.color),
              title: Text(
                '${info.name}  (have ${player.count(id)})',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text.rich(
                TextSpan(
                  children: [
                    for (final e in recipes[index].value.entries)
                      TextSpan(
                        text: '${Items.of(e.key).name} ${player.count(e.key)}/${e.value}   ',
                        style: TextStyle(
                          color: player.count(e.key) >= e.value ? Colors.lightGreenAccent : Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              trailing: ElevatedButton(
                onPressed: canCraft ? () => gameState.craftItem(id) : null,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: Colors.white10,
                  disabledForegroundColor: Colors.white38,
                ),
                child: const Text('Craft'),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPauseMenu(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.85),
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
                onPressed: onSave,
                child: const Text('Save Game'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onMainMenu,
                child: const Text('Main Menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleepFade() {
    // Fades to black and back over the two seconds of sleep.
    final alpha = (1 - (gameState.sleepTimer - 1).abs()).clamp(0.0, 1.0);
    return Positioned.fill(
      // Swallow taps so nothing can be opened while asleep.
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: alpha),
          child: Center(
            child: Text(
              'Zzz...',
              style: TextStyle(color: Colors.white.withValues(alpha: alpha), fontSize: 28),
            ),
          ),
        ),
      ),
    );
  }
}
