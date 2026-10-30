import 'dart:ui' as ui;

import 'pixel_canvas.dart';
import 'textures.dart';
import 'ui_art.dart';

/// The kinds of nine-sliced frames, with the width of their border in pixels.
enum PixelFrame {
  wood(5),
  parchment(5),
  plate(3),
  note(3),
  slot(3),
  highlightSlot(3),
  bar(2);

  final int border;

  const PixelFrame(this.border);
}

enum PixelButtonStyle { wood, gold, stone }

/// Images for the interface, generated once on first use.
class UiTextures {
  static UiTextures? _instance;
  static UiTextures get instance => _instance ??= UiTextures._();

  final Map<String, ui.Image> _icons = {};
  final Map<PixelFrame, ui.Image> _frames = {};
  final Map<(PixelButtonStyle, bool), ui.Image> _buttons = {};
  late final ui.Image roundActive, roundActivePressed, roundIdle, roundIdlePressed;
  late final ui.Image joystickBase, joystickKnob, exclamation, question, titleScene;

  UiTextures._() {
    for (final name in UiArt.drawnIcons) {
      _icons[name] = UiArt.icon(name).toImage();
    }
    final made = <String, PixelCanvas>{
      'stone': UiArt.stone(),
      'sticks': UiArt.sticks(),
      'seeds': UiArt.seeds(),
      'berries': UiArt.berries(),
      'apple': UiArt.apple(),
    };
    for (final e in made.entries) {
      _icons[e.key] = e.value.toImage();
    }

    _frames[PixelFrame.wood] = UiArt.woodFrame().toImage();
    _frames[PixelFrame.parchment] = UiArt.parchmentFrame().toImage();
    _frames[PixelFrame.plate] = UiArt.plateFrame().toImage();
    _frames[PixelFrame.note] = UiArt.noteFrame().toImage();
    _frames[PixelFrame.slot] = UiArt.slotFrame().toImage();
    _frames[PixelFrame.highlightSlot] = UiArt.slotFrame(highlight: true).toImage();
    _frames[PixelFrame.bar] = UiArt.barFrame().toImage();

    const ramps = {
      PixelButtonStyle.wood: UiArt.woodRamp,
      PixelButtonStyle.gold: UiArt.goldRamp,
      PixelButtonStyle.stone: UiArt.stoneRamp,
    };
    for (final e in ramps.entries) {
      for (final pressed in [false, true]) {
        _buttons[(e.key, pressed)] = UiArt.button(e.value, pressed: pressed).toImage();
      }
    }
    roundActive = UiArt.roundButton(UiArt.goldRamp, pressed: false).toImage();
    roundActivePressed = UiArt.roundButton(UiArt.goldRamp, pressed: true).toImage();
    roundIdle = UiArt.roundButton(UiArt.stoneRamp, pressed: false).toImage();
    roundIdlePressed = UiArt.roundButton(UiArt.stoneRamp, pressed: true).toImage();
    joystickBase = UiArt.joystickBase().toImage();
    joystickKnob = UiArt.joystickKnob().toImage();
    exclamation = UiArt.questBubble(question: false).toImage();
    question = UiArt.questBubble(question: true).toImage();
    titleScene = UiArt.titleScene().toImage();
  }

  ui.Image frame(PixelFrame frame) => _frames[frame]!;

  ui.Image button(PixelButtonStyle style, {required bool pressed}) => _buttons[(style, pressed)]!;

  /// An icon by name; world sprites stand in for a few of them.
  ui.Image icon(String name) {
    final drawn = _icons[name];
    if (drawn != null) return drawn;
    final world = Textures.instance;
    return switch (name) {
      'campfire' => world.fire.first,
      'bed' => world.bed,
      'rabbit' => world.rabbit.first,
      _ => _icons['hand']!,
    };
  }

  /// The icon for an inventory item.
  static String itemIcon(String item) => switch (item) {
        'wood' => 'wood',
        'stone' => 'stone',
        'stick' => 'sticks',
        'seeds' => 'seeds',
        'berry' => 'berries',
        'apple' => 'apple',
        'fish' => 'fish',
        'cooked_fish' => 'cooked_fish',
        'carrot' => 'carrot',
        'campfire' => 'campfire',
        'axe' => 'axe',
        'pickaxe' => 'pickaxe',
        'fishing_rod' => 'rod',
        'watering_can' => 'can',
        'wooden_sword' => 'sword',
        _ => 'bag',
      };

  /// The icon for what the action button will do.
  static String actionIcon(String? action) => switch (action) {
        'talk' => 'talk',
        'chop' => 'axe',
        'mine' => 'pickaxe',
        'pick' => 'berries',
        'pick_apple' => 'apple',
        'search' => 'search',
        'fish' => 'rod',
        'cook' => 'cooked_fish',
        'sleep' => 'bed',
        'plant' => 'seeds',
        'water' => 'can',
        'growing' => 'hourglass',
        'harvest' => 'carrot',
        'bridge_site' || 'cave' => 'look',
        'watch' => 'rabbit',
        _ => 'hand',
      };
}
