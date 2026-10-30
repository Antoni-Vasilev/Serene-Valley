import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:serene_valley/main.dart';
import 'package:serene_valley/models/game_state.dart';
import 'package:serene_valley/screens/game_screen.dart';

void main() {
  group('GameState', () {
    test('player spawns on a walkable tile', () {
      for (var seed = 0; seed < 20; seed++) {
        final state = GameState(worldSeed: seed);
        final p = state.player.position;
        expect(state.world.isWalkable(p.dx.floor(), p.dy.floor()), isTrue,
            reason: 'seed $seed');
      }
    });

    test('world object keys contain coordinates', () {
      final state = GameState(worldSeed: 1);
      final key = state.world.trees.keys.first;
      expect(key, matches(RegExp(r'^tree_\d+_\d+$')));
    });

    test('movement is scaled by elapsed time', () {
      final state = GameState(worldSeed: 3);
      final start = state.player.position;
      state.moveInput = const Offset(1, 0);
      state.update(0.1);
      final moved = (state.player.position - start).distance;
      // 4 tiles/second for 0.1s, or 0 if a wall is directly in the way.
      expect(moved, lessThanOrEqualTo(0.41));
    });

    test('stats drain slowly instead of once per frame', () {
      final state = GameState(worldSeed: 4);
      for (var i = 0; i < 60; i++) {
        state.update(1 / 60);
      }
      expect(state.player.hunger, greaterThan(99));
      expect(state.player.energy, greaterThan(99));
      expect(state.player.health, state.player.maxHealth);
    });

    test('crafting with missing ingredients does not throw', () {
      final state = GameState(worldSeed: 5);
      expect(() => state.craftItem('wooden_sword'), returnsNormally);
      expect(() => state.craftItem('fishing_rod'), returnsNormally);
      expect(() => state.selectTool('wooden_sword'), returnsNormally);
    });

    test('crafting consumes ingredients', () {
      final state = GameState(worldSeed: 6);
      state.player.addItem('wood', 3);
      state.craftItem('stick');
      state.craftItem('stick');
      state.craftItem('fishing_rod');
      expect(state.player.count('wood'), 0);
      expect(state.player.count('stick'), 0);
      expect(state.player.count('fishing_rod'), 2);
    });
  });

  const phones = {
    'small phone': Size(720, 1280), // 360x640 dp
    'large phone': Size(1080, 2340), // ~393x851 dp
  };
  for (final phone in phones.entries) {
    testWidgets('game runs on a ${phone.key} and menus open', (tester) async {
      await _playThroughMenus(tester, phone.value);
    });
  }
}

Future<void> _playThroughMenus(WidgetTester tester, Size physicalSize) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio =
      physicalSize.width / (physicalSize.width > 1000 ? 393 : 360);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SereneValleyApp());
  await tester.pump(const Duration(milliseconds: 100));

  expect(find.byType(GameScreen), findsOneWidget);
  expect(find.byType(Joystick), findsOneWidget);
  expect(tester.takeException(), isNull);

  for (final label in ['Items', 'Craft', 'Map', 'Pause']) {
    await tester.tap(find.byTooltip(label));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull, reason: label);
    // Every menu has a button to close it.
    await tester.tap(find.widgetWithText(
        ElevatedButton, label == 'Pause' ? 'Resume' : 'Close'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Let pending action-message timers finish.
  await tester.pump(const Duration(seconds: 3));
}
