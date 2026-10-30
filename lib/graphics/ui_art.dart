import 'dart:math';

import 'object_art.dart';
import 'palette.dart';
import 'pixel_canvas.dart';

/// Pixel art for the interface: icons, window frames and buttons.
class UiArt {
  static const Map<String, int> _ink = {
    'o': 0xFF2A1E18,
    'w': 0xFFFFFFFF,
    'W': 0xFFDCDCE0,
    'g': 0xFFA0A0AA,
    'G': 0xFF62626C,
    'r': 0xFFD8333A,
    'R': 0xFFFF7A70,
    'm': 0xFF8A1A22,
    'y': 0xFFFFD54F,
    'Y': 0xFFFFF2A8,
    'k': 0xFFE09A2A,
    'n': 0xFFEF7D1A,
    'N': 0xFFFFB24D,
    'b': 0xFF966037,
    'B': 0xFFC98F5A,
    'd': 0xFF5E3920,
    'l': 0xFF4FA243,
    'L': 0xFF8BD06A,
    'e': 0xFF29632E,
    'u': 0xFF3371B5,
    'U': 0xFF6BA6DD,
    'v': 0xFF1F4E8C,
    'c': 0xFFF3E3C3,
    'C': 0xFFD9C29A,
    // Steel, rust and crystal, for the things from the mine.
    's': 0xFFB8D4F0,
    'S': 0xFF6E96C4,
    'x': 0xFF3E5A84,
    't': 0xFFB5602A,
    'T': 0xFFE08A48,
    'p': 0xFF5A3AA8,
    'P': 0xFF9A7AF0,
    'q': 0xFFE0D4FF,
  };

  /// Hand-drawn 12x12 icons.
  static const Map<String, List<String>> _drawn = {
    'heart': [
      '............',
      '..ooo..ooo..',
      '.oRRroorrro.',
      'oRRrrrrrrrro',
      'oRrrrrrrrrro',
      'orrrrrrrrrmo',
      '.orrrrrrrmo.',
      '..orrrrrmo..',
      '...orrrmo...',
      '....ormo....',
      '.....oo.....',
      '............',
    ],
    'food': [
      '............',
      '.....oooo...',
      '....oNNnno..',
      '...oNnnnnko.',
      '...onnnnnko.',
      '...onnnnkko.',
      '....onkkko..',
      '...owoooo...',
      '..owWo......',
      '.owWo.......',
      'oWwo........',
      'ooo.........',
    ],
    'energy': [
      '............',
      '......oooo..',
      '.....oYyyo..',
      '....oYyyo...',
      '...oYyyoooo.',
      '..oYyyyyyyo.',
      '..ooooyyyo..',
      '.....oyyo...',
      '....oyyo....',
      '....oyo.....',
      '...oyo......',
      '...oo.......',
    ],
    'star': [
      '............',
      '.....oo.....',
      '....oyyo....',
      '....oyyo....',
      'oooooYyooooo',
      'oyYYyyyyyyyo',
      '.oyyyyyyyyo.',
      '..oyyyyyyo..',
      '..oyyooyyo..',
      '.oyyo..oyyo.',
      '.ooo....ooo.',
      '............',
    ],
    'sun': [
      '............',
      '.....yy.....',
      '..y..yy..y..',
      '...oooooo...',
      '..oYYyyyyo..',
      'yyoYyyyyyoyy',
      'yyoyyyyyyoyy',
      '..oyyyyyko..',
      '...oooooo...',
      '..y..yy..y..',
      '.....yy.....',
      '............',
    ],
    'moon': [
      '............',
      '....oooo....',
      '...oYYYo....',
      '..oYYYo.....',
      '..oYYo......',
      '.oYYYo......',
      '.oYYYo......',
      '.oYYYYo.....',
      '..oYYYYoooo.',
      '..okYYYYYYo.',
      '...ookkkoo..',
      '.....ooo....',
    ],
    'bag': [
      '............',
      '....oooo....',
      '...od..do...',
      '..oooooooo..',
      '.obBBBBBBbo.',
      '.obbbbbbbbo.',
      '.oddoyyoddo.',
      '.obbbyybbbo.',
      '.obbbbbbbbo.',
      '.obbbbbbbbo.',
      '.oddddddddo.',
      '..oooooooo..',
    ],
    'hammer': [
      '............',
      '..oooooo....',
      '.oWWWWWgo...',
      '.oWggggGoo..',
      '.oGGGGGGGo..',
      '..oooobooo..',
      '.....obo....',
      '....obo.....',
      '...obo......',
      '..obo.......',
      '.obo........',
      '.oo.........',
    ],
    'map': [
      '............',
      '.oooooooooo.',
      '.occccccCco.',
      '.ocllcccCco.',
      '.olllccuuco.',
      '.oclccuUcco.',
      '.occccuccCo.',
      '.ocrcrcucco.',
      '.occrcccuCo.',
      '.ocrcrccCCo.',
      '.oooooooooo.',
      '............',
    ],
    'pause': [
      '............',
      '............',
      '..ooo..ooo..',
      '..oWo..oWo..',
      '..owo..owo..',
      '..owo..owo..',
      '..owo..owo..',
      '..owo..owo..',
      '..owo..owo..',
      '..ooo..ooo..',
      '............',
      '............',
    ],
    'flag': [
      '............',
      '.oo.........',
      '.odoooooo...',
      '.odRRrrrro..',
      '.odrrrrrro..',
      '.odrrrrmmo..',
      '.odoooooo...',
      '.odo........',
      '.odo........',
      '.odo........',
      '.odo........',
      '.ooo........',
    ],
    'wood': [
      '............',
      '............',
      '............',
      '.oooooooooo.',
      'obBBBBBBoBBo',
      'obbbbbbboBdo',
      'odbdbdbdoBdo',
      'obbbbbbboBBo',
      'odddddddoBBo',
      '.oooooooooo.',
      '............',
      '............',
    ],
    'talk': [
      '............',
      '..oooooooo..',
      '.owwwwwwwwo.',
      'owWWwwwwwwwo',
      'owwwwwwwwwwo',
      'owoowoowoowo',
      'owwwwwwwwwWo',
      '.owwwwwwwWo.',
      '..ooowwoooo.',
      '....owo.....',
      '....oo......',
      '............',
    ],
    'axe': [
      '............',
      '.......oooo.',
      '......oWWWgo',
      '.....oWWggGo',
      '....oboWgGGo',
      '...obbooGGo.',
      '..obbo..oo..',
      '.obbo.......',
      'obbo........',
      'obo.........',
      'oo..........',
      '............',
    ],
    'pickaxe': [
      '............',
      '..oooooooo..',
      '.oWWWggggGo.',
      'oWWoobboogGo',
      'oWo.obbo.oGo',
      'oo..obbo..oo',
      '....obbo....',
      '....obbo....',
      '....obbo....',
      '....obbo....',
      '....oooo....',
      '............',
    ],
    'rod': [
      '..........oo',
      '.........obo',
      '........obbo',
      '.......obbow',
      '......obbo.w',
      '.....obbo..w',
      '....obbo...w',
      '...obbo....w',
      '..oGbo....oo',
      '.oGGGo...oro',
      '.oGGo....oro',
      '..oo......o.',
    ],
    'can': [
      '............',
      '..oooo......',
      '.o....o.....',
      '.oooooooo..o',
      'oUUuuuuuuooU',
      'oUuuuuuuuuoo',
      'ouuuuuuuuuo.',
      'ouuuuuuuuvo.',
      'ouuuuuuuuvo.',
      'ouuuuuuuuvo.',
      'ovvvvvvvvvo.',
      '.ooooooooo..',
    ],
    'sword': [
      '............',
      '.........oo.',
      '........oBo.',
      '.......oBbo.',
      '......oBbo..',
      '.....oBbo...',
      '..o.oBbo....',
      '..oobbo.....',
      '...odo......',
      '..odooo.....',
      '.odo........',
      '.oo.........',
    ],
    'search': [
      '............',
      '...oooo.....',
      '..oUUUUo....',
      '.oUwUUUUo...',
      '.oUUUUUUo...',
      '.oUUUUUUo...',
      '.oUUUUUUo...',
      '..oUUUUoo...',
      '...ooooboo..',
      '.......obbo.',
      '........obbo',
      '.........oo.',
    ],
    'look': [
      '............',
      '............',
      '....oooo....',
      '..oowwwwoo..',
      '.owwwoowwwo.',
      'owwwouuowwwo',
      'owwwouvowwwo',
      '.owwwoowwwo.',
      '..oowwwwoo..',
      '....oooo....',
      '............',
      '............',
    ],
    'hourglass': [
      '............',
      '.oooooooooo.',
      '..obbbbbbo..',
      '..oyyyyyyo..',
      '...oyyyyo...',
      '....oyyo....',
      '....oyyo....',
      '...oyyyyo...',
      '..oyyyyyyo..',
      '..obbbbbbo..',
      '.oooooooooo.',
      '............',
    ],
    'hand': [
      '............',
      '....oo......',
      '...oWWo.....',
      '...oWwo.....',
      '...oWwooo...',
      '.oooWwoWwoo.',
      'oWWoWwoWwoWo',
      'oWwwwwwwwwwo',
      '.oWwwwwwwwwo',
      '..owwwwwwwo.',
      '...owwwwwo..',
      '....ooooo...',
    ],
    'fish': [
      '............',
      '............',
      '..ooooo...oo',
      '.oUUUUUo.oUo',
      'oUwoUUUUooUo',
      'oUUUUUUUuUUo',
      'ouuuuuuuuUUo',
      'ouuuuuuuooUo',
      '.ovvvvvvo.oo',
      '..ooooooo...',
      '............',
      '............',
    ],
    'cooked_fish': [
      '............',
      '............',
      '..ooooo...oo',
      '.oNNNNNo.oNo',
      'oNwoNdNNooNo',
      'oNNNdNNdnNNo',
      'onnndnndnNNo',
      'onnnnnnnooNo',
      '.okkkkkko.oo',
      '..ooooooo...',
      '............',
      '............',
    ],
    'carrot': [
      '........oo..',
      '......oollo.',
      '.....olLlo..',
      '....oonnoo..',
      '...onNnnko..',
      '...oNnnnko..',
      '..onNnnko...',
      '..oNnnnko...',
      '.onnnnko....',
      '.onnnko.....',
      '.onko.......',
      '..o.........',
    ],
    'music': [
      '............',
      '....ooooooo.',
      '....oyyyyyyo',
      '....oyooooyo',
      '....oyo..oyo',
      '....oyo..oyo',
      '....oyo..oyo',
      '..oooyo.ooyo',
      '.oyyyyo.oyyo',
      '.oyyyyooyyyo',
      '..oooo.oooo.',
      '............',
    ],
    'speaker': [
      '............',
      '.....oo.....',
      '....owo..o..',
      '...owwo...o.',
      'ooowwwo.o..o',
      'owwwwwo..o.o',
      'owwwwwo..o.o',
      'ooowwwo.o..o',
      '...owwo...o.',
      '....owo..o..',
      '.....oo.....',
      '............',
    ],
    'resin': [
      '............',
      '.....oo.....',
      '....oYyo....',
      '....oyko....',
      '...oYykno...',
      '...oyykno...',
      '..oYykknno..',
      '..oykkknno..',
      '..okknnnno..',
      '...oknnno...',
      '....oooo....',
      '............',
    ],
    'torch': [
      '.....oo.....',
      '....oyyo....',
      '...oyYYyo...',
      '...onyYyo...',
      '...onnyno...',
      '....onno....',
      '....oCCo....',
      '....oCco....',
      '....obdo....',
      '....obdo....',
      '....obdo....',
      '....oooo....',
    ],
    'lantern': [
      '....oooo....',
      '...o....o...',
      '..oxxxxxxo..',
      '..oxqqqqxo..',
      '..oxqPPqxo..',
      '..oxqPPqxo..',
      '..oxqqqqxo..',
      '..oxPqqPxo..',
      '..oxxxxxxo..',
      '...oxxxxo...',
      '....oooo....',
      '............',
    ],
    'iron_ore': [
      '............',
      '............',
      '....oooo....',
      '..oogWggoo..',
      '.ogWgTtggGo.',
      '.oggtTggtGo.',
      'ogTtgggTtgGo',
      'oggggtggggGo',
      '.oGgTtggGGo.',
      '..ooGGGGoo..',
      '....oooo....',
      '............',
    ],
    'ingot': [
      '............',
      '............',
      '............',
      '...oooooo...',
      '..osssssSo..',
      '.osWssssSSo.',
      'oSSSSSSSSxxo',
      'oxxxxxxxxxxo',
      'oooooooooooo',
      '............',
      '............',
      '............',
    ],
    'crystal': [
      '............',
      '.....oo.....',
      '....oqPo....',
      '...oqPPpo...',
      '...oqPPpo...',
      '..oqqPPppo..',
      '..oqPPPppo..',
      '..oPPPPppo..',
      '...oPPppo...',
      '....oPpo....',
      '.....oo.....',
      '............',
    ],
    'iron_axe': [
      '............',
      '.......oooo.',
      '......osssSo',
      '.....ossSSxo',
      '....obosSxxo',
      '...obbooxxo.',
      '..obbo..oo..',
      '.obdo.......',
      'obdo........',
      'odo.........',
      'oo..........',
      '............',
    ],
    'iron_pickaxe': [
      '............',
      '..oooooooo..',
      '.osssSSSSxo.',
      'ossoobboSSxo',
      'oso.obbo.oxo',
      'oo..obbo..oo',
      '....obdo....',
      '....obdo....',
      '....obdo....',
      '....obdo....',
      '....oooo....',
      '............',
    ],
    'ladder': [
      '..oo....oo..',
      '..obo..obo..',
      '..oboooobo..',
      '..obBBBBbo..',
      '..oboooobo..',
      '..obo..obo..',
      '..oboooobo..',
      '..obBBBBbo..',
      '..oboooobo..',
      '..obo..obo..',
      '..obo..obo..',
      '..ooo..ooo..',
    ],
    'enter': [
      '............',
      '...oooooo...',
      '..oGggggGo..',
      '.oGgoooogGo.',
      '.ogooyyoogo.',
      '.ogooyyoogo.',
      '.ogyyyyyygo.',
      '.ogoyyyyogo.',
      '.ogooyyoogo.',
      '.ogoooooogo.',
      '.ooo....ooo.',
      '............',
    ],
    'arrow': [
      '......o.....',
      '......oo....',
      '......oyo...',
      'oooooooyyo..',
      'oYYYYYYyyyo.',
      'oyyyyyyyyyyo',
      'okkkkkkkkko.',
      'oooooookko..',
      '......oko...',
      '......oo....',
      '......o.....',
      '............',
    ],
  };

  static PixelCanvas icon(String name) => spriteFromRows(_drawn[name]!, _ink);

  static Iterable<String> get drawnIcons => _drawn.keys;

  // ---------------------------------------------------------------------------
  // Item icons built from shapes.

  static PixelCanvas stone() {
    final c = PixelCanvas(12, 12);
    c.shadedEllipse(6.5, 7, 4.6, 3.6, Palette.rock);
    c.shadedEllipse(4, 7.6, 2.6, 2.4, Palette.rock);
    c.set(7, 5, Palette.rock[0]);
    c.set(8, 6, Palette.rock[0]);
    c.outline(Palette.rockOutline);
    return c;
  }

  static PixelCanvas sticks() {
    final c = PixelCanvas(12, 12);
    const wood = Palette.wood;
    c.line(2, 10, 9, 3, wood[3]);
    c.line(3, 10, 10, 3, wood[1]);
    c.line(2, 3, 9, 10, wood[4]);
    c.line(2, 4, 8, 10, wood[2]);
    c.outline(Palette.outline);
    return c;
  }

  static PixelCanvas seeds() {
    final c = PixelCanvas(12, 12);
    const pouch = [0xFFA08458, 0xFFC4A774, 0xFFDCC290, 0xFFF0DCB0];
    c.shadedEllipse(5.5, 7.5, 4, 3.4, pouch);
    c.rect(4, 3, 3, 2, pouch[1]);
    c.rect(4, 4, 3, 1, 0xFF8A3A2A);
    c.outline(Palette.outline);
    for (final (x, y) in const [(9, 9), (10, 10), (8, 10)]) {
      c.set(x, y, 0xFFE8D08A);
    }
    return c;
  }

  static PixelCanvas berries() {
    final c = PixelCanvas(12, 12);
    for (final (x, y) in const [(4.0, 7.5), (8.0, 7.5), (6.0, 4.5)]) {
      c.shadedEllipse(x, y, 2.4, 2.3, [Palette.berry[0], Palette.berry[1], Palette.berry[1], Palette.berry[2]]);
    }
    c.rect(6, 1, 1, 2, Palette.grass[1]);
    c.rect(7, 1, 2, 1, Palette.grass[3]);
    c.outline(Palette.outline);
    return c;
  }

  static PixelCanvas apple() {
    final c = PixelCanvas(12, 12);
    c.shadedEllipse(6, 7, 4.3, 4, [Palette.apple[0], Palette.apple[1], Palette.apple[1], Palette.apple[2]]);
    c.rect(6, 1, 1, 3, Palette.bark[1]);
    c.rect(7, 1, 2, 1, Palette.grass[3]);
    c.set(8, 2, Palette.grass[2]);
    c.outline(Palette.outline);
    return c;
  }

  // ---------------------------------------------------------------------------
  // Frames, sliced into nine so their borders stay sharp at any size.

  /// A frame [size] pixels square. [rings] are the colours from the outside
  /// in, each as (top/left, bottom/right); everything inside is [fill].
  static PixelCanvas frame(List<(int, int)> rings, int fill, {int size = 16, Random? grain}) {
    final c = PixelCanvas(size, size)..fill(fill);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final d = min(min(x, y), min(size - 1 - x, size - 1 - y));
        if (d >= rings.length) continue;
        final lit = x == d || y == d;
        final ring = rings[d];
        c.set(x, y, lit && !(x == size - 1 - d || y == size - 1 - d) ? ring.$1 : ring.$2);
      }
    }
    // Rounded corners.
    for (final (x, y) in [(0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)]) {
      c.set(x, y, 0);
    }
    for (final (x, y) in [(1, 1), (size - 2, 1), (1, size - 2), (size - 2, size - 2)]) {
      c.set(x, y, rings.first.$2);
    }
    if (grain != null && rings.length > 3) {
      for (var i = 0; i < 10; i++) {
        final x = grain.nextInt(size);
        final y = grain.nextInt(size);
        final d = min(min(x, y), min(size - 1 - x, size - 1 - y));
        if (d == 2 || d == 3) c.set(x, y, Palette.wood[1]);
      }
    }
    return c;
  }

  static const _dark = 0xFF1E140E;

  /// Dark wooden window frame.
  static PixelCanvas woodFrame() => frame(
        [
          (_dark, _dark),
          (Palette.wood[4], Palette.wood[1]),
          (Palette.wood[3], Palette.wood[2]),
          (Palette.wood[2], Palette.wood[2]),
          (Palette.wood[0], Palette.wood[3]),
        ],
        0xFF33241A,
        grain: Random(3001),
      );

  /// Wooden frame around a sheet of parchment.
  static PixelCanvas parchmentFrame() => frame(
        [
          (_dark, _dark),
          (Palette.wood[4], Palette.wood[1]),
          (Palette.wood[3], Palette.wood[2]),
          (Palette.wood[1], Palette.wood[1]),
          (0xFFE5CFA5, 0xFFF3E3C3),
        ],
        0xFFF3E3C3,
      );

  /// A small dark plate for HUD panels and labels.
  static PixelCanvas plateFrame() => frame(
        [
          (_dark, _dark),
          (Palette.wood[3], Palette.wood[0]),
          (0xFF4A3424, 0xFF2A1D14),
        ],
        0xE0362619,
        size: 10,
      );

  /// A small paper note.
  static PixelCanvas noteFrame() => frame(
        [
          (0xFF5E3920, 0xFF5E3920),
          (0xFFFBF0D8, 0xFFC9AE80),
          (0xFFF3E3C3, 0xFFE5CFA5),
        ],
        0xFFF3E3C3,
        size: 10,
      );

  /// A sunken inventory slot.
  static PixelCanvas slotFrame({bool highlight = false}) => frame(
        [
          (highlight ? 0xFFFFD54F : _dark, highlight ? 0xFFFFD54F : _dark),
          (0xFF140D08, 0xFF6E4A30),
          (0xFF22170F, 0xFF3A2819),
        ],
        0xFF2E2016,
        size: 10,
      );

  static PixelCanvas barFrame() => frame(
        [
          (_dark, _dark),
          (0xFF140D08, 0xFF140D08),
        ],
        0xFF2A1D14,
        size: 6,
      );

  /// A raised button in [ramp] (dark to light); pressed, it sinks in.
  static PixelCanvas button(List<int> ramp, {required bool pressed}) {
    const size = 16;
    final c = PixelCanvas(size, size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        int color;
        if (x == 0 || y == 0 || x == size - 1 || y == size - 1) {
          color = _dark;
        } else if (pressed) {
          color = y <= 2 ? ramp[0] : ramp[2];
        } else if (y >= size - 3) {
          color = ramp[0];
        } else if (y == 1 || x == 1) {
          color = ramp[4];
        } else if (x == size - 2) {
          color = ramp[2];
        } else {
          color = ramp[3];
        }
        c.set(x, y, color);
      }
    }
    for (final (x, y) in [(0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)]) {
      c.set(x, y, 0);
    }
    for (final (x, y) in [(1, 1), (size - 2, 1), (1, size - 2), (size - 2, size - 2)]) {
      c.set(x, y, _dark);
    }
    return c;
  }

  static const woodRamp = [0xFF5E3920, 0xFF7A4B2A, 0xFF966037, 0xFFB07646, 0xFFD39C66];
  static const goldRamp = [0xFF8A5A10, 0xFFB57A1C, 0xFFE0A030, 0xFFF2BE4A, 0xFFFFE08A];
  static const stoneRamp = [0xFF44444C, 0xFF5C5C66, 0xFF74747E, 0xFF8C8C96, 0xFFA8A8B2];

  /// The big round action button.
  static PixelCanvas roundButton(List<int> ramp, {required bool pressed}) {
    const size = 26;
    final c = PixelCanvas(size, size);
    // The lip underneath shows when the button is up.
    if (!pressed) c.ellipse(13, 14.5, 12, 11.5, ramp[0]);
    c.shadedEllipse(13, pressed ? 14 : 12.5, 12, 11.5, [ramp[1], ramp[2], ramp[3], ramp[3], ramp[4]]);
    c.outline(_dark);
    return c;
  }

  static PixelCanvas joystickBase() {
    const size = 40;
    final c = PixelCanvas(size, size);
    c.shadedEllipse(20, 20, 19, 19, Palette.rock);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = (x + 0.5 - 20) / 14;
        final dy = (y + 0.5 - 20) / 14;
        if (dx * dx + dy * dy <= 1) c.set(x, y, 0x66140D08);
      }
    }
    c.outline(_dark);
    return c;
  }

  static PixelCanvas joystickKnob() {
    final c = PixelCanvas(16, 16);
    c.shadedEllipse(8, 8, 7, 7, const [0xFF9C8460, 0xFFC8B28C, 0xFFE0CDA8, 0xFFF3E3C3, 0xFFFFF8E8]);
    c.outline(_dark);
    return c;
  }

  /// A speech bubble with "!" (a task to pick up) or "?" (one to hand in).
  static PixelCanvas questBubble({required bool question}) {
    const exclamation = [
      '.cccccccccc.',
      'cccccccccccc',
      'cccccrrccccc',
      'cccccrrccccc',
      'cccccrrccccc',
      'cccccrrccccc',
      'cccccrrccccc',
      'cccccrrccccc',
      'cccccccccccc',
      'cccccrrccccc',
      'cccccrrccccc',
      '.cccccccccc.',
      '....ccc.....',
      '.....c......',
    ];
    const questionMark = [
      '.cccccccccc.',
      'cccccccccccc',
      'ccccrrrrcccc',
      'cccrrccrrccc',
      'cccccccrrccc',
      'ccccccrrcccc',
      'cccccrrccccc',
      'cccccrrccccc',
      'cccccccccccc',
      'cccccrrccccc',
      'cccccrrccccc',
      '.cccccccccc.',
      '....ccc.....',
      '.....c......',
    ];
    final c = PixelCanvas(14, 16);
    c.stamp(spriteFromRows(question ? questionMark : exclamation, const {'c': 0xFFFFF2C8, 'r': 0xFFD8333A}), 1, 1);
    c.outline(_dark);
    return c;
  }

  // ---------------------------------------------------------------------------
  // Title screen

  /// A sunset over the valley, 108 x 234 pixels.
  static PixelCanvas titleScene() {
    const w = 108, h = 234;
    final r = Random(4242);
    final c = PixelCanvas(w, h);

    // Sky in dithered bands.
    const sky = [0xFF1F2547, 0xFF2B3A67, 0xFF46457A, 0xFF6A5288, 0xFF8E6C9E, 0xFFC27E95, 0xFFE89A7E, 0xFFF4B66A];
    const bandHeight = 18;
    for (var y = 0; y < 150; y++) {
      final band = min(sky.length - 1, y ~/ bandHeight);
      final next = min(sky.length - 1, band + 1);
      final t = (y % bandHeight) / bandHeight;
      for (var x = 0; x < w; x++) {
        final dither = t > 0.66 && (x + y).isEven || t > 0.85;
        c.set(x, y, dither ? sky[next] : sky[band]);
      }
    }
    for (var i = 0; i < 26; i++) {
      c.set(r.nextInt(w), r.nextInt(60), i % 5 == 0 ? 0xFFFFF2A8 : 0xFFE8E8FF);
    }

    // The sun, low over the hills.
    c.ellipse(78, 120, 15, 15, 0xFFFFC866);
    c.ellipse(78, 120, 12, 12, 0xFFFFE08A);
    c.ellipse(76, 117, 6, 6, 0xFFFFF2C0);

    // Far mountains.
    for (var x = 0; x < w; x++) {
      final peak = 112 + (sin(x / 9) * 9 + sin(x / 4.3 + 1) * 4).round();
      for (var y = peak; y < 150; y++) {
        c.set(x, y, y == peak ? 0xFF8A6A9A : 0xFF5E4A7A);
      }
    }

    void hill(int base, double amplitude, double period, double phase, List<int> ramp) {
      for (var x = 0; x < w; x++) {
        final top = base + (sin(x / period + phase) * amplitude).round();
        for (var y = top; y < h; y++) {
          c.set(x, y, y == top ? ramp[3] : (y < top + 3 ? ramp[2] : ramp[1]));
        }
      }
    }

    hill(138, 6, 14, 0.4, const [0xFF2E4A3A, 0xFF3E6248, 0xFF4E7A56, 0xFF6A9468]);
    hill(152, 7, 11, 2.0, Palette.forest);

    // A winding river through the valley.
    for (var y = 150; y < h; y++) {
      final cx = 40 + (sin(y / 13) * 10).round() + (y - 150) ~/ 5;
      final half = 2 + (y - 150) ~/ 22;
      for (var x = cx - half; x <= cx + half; x++) {
        c.set(x, y, x == cx - half ? Palette.water[4] : Palette.water[2]);
      }
      if (y % 6 == 0) c.set(cx, y, Palette.foam);
    }

    hill(178, 5, 16, 4.0, Palette.grass);

    // A cottage on the near hill.
    const hx = 62, hy = 162;
    c.rect(hx, hy + 6, 14, 8, Palette.wood[3]);
    c.rect(hx + 6, hy + 9, 3, 5, Palette.wood[0]);
    c.rect(hx + 2, hy + 8, 2, 2, 0xFFFFD27A);
    c.rect(hx + 10, hy + 8, 2, 2, 0xFFFFD27A);
    for (var i = 0; i < 7; i++) {
      c.rect(hx - 1 + i, hy + 6 - i, 16 - i * 2, 1, Palette.roof[2 + (i % 2)]);
    }
    c.rect(hx + 10, hy - 2, 2, 4, Palette.stone[2]);

    // Trees and flowers in front.
    c.stamp(ObjectArt.oak(Random(5)), 2, 172);
    c.stamp(ObjectArt.pine(Random(6)), 84, 166);
    c.stamp(ObjectArt.oak(Random(7)), 88, 196);
    c.stamp(ObjectArt.pine(Random(8)), 14, 198);
    for (var i = 0; i < 30; i++) {
      final x = r.nextInt(w);
      final y = 200 + r.nextInt(34);
      if (c.get(x, y) == Palette.grass[1]) {
        c.set(x, y, const [0xFFF5F5F5, 0xFFFFD54F, 0xFFF28AB2][i % 3]);
      }
    }
    return c;
  }
}
