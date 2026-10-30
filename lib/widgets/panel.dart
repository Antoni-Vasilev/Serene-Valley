import 'package:flutter/material.dart';

/// Full-screen menu panel with a title bar and a close button. It stays clear
/// of notches and system bars. Must be placed directly in a [Stack].
class FullScreenPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback onClose;

  const FullScreenPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: Container(
            color: Colors.black.withValues(alpha: 0.9),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.brown[800],
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: onClose,
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
