import '../models/npc.dart';
import 'palette.dart';
import 'pixel_canvas.dart';

/// Pixel-art characters and animals.
///
/// Characters are 16x17 pixels, drawn from templates where each letter is a
/// slot in the character's palette:
///   o outline   h/H/j hair or hat (base, light, dark)
///   s/S skin (base, shade)   r cheeks   e eyes   w beard, or chin shade
///   c/C/d shirt (base, light, dark)   p/P trousers   b shoes
class CharacterArt {
  static const _downTop = [
    '.....oooooo.....',
    '....ohhHHhho....',
    '...ohhHHhhhho...',
    '...ohhhhhhhho...',
    '...ojhhhhhhjo...',
    '...ojssssssjo...',
    '...ossessesso...',
    '...osrssssrso...',
    '....owwwwwwo....',
    '...ocCccccdco...',
    '...ocCccccdco...',
    '...osCccccdso...',
    '....oppppppo....',
  ];

  static const _upTop = [
    '.....oooooo.....',
    '....ohhHHhho....',
    '...ohhHHhhhho...',
    '...ohhhhhhhho...',
    '...ohhhhhhhho...',
    '...ohhhhhhhho...',
    '...ojhhhhhhjo...',
    '...ojjhhhhjjo...',
    '....oSSSSSSo....',
    '...ocCccccdco...',
    '...ocCccccdco...',
    '...osCccccdso...',
    '....oppppppo....',
  ];

  static const _sideTop = [
    '.....oooooo.....',
    '....ohhhHHho....',
    '...ohhhHHhhho...',
    '...ohhhhhhhho...',
    '...ohhhhhhhjo...',
    '...osshhhhhjo...',
    '...osesshhhjo...',
    '...osrsshhhjo...',
    '....owwSjjjo....',
    '....ocCccdco....',
    '....ocCccdco....',
    '....ocCsccdo....',
    '....oppppppo....',
  ];

  // Legs for standing and the two halves of a step, front or back view.
  static const _frontLegs = [
    ['....opPoopPo....', '....opPoopPo....', '....obboobbo....', '....oooooooo....'],
    ['....opPoopPo....', '....obboopPo....', '....ooooobbo....', '........oooo....'],
    ['....opPoopPo....', '....opPoobbo....', '....obbooooo....', '....oooo........'],
  ];

  // Legs in profile: together, then mid-stride.
  static const _sideLegs = [
    ['.....opPppo.....', '.....opPppo.....', '....obbbbbo.....', '....ooooooo.....'],
    ['....opPo.opPo...', '...opPo...opPo..', '..obbbo...obbo..', '..ooooo...oooo..'],
  ];

  /// All frames for [look]: down, up and left have stand + two step frames
  /// (left reuses its stride), right mirrors left.
  static Map<String, List<PixelCanvas>> character(CharacterLook look) {
    final palette = _palette(look);
    List<PixelCanvas> frames(List<String> top, List<List<String>> legs, List<int> order) => [
          for (final i in order) spriteFromRows([...top, ...legs[i]], palette),
        ];

    final left = frames(_sideTop, _sideLegs, const [0, 1, 1]);
    return {
      'down': frames(_downTop, _frontLegs, const [0, 1, 2]),
      'up': frames(_upTop, _frontLegs, const [0, 1, 2]),
      'left': left,
      'right': [for (final f in left) f.mirrored()],
    };
  }

  static Map<String, int> _palette(CharacterLook look) {
    final hair = look.hat.toARGB32();
    final skin = look.skin.toARGB32();
    final shirt = look.body.toARGB32();
    final trousers = look.legs.toARGB32();
    final beard = look.beard?.toARGB32();
    return {
      'o': Palette.outline,
      'h': hair,
      'H': lighten(hair, 0.3),
      'j': darken(hair, 0.3),
      's': skin,
      'S': darken(skin, 0.15),
      'r': mixColor(skin, 0xFFE0606A, 0.35),
      'e': Palette.outline,
      'w': beard ?? darken(skin, 0.15),
      'c': shirt,
      'C': lighten(shirt, 0.25),
      'd': darken(shirt, 0.3),
      'p': trousers,
      'P': darken(trousers, 0.3),
      'b': 0xFF4A2F1E,
    };
  }

  // ---------------------------------------------------------------------------
  // Animals, all facing right in 16x16 pixels.

  static PixelCanvas rabbit() {
    final c = PixelCanvas(16, 16);
    const fur = [0xFFA9A9B4, 0xFFC9C9D2, 0xFFE4E4EA, 0xFFF7F7FA];
    c.shadedEllipse(7, 11.5, 4.3, 3.2, fur);
    c.shadedEllipse(11, 9, 2.7, 2.4, fur);
    c.rect(10, 3, 1, 5, fur[2]);
    c.rect(12, 3, 1, 5, fur[1]);
    c.rect(10, 4, 1, 2, 0xFFE8A8B8);
    c.set(3, 10, fur[3]);
    c.outline(0xFF4A4A55);
    c.set(12, 8, Palette.outline);
    c.set(13, 9, 0xFFE07A8A);
    return c;
  }

  static PixelCanvas deer() {
    final c = PixelCanvas(16, 16);
    const coat = [0xFF6B3E1F, 0xFF8A522A, 0xFFA66A38, 0xFFC0844C];
    c.rect(4, 11, 1, 4, coat[0]);
    c.rect(6, 11, 1, 4, coat[1]);
    c.rect(9, 11, 1, 4, coat[0]);
    c.rect(11, 11, 1, 4, coat[1]);
    c.shadedEllipse(7.5, 9.5, 5, 2.6, coat);
    c.rect(10, 5, 2, 4, coat[2]);
    c.shadedEllipse(12, 4.5, 2.2, 1.7, coat);
    c.set(14, 5, coat[1]);
    c.set(2, 8, 0xFFF2E8D8);
    for (final (x, y) in const [(5, 8), (7, 8), (9, 9)]) {
      c.set(x, y, 0xFFE8D2B0);
    }
    c.outline(0xFF2E1A0E);
    // Antlers.
    const antler = 0xFF5A3A1E;
    c.line(11, 2, 10, 0, antler);
    c.line(13, 2, 14, 0, antler);
    c.set(9, 1, antler);
    c.set(15, 1, antler);
    c.set(12, 4, Palette.outline);
    return c;
  }

  static PixelCanvas bird() {
    final c = PixelCanvas(16, 16);
    const feathers = [0xFF1F4F9A, 0xFF2C67C2, 0xFF4A86E0, 0xFF7AAAF0];
    const head = [0xFF9A1E1E, 0xFFC83232, 0xFFE85A4A, 0xFFF58A7A];
    c.rect(3, 10, 3, 1, feathers[0]);
    c.shadedEllipse(8, 11, 3.2, 2.3, feathers);
    c.shadedEllipse(10.5, 8.8, 1.9, 1.8, head);
    c.rect(7, 13, 1, 2, 0xFFE0902A);
    c.rect(9, 13, 1, 2, 0xFFE0902A);
    c.outline(0xFF15233F);
    c.set(12, 9, 0xFFF0A030);
    c.set(13, 9, 0xFFF0A030);
    c.set(11, 8, Palette.outline);
    return c;
  }
}
