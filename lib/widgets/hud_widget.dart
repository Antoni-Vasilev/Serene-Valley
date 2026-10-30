import 'dart:math';
import 'package:flutter/material.dart';
import '../graphics/ui_textures.dart';
import '../models/game_state.dart';
import '../models/items.dart';
import '../models/player.dart';
import 'dialog_panel.dart';
import 'map_overlay.dart';
import 'pixel_ui.dart';
import 'sound_toggles.dart';

class HUDWidget extends StatelessWidget {
  final GameState gameState;
  final VoidCallback onSave;
  final VoidCallback onMainMenu;
  // Shows a "Game saved" note in the pause menu.
  final bool justSaved;

  const HUDWidget({
    super.key,
    required this.gameState,
    required this.onSave,
    required this.onMainMenu,
    this.justSaved = false,
  });

  Player get player => gameState.player;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top: stats, clock and the current quest, with messages below.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildStats()),
                      const SizedBox(width: 6),
                      _buildClock(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildQuestTracker(),
                  if (gameState.currentAction != 'none') ...[
                    const SizedBox(height: 8),
                    _buildActionMessage(),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Bottom bar - controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: _buildControlBar(context),
            ),
          ),
        ),

        if (gameState.showInventory) _buildInventoryOverlay(context),
        if (gameState.showCrafting) _buildCraftingOverlay(context),
        if (gameState.showMap) MapOverlay(gameState: gameState),
        if (gameState.dialogNpcId != null) DialogPanel(gameState: gameState),
        if (gameState.confirmSleep) SleepPrompt(gameState: gameState),
        if (gameState.showChapterComplete)
          ChapterCompletePanel(gameState: gameState),
        if (gameState.isPaused) _buildPauseMenu(context),
        if (gameState.isSleeping) _buildSleepFade(),
      ],
    );
  }

  Widget _buildStats() {
    return PixelPanel(
      frame: PixelFrame.plate,
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStat('heart', const Color(0xFFE5484D), player.health.toDouble(),
              player.maxHealth, 'Health'),
          const SizedBox(height: 3),
          _buildStat('food', const Color(0xFFF59A23), player.hunger,
              player.maxHunger, 'Hunger'),
          const SizedBox(height: 3),
          _buildStat('energy', const Color(0xFFFFD54F), player.energy,
              player.maxEnergy, 'Energy'),
        ],
      ),
    );
  }

  Widget _buildStat(
      String icon, Color color, double current, int max, String label) {
    return Tooltip(
      message: label,
      child: Row(
        children: [
          PixelIcon(icon, size: 18),
          const SizedBox(width: 6),
          Expanded(
              child: PixelBar(value: current / max, color: color, height: 12)),
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            child: Text('${current.ceil()}',
                style: pixelText(13, bold: true), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildClock() {
    final world = gameState.world;
    final time = world.timeOfDay;
    final hours = time.floor().toString().padLeft(2, '0');
    final minutes =
        ((time - time.floor()) * 60).floor().toString().padLeft(2, '0');

    return PixelPanel(
      frame: PixelFrame.plate,
      padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PixelIcon(world.isDay ? 'sun' : 'moon', size: 20),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day ${world.day}',
                      style: pixelText(12, color: UiColors.faded)),
                  Text('$hours:$minutes', style: pixelText(17, bold: true)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PixelIcon('star', size: 14),
              const SizedBox(width: 4),
              Text('Lv ${player.level}',
                  style: pixelText(13, bold: true, color: UiColors.gold)),
              const SizedBox(width: 6),
              SizedBox(
                width: 44,
                child: PixelBar(
                  value: player.experience / player.experienceToNextLevel,
                  color: const Color(0xFF7FB6F0),
                  height: 9,
                ),
              ),
            ],
          ),
        ],
      ),
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
          .map((e) =>
              '${Items.of(e.key).name} ${min(player.count(e.key), e.value)}/${e.value}')
          .join('   ');
      highlight = false;
    }

    return PixelPanel(
      frame: PixelFrame.note,
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Row(
        children: [
          const PixelIcon('flag', size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: pixelText(14, bold: true, color: UiColors.ink)),
                Text(
                  detail,
                  style: pixelText(13,
                      color: highlight
                          ? const Color(0xFFB0401C)
                          : UiColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMessage() {
    return PixelPanel(
      frame: PixelFrame.note,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        gameState.currentAction,
        style: pixelText(14, color: UiColors.ink),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildControlBar(BuildContext context) {
    return PixelPanel(
      frame: PixelFrame.plate,
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _buildControlButton('bag', 'Items', gameState.toggleInventory),
          _buildControlButton('hammer', 'Craft', gameState.toggleCrafting),
          _buildControlButton('map', 'Map', gameState.toggleMap),
          _buildControlButton('moon', 'Sleep', gameState.requestSleep),
          _buildControlButton('pause', 'Pause', gameState.togglePause),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      String icon, String label, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: PixelButton(
          onPressed: onPressed,
          tooltip: label,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PixelIcon(icon, size: 24),
              const SizedBox(height: 2),
              Text(label, style: pixelText(12, bold: true)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryOverlay(BuildContext context) {
    final items = player.inventory.entries.where((e) => e.value > 0).toList();
    final note = gameState.inventoryNote;

    return PixelWindow(
      title: 'Inventory',
      icon: 'bag',
      onClose: gameState.toggleInventory,
      child: Column(
        children: [
          // Eating changes the stats, so show them here too.
          PixelPanel(
            frame: PixelFrame.plate,
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: _buildStat('heart', const Color(0xFFE5484D),
                      player.health.toDouble(), player.maxHealth, 'Health'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStat('food', const Color(0xFFF59A23),
                      player.hunger, player.maxHunger, 'Hunger'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _buildInventoryItem(items[index].key, items[index].value),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: PixelPanel(
              frame: PixelFrame.parchment,
              padding: const EdgeInsets.all(4),
              child: Text(
                note ??
                    'Tap food to eat it, or a campfire to place it in front of you.',
                style: pixelText(14, color: UiColors.ink),
              ),
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
      child: PixelPanel(
        frame: hint != null ? PixelFrame.highlightSlot : PixelFrame.slot,
        padding: const EdgeInsets.all(2),
        child: Stack(
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PixelIcon(UiTextures.itemIcon(item), size: 36),
                      const SizedBox(height: 3),
                      Text(
                        info.name,
                        style: pixelText(11),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hint != null)
                        Text(hint,
                            style: pixelText(11,
                                bold: true, color: UiColors.gold)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Text('$count', style: pixelText(13, bold: true)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCraftingOverlay(BuildContext context) {
    final recipes = GameState.recipes.entries.toList();

    return PixelWindow(
      title: 'Crafting',
      icon: 'hammer',
      onClose: gameState.toggleCrafting,
      child: ListView.separated(
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final id = recipes[index].key;
          final info = Items.of(id);
          final canCraft = gameState.canCraft(id);

          return PixelPanel(
            frame: PixelFrame.slot,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                PixelIcon(UiTextures.itemIcon(id), size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${info.name}  (have ${player.count(id)})',
                          style: pixelText(15, bold: true)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          for (final e in recipes[index].value.entries)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PixelIcon(UiTextures.itemIcon(e.key), size: 16),
                                const SizedBox(width: 3),
                                Text(
                                  '${player.count(e.key)}/${e.value}',
                                  style: pixelText(
                                    13,
                                    color: player.count(e.key) >= e.value
                                        ? UiColors.good
                                        : UiColors.faded,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PixelButton(
                  onPressed: canCraft ? () => gameState.craftItem(id) : null,
                  style: PixelButtonStyle.gold,
                  child: const Text('Craft'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPauseMenu(BuildContext context) {
    return PixelModal(
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Paused',
                style: pixelText(30, bold: true, color: UiColors.gold),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            PixelButton(
                onPressed: gameState.togglePause,
                style: PixelButtonStyle.gold,
                child: const Text('Resume')),
            const SizedBox(height: 10),
            PixelButton(onPressed: onSave, child: const Text('Save Game')),
            const SizedBox(height: 10),
            PixelButton(onPressed: onMainMenu, child: const Text('Main Menu')),
            const SizedBox(height: 16),
            const SoundToggles(),
            if (justSaved) ...[
              const SizedBox(height: 10),
              Text('Game saved',
                  style: pixelText(14, color: UiColors.good),
                  textAlign: TextAlign.center),
            ],
          ],
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
              style: pixelText(32,
                  bold: true,
                  color: UiColors.cream.withValues(alpha: alpha),
                  shadow: false),
            ),
          ),
        ),
      ),
    );
  }
}
