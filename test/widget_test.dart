import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:serene_valley/main.dart';
import 'package:serene_valley/models/game_state.dart';
import 'package:serene_valley/screens/game_screen.dart';
import 'package:serene_valley/screens/title_screen.dart';
import 'package:serene_valley/services/save_service.dart';
import 'package:serene_valley/widgets/pixel_ui.dart';

const phones = {
  'small phone': Size(720, 1280), // 360x640 dp
  'large phone': Size(1080, 2340), // ~393x851 dp
};

Future<void> usePhone(WidgetTester tester, Size physicalSize) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = physicalSize.width / (physicalSize.width > 1000 ? 393 : 360);
  addTearDown(tester.view.reset);
}

/// Lets a few frames of the game run; the game loop never settles.
Future<void> frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> startNewGame(WidgetTester tester, SaveService service) async {
  await tester.pumpWidget(SereneValleyApp(saveService: service));
  await tester.pump();
  await tester.tap(find.text('New game'));
  await frames(tester);
  expect(find.byType(GameScreen), findsOneWidget);
}

void main() {
  for (final phone in phones.entries) {
    testWidgets('a new game starts at the elder and menus open on a ${phone.key}', (tester) async {
      await usePhone(tester, phone.value);
      final storage = MemorySaveStorage();
      await startNewGame(tester, SaveService(storage: storage));
      expect(find.byType(Joystick), findsOneWidget);
      expect(storage.data, isNotNull, reason: 'a new game is saved right away');
      expect(find.text('Talk to Elder Rowan in the village'), findsOneWidget);

      // The action button talks to the elder, who offers the first quest.
      expect(find.text('Talk'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('action-button')));
      await frames(tester);
      expect(find.text('Elder Rowan'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await frames(tester);
      await tester.tap(find.text('Close'));
      await frames(tester);
      expect(find.text('Wood 0/10'), findsOneWidget);

      for (final label in ['Items', 'Craft', 'Map', 'Pause']) {
        await tester.tap(find.byTooltip(label));
        await frames(tester, 2);
        expect(tester.takeException(), isNull, reason: label);
        await tester.tap(find.widgetWithText(PixelButton, label == 'Pause' ? 'Resume' : 'Close'));
        await frames(tester, 2);
      }

      // Let pending message timers finish.
      await tester.pump(const Duration(seconds: 4));
    });
  }

  testWidgets('the main menu saves, and Continue brings the game back', (tester) async {
    await usePhone(tester, phones['large phone']!);
    final storage = MemorySaveStorage();
    final service = SaveService(storage: storage);
    await startNewGame(tester, service);

    await tester.tap(find.byTooltip('Pause'));
    await frames(tester, 2);
    await tester.tap(find.text('Main Menu'));
    // Wait for the page transition to finish.
    await frames(tester, 20);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(TitleScreen), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.textContaining('The Broken Bridge'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await frames(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('tapping Main Menu twice still lands on the title screen', (tester) async {
    await usePhone(tester, phones['large phone']!);
    final service = SaveService(storage: _SlowStorage());
    await startNewGame(tester, service);

    await tester.tap(find.byTooltip('Pause'));
    await frames(tester, 2);
    await tester.tap(find.text('Main Menu'));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.text('Main Menu'), warnIfMissed: false);
    await frames(tester, 20);
    expect(find.byType(TitleScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('the old mine shows its torchlight and its own map', (tester) async {
    await usePhone(tester, phones['large phone']!);
    final state = GameState(worldSeed: 3);
    state.world.mineOpen = true;
    state.player.addItem('torch', 2);
    state.player.position = state.world.mineEntrance! + const Offset(0.5, 1.5);
    final storage = MemorySaveStorage(jsonEncode(state.toJson()));
    await tester.pumpWidget(SereneValleyApp(saveService: SaveService(storage: storage)));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await frames(tester);
    expect(find.text('Enter'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('action-button')));
    await frames(tester, 30);
    expect(find.text('Climb'), findsOneWidget);
    expect(find.byTooltip('Torch'), findsOneWidget);

    await tester.tap(find.byTooltip('Map'));
    await frames(tester, 2);
    expect(find.text('Old Mine'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(PixelButton, 'Close'));
    await frames(tester, 2);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('an existing save offers Continue on the title screen', (tester) async {
    await usePhone(tester, phones['small phone']!);
    final state = GameState(worldSeed: 3)..questIndex = 2;
    final storage = MemorySaveStorage(jsonEncode(state.toJson()));

    await tester.pumpWidget(SereneValleyApp(saveService: SaveService(storage: storage)));
    await tester.pump();
    expect(find.textContaining('A Meal for Everyone'), findsOneWidget);

    // Starting over asks first.
    await tester.tap(find.text('New game'));
    await tester.pump();
    expect(find.text('Start a new game?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.byType(TitleScreen), findsOneWidget);
  });
}

/// Storage whose writes take a while, like a slow phone.
class _SlowStorage extends MemorySaveStorage {
  @override
  Future<void> write(String data) async {
    await Future.delayed(const Duration(milliseconds: 80));
    await super.write(data);
  }
}
