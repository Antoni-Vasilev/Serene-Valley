import 'dart:math';
import 'dart:ui' as ui;

import '../models/npc.dart';
import 'character_art.dart';
import 'object_art.dart';
import 'palette.dart';
import 'pixel_canvas.dart';
import 'terrain_art.dart';

/// Every texture in the game, generated once on first use.
///
/// Images are 16 pixels per tile. Sides of a tile are numbered clockwise:
/// 0 = top, 1 = right, 2 = bottom, 3 = left.
class Textures {
  static Textures? _instance;
  static Textures get instance => _instance ??= Textures._();

  static const int variants = 4;

  // Terrain, keyed by tile type ('farmland_wet' for watered soil).
  final Map<String, List<ui.Image>> tiles = {};
  late final List<List<ui.Image>> water; // [variant][frame]
  late final List<List<ui.Image>> shore; // [side][frame]
  late final List<ui.Image> shoreCorner; // [corner], clockwise from top-left
  late final List<ui.Image> landEdge; // [side]
  late final Map<String, List<List<ui.Image>>> fringe; // 'grass' or 'forest' -> [side][variant]
  late final ui.Image cliffFace, cliffTop, cliffLeft, cliffRight, cliffShadow;
  late final ui.Image railTop, railBottom, brokenPosts, fencePost;
  late final List<ui.Image> fenceRails; // [side]

  // Things in the world.
  late final List<ui.Image> oaks, pines, appleTrees, bareAppleTrees, rocks, bushes, bareBushes;
  late final List<ui.Image> flowers, tallGrass, crops, fire;
  late final ui.Image cave, coldFirePit, bed, bracket, shadowSmall, shadowMedium, shadowLarge;
  late final ui.Image wall, window, litWindow, door, openDoor;
  final Map<(int, int), ui.Image> _roofs = {};

  // Animals facing [right, left].
  late final List<ui.Image> rabbit, deer, bird;

  final Map<CharacterLook, Map<String, List<ui.Image>>> _characters = {};

  Textures._() {
    _buildTerrain();
    _buildObjects();
    rabbit = _bothWays(CharacterArt.rabbit());
    deer = _bothWays(CharacterArt.deer());
    bird = _bothWays(CharacterArt.bird());
  }

  /// Frames for a character by facing ('down', 'up', 'left', 'right'):
  /// standing, then the two halves of a step.
  Map<String, List<ui.Image>> character(CharacterLook look) => _characters.putIfAbsent(
        look,
        () => {
          for (final e in CharacterArt.character(look).entries) e.key: [for (final f in e.value) f.toImage()],
        },
      );

  /// A roof for a house [width] tiles wide whose roof covers [height] rows.
  ui.Image roof(int width, int height) => _roofs.putIfAbsent(
        (width, height),
        () => ObjectArt.roof(Random(2700 + width * 10 + height), width, height, chimney: true).toImage(),
      );

  void _buildTerrain() {
    List<ui.Image> make(PixelCanvas Function(Random r) art, int seed) => [
          for (var v = 0; v < variants; v++) art(Random(seed * 101 + v)).toImage(),
        ];

    tiles['grass'] = make((r) => TerrainArt.grass(r, Palette.grass), 1);
    tiles['forest_grass'] = make((r) => TerrainArt.grass(r, Palette.forest, litter: true), 2);
    tiles['dirt'] = make(TerrainArt.dirt, 3);
    tiles['sand'] = make(TerrainArt.sand, 4);
    tiles['path'] = make(TerrainArt.cobble, 5);
    tiles['stone'] = make(TerrainArt.stone, 6);
    tiles['wood_floor'] = make(TerrainArt.woodFloor, 7);
    tiles['wood_wall'] = make(TerrainArt.logs, 8);
    tiles['bridge'] = make(TerrainArt.bridge, 9);
    tiles['farmland'] = make((r) => TerrainArt.farmland(r, wet: false), 10);
    tiles['farmland_wet'] = make((r) => TerrainArt.farmland(r, wet: true), 11);

    // Every frame of a variant reuses the same seed so only the waves move.
    water = [
      for (var v = 0; v < variants; v++)
        [for (var f = 0; f < 4; f++) TerrainArt.water(Random(1200 + v), f).toImage()],
    ];

    // Edge overlays are drawn for the top edge, then turned to each side.
    shore = [
      for (var side = 0; side < 4; side++)
        [
          for (var f = 0; f < 2; f++)
            _turn(TerrainArt.shore(Random(1300 + side), f, bankShadow: side == 0), side).toImage(),
        ],
    ];
    shoreCorner = [for (var corner = 0; corner < 4; corner++) _turn(TerrainArt.shoreCorner(), corner).toImage()];
    landEdge = [for (var side = 0; side < 4; side++) _turn(TerrainArt.landEdge(), side).toImage()];
    fringe = {
      for (final (name, ramp) in [('grass', Palette.grass), ('forest', Palette.forest)])
        name: [
          for (var side = 0; side < 4; side++)
            [
              for (var v = 0; v < 2; v++)
                _turn(TerrainArt.fringe(Random(1400 + side * 7 + v + name.length * 31), ramp), side).toImage(),
            ],
        ],
    };
    cliffFace = TerrainArt.cliffFace(Random(1500)).toImage();
    cliffTop = TerrainArt.cliffTop().toImage();
    cliffLeft = TerrainArt.cliffSide(left: true).toImage();
    cliffRight = TerrainArt.cliffSide(left: false).toImage();
    cliffShadow = TerrainArt.cliffShadow().toImage();
    railTop = TerrainArt.bridgeRail(top: true).toImage();
    railBottom = TerrainArt.bridgeRail(top: false).toImage();
    brokenPosts = TerrainArt.brokenPosts().toImage();
    fencePost = TerrainArt.fencePost().toImage();
    fenceRails = [for (var side = 0; side < 4; side++) TerrainArt.fenceRail(side).toImage()];
  }

  void _buildObjects() {
    oaks = [for (var v = 0; v < 3; v++) ObjectArt.oak(Random(2000 + v)).toImage()];
    pines = [for (var v = 0; v < 2; v++) ObjectArt.pine(Random(2100 + v)).toImage()];
    // The same seeds give the same trees, with and without fruit.
    appleTrees = [for (var v = 0; v < 2; v++) ObjectArt.oak(Random(2200 + v), apples: true).toImage()];
    bareAppleTrees = [for (var v = 0; v < 2; v++) ObjectArt.oak(Random(2200 + v)).toImage()];
    rocks = [for (var v = 0; v < variants; v++) ObjectArt.rock(Random(2300 + v)).toImage()];
    bushes = [for (var v = 0; v < 3; v++) ObjectArt.bush(Random(2400 + v), berries: true).toImage()];
    bareBushes = [for (var v = 0; v < 3; v++) ObjectArt.bush(Random(2400 + v), berries: false).toImage()];
    flowers = [
      for (final (i, (petal, centre)) in const [
        (0xFFF5F5F5, 0xFFFFD54F),
        (0xFFF28AB2, 0xFFFFE08A),
        (0xFF8FB4F5, 0xFFFFF2B0),
        (0xFFFFD54F, 0xFFE07A2A),
      ].indexed)
        ObjectArt.flowers(Random(2500 + i), petal, centre).toImage(),
    ];
    tallGrass = [for (var v = 0; v < 3; v++) ObjectArt.tallGrass(Random(2600 + v)).toImage()];
    crops = [for (var stage = 0; stage < 4; stage++) ObjectArt.crop(stage).toImage()];
    fire = [for (var f = 0; f < 3; f++) ObjectArt.firePit(lit: true, frame: f).toImage()];
    coldFirePit = ObjectArt.firePit(lit: false).toImage();
    cave = ObjectArt.cave().toImage();
    bed = ObjectArt.bed().toImage();
    bracket = ObjectArt.bracket().toImage();
    shadowSmall = ObjectArt.shadow(10, 4).toImage();
    shadowMedium = ObjectArt.shadow(14, 5).toImage();
    shadowLarge = ObjectArt.shadow(20, 6).toImage();
    wall = ObjectArt.facadeWall(Random(2800)).toImage();
    window = ObjectArt.facadeWindow(Random(2801), lit: false).toImage();
    litWindow = ObjectArt.facadeWindow(Random(2801), lit: true).toImage();
    door = ObjectArt.facadeDoor(Random(2802), open: false).toImage();
    openDoor = ObjectArt.facadeDoor(Random(2802), open: true).toImage();
  }

  static List<ui.Image> _bothWays(PixelCanvas facingRight) => [facingRight.toImage(), facingRight.mirrored().toImage()];

  static PixelCanvas _turn(PixelCanvas c, int quarterTurns) {
    var result = c;
    for (var i = 0; i < quarterTurns; i++) {
      result = rotateClockwise(result);
    }
    return result;
  }
}
