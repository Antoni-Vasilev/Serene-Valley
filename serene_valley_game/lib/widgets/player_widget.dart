import 'package:flutter/material.dart';
import '../models/player.dart';

class PlayerWidget extends StatelessWidget {
  final Player player;
  final double tileSize;

  const PlayerWidget({
    super.key,
    required this.player,
    required this.tileSize,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: player.position.dx * tileSize,
      top: player.position.dy * tileSize,
      child: _buildPlayerSprite(),
    );
  }

  Widget _buildPlayerSprite() {
    Color playerColor = const Color(0xFF4CAF50);
    
    switch (player.direction) {
      case 'up':
        return _buildUpSprite(playerColor);
      case 'down':
        return _buildDownSprite(playerColor);
      case 'left':
        return _buildLeftSprite(playerColor);
      case 'right':
        return _buildRightSprite(playerColor);
      default:
        return _buildDownSprite(playerColor);
    }
  }

  Widget _buildDownSprite(Color color) {
    return SizedBox(
      width: tileSize,
      height: tileSize,
      child: Stack(
        children: [
          // Body
          Positioned(
            left: tileSize * 0.25,
            top: tileSize * 0.25,
            child: Container(
              width: tileSize * 0.5,
              height: tileSize * 0.4,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
          // Head
          Positioned(
            left: tileSize * 0.3,
            top: tileSize * 0.1,
            child: Container(
              width: tileSize * 0.4,
              height: tileSize * 0.3,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Hat (optional)
          Positioned(
            left: tileSize * 0.25,
            top: tileSize * 0.05,
            child: Container(
              width: tileSize * 0.5,
              height: tileSize * 0.15,
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(tileSize * 0.1),
              ),
            ),
          ),
          // Legs
          Positioned(
            left: tileSize * 0.3,
            top: tileSize * 0.65,
            child: Container(
              width: tileSize * 0.15,
              height: tileSize * 0.25,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
          Positioned(
            left: tileSize * 0.55,
            top: tileSize * 0.65,
            child: Container(
              width: tileSize * 0.15,
              height: tileSize * 0.25,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpSprite(Color color) {
    return SizedBox(
      width: tileSize,
      height: tileSize,
      child: Stack(
        children: [
          // Body
          Positioned(
            left: tileSize * 0.25,
            top: tileSize * 0.35,
            child: Container(
              width: tileSize * 0.5,
              height: tileSize * 0.4,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
          // Head
          Positioned(
            left: tileSize * 0.3,
            top: tileSize * 0.6,
            child: Container(
              width: tileSize * 0.4,
              height: tileSize * 0.3,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Hat
          Positioned(
            left: tileSize * 0.25,
            top: tileSize * 0.5,
            child: Container(
              width: tileSize * 0.5,
              height: tileSize * 0.15,
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(tileSize * 0.1),
              ),
            ),
          ),
          // Legs
          Positioned(
            left: tileSize * 0.3,
            top: tileSize * 0.1,
            child: Container(
              width: tileSize * 0.15,
              height: tileSize * 0.25,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
          Positioned(
            left: tileSize * 0.55,
            top: tileSize * 0.1,
            child: Container(
              width: tileSize * 0.15,
              height: tileSize * 0.25,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSprite(Color color) {
    return SizedBox(
      width: tileSize,
      height: tileSize,
      child: Stack(
        children: [
          // Body
          Positioned(
            left: tileSize * 0.35,
            top: tileSize * 0.25,
            child: Container(
              width: tileSize * 0.4,
              height: tileSize * 0.5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
          // Head
          Positioned(
            left: tileSize * 0.1,
            top: tileSize * 0.2,
            child: Container(
              width: tileSize * 0.3,
              height: tileSize * 0.3,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Hat
          Positioned(
            left: tileSize * 0.05,
            top: tileSize * 0.15,
            child: Container(
              width: tileSize * 0.15,
              height: tileSize * 0.2,
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(tileSize * 0.1),
              ),
            ),
          ),
          // Legs
          Positioned(
            left: tileSize * 0.3,
            top: tileSize * 0.65,
            child: Container(
              width: tileSize * 0.2,
              height: tileSize * 0.15,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
          Positioned(
            left: tileSize * 0.3,
            top: tileSize * 0.8,
            child: Container(
              width: tileSize * 0.2,
              height: tileSize * 0.15,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSprite(Color color) {
    return SizedBox(
      width: tileSize,
      height: tileSize,
      child: Stack(
        children: [
          // Body
          Positioned(
            left: tileSize * 0.25,
            top: tileSize * 0.25,
            child: Container(
              width: tileSize * 0.4,
              height: tileSize * 0.5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
          // Head
          Positioned(
            left: tileSize * 0.6,
            top: tileSize * 0.2,
            child: Container(
              width: tileSize * 0.3,
              height: tileSize * 0.3,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Hat
          Positioned(
            left: tileSize * 0.7,
            top: tileSize * 0.15,
            child: Container(
              width: tileSize * 0.15,
              height: tileSize * 0.2,
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(tileSize * 0.1),
              ),
            ),
          ),
          // Legs
          Positioned(
            left: tileSize * 0.5,
            top: tileSize * 0.65,
            child: Container(
              width: tileSize * 0.2,
              height: tileSize * 0.15,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
          Positioned(
            left: tileSize * 0.5,
            top: tileSize * 0.8,
            child: Container(
              width: tileSize * 0.2,
              height: tileSize * 0.15,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
