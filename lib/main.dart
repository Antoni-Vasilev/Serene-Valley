import 'package:flutter/material.dart';
import 'screens/game_screen.dart';

void main() {
  runApp(const SereneValleyApp());
}

class SereneValleyApp extends StatelessWidget {
  const SereneValleyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serene Valley',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B8E23),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
