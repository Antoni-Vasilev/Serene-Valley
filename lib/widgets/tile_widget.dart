import 'package:flutter/material.dart';

class TileWidget extends StatelessWidget {
  final String tileType;
  final double tileSize;
  final double lightLevel;

  const TileWidget({
    super.key,
    required this.tileType,
    required this.tileSize,
    this.lightLevel = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tileSize,
      height: tileSize,
      child: Container(
        decoration: BoxDecoration(
          color: _getTileColor(),
          border: Border.all(
            color: Colors.black.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: _buildTileContent(),
      ),
    );
  }

  Color _getTileColor() {
    switch (tileType) {
      case 'grass':
        return const Color(0xFF7CFC00);
      case 'dirt':
        return const Color(0xFF8B4513);
      case 'sand':
        return const Color(0xFFFFD700);
      case 'stone':
        return const Color(0xFF808080);
      case 'water':
        return Colors.blue;
      case 'forest_grass':
        return const Color(0xFF228B22);
      case 'wood_floor':
        return const Color(0xFFCD853F);
      case 'wood_wall':
        return const Color(0xFFA0522D);
      case 'void':
        return Colors.black;
      default:
        return const Color(0xFF7CFC00);
    }
  }

  Widget _buildTileContent() {
    switch (tileType) {
      case 'grass':
        return _buildGrassTile();
      case 'forest_grass':
        return _buildForestGrassTile();
      case 'water':
        return _buildWaterTile();
      case 'sand':
        return _buildSandTile();
      case 'stone':
        return _buildStoneTile();
      case 'dirt':
        return _buildDirtTile();
      case 'wood_floor':
        return _buildWoodFloorTile();
      case 'wood_wall':
        return _buildWoodWallTile();
      default:
        return Container();
    }
  }

  Widget _buildGrassTile() {
    return Stack(
      children: [
        // Base grass
        Container(
          color: const Color(0xFF7CFC00),
        ),
        // Grass texture
        Positioned.fill(
          child: CustomPaint(
            painter: GrassPainter(tileSize),
          ),
        ),
      ],
    );
  }

  Widget _buildForestGrassTile() {
    return Container(
      color: const Color(0xFF228B22),
      child: CustomPaint(
        painter: ForestGrassPainter(tileSize),
      ),
    );
  }

  Widget _buildWaterTile() {
    return Container(
      color: Colors.blue,
      child: CustomPaint(
        painter: WaterPainter(tileSize),
      ),
    );
  }

  Widget _buildSandTile() {
    return Container(
      color: const Color(0xFFFFD700),
      child: CustomPaint(
        painter: SandPainter(tileSize),
      ),
    );
  }

  Widget _buildStoneTile() {
    return Container(
      color: const Color(0xFF808080),
      child: CustomPaint(
        painter: StonePainter(tileSize),
      ),
    );
  }

  Widget _buildDirtTile() {
    return Container(
      color: const Color(0xFF8B4513),
      child: CustomPaint(
        painter: DirtPainter(tileSize),
      ),
    );
  }

  Widget _buildWoodFloorTile() {
    return Container(
      color: const Color(0xFFCD853F),
      child: CustomPaint(
        painter: WoodFloorPainter(tileSize),
      ),
    );
  }

  Widget _buildWoodWallTile() {
    return Container(
      color: const Color(0xFFA0522D),
      child: CustomPaint(
        painter: WoodWallPainter(tileSize),
      ),
    );
  }
}

class GrassPainter extends CustomPainter {
  final double tileSize;

  GrassPainter(this.tileSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF228B22)
      ..style = PaintingStyle.fill;

    // Draw some grass blades
    for (int i = 0; i < 5; i++) {
      double x = size.width * (0.2 + i * 0.15);
      double height = size.height * (0.3 + Random().nextDouble() * 0.4);
      
      canvas.drawRect(
        Rect.fromLTRB(x, size.height - height, x + 2, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ForestGrassPainter extends CustomPainter {
  final double tileSize;

  ForestGrassPainter(this.tileSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF006400)
      ..style = PaintingStyle.fill;

    // Draw denser grass
    for (int i = 0; i < 8; i++) {
      double x = size.width * (0.1 + i * 0.1);
      double height = size.height * (0.4 + Random().nextDouble() * 0.5);
      
      canvas.drawRect(
        Rect.fromLTRB(x, size.height - height, x + 2, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WaterPainter extends CustomPainter {
  final double tileSize;

  WaterPainter(this.tileSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Draw water waves
    for (int i = 0; i < 3; i++) {
      double y = size.height * (0.3 + i * 0.2);
      canvas.drawOval(
        Rect.fromLTRB(0, y, size.width, y + size.height * 0.1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SandPainter extends CustomPainter {
  final double tileSize;

  SandPainter(this.tileSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFE4B5)
      ..style = PaintingStyle.fill;

    // Draw sand texture
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        double x = size.width * (i * 0.2);
        double y = size.height * (j * 0.2);
        
        if ((i + j) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTRB(x, y, x + size.width * 0.15, y + size.height * 0.15),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StonePainter extends CustomPainter {
  final double tileSize;

  StonePainter(this.tileSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFA9A9A9)
      ..style = PaintingStyle.fill;

    // Draw stone texture
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        double x = size.width * (i * 0.25);
        double y = size.height * (j * 0.25);
        
        if (Random().nextDouble() > 0.5) {
          canvas.drawRect(
            Rect.fromLTRB(x, y, x + size.width * 0.2, y + size.height * 0.2),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DirtPainter extends CustomPainter {
  final double tileSize;

  DirtPainter(this.tileSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFA0522D)
      ..style = PaintingStyle.fill;

    // Draw dirt texture
    for (int i = 0; i < 3; i++) {
      double x = size.width * (0.2 + i * 0.2);
      double y = size.height * 0.5;
      
      canvas.drawOval(
        Rect.fromLTRB(x, y, x + size.width * 0.15, y + size.height * 0.3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WoodFloorPainter extends CustomPainter {
  final double tileSize;

  WoodFloorPainter(this.tileSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDEB887)
      ..style = PaintingStyle.fill;

    // Draw wood planks
    for (int i = 0; i < 3; i++) {
      double x = size.width * (i * 0.33);
      canvas.drawRect(
        Rect.fromLTRB(x, 0, x + size.width * 0.25, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WoodWallPainter extends CustomPainter {
  final double tileSize;

  WoodWallPainter(this.tileSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCD853F)
      ..style = PaintingStyle.fill;

    // Draw wood panels
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, size.height),
      paint,
    );

    // Draw wood lines
    final linePaint = Paint()
      ..color = const Color(0xFFA0522D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i < 4; i++) {
      double y = size.height * (i * 0.25);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
