import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio/sound.dart';
import 'screens/title_screen.dart';
import 'services/save_service.dart';
import 'widgets/pixel_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Full-screen game: hide the status and navigation bars until swiped in.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Loads in the background; sounds start as soon as they're ready.
  Sound.instance.init();
  runApp(SereneValleyApp(saveService: SaveService()));
}

class SereneValleyApp extends StatelessWidget {
  final SaveService saveService;

  const SereneValleyApp({super.key, required this.saveService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serene Valley',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B8E23),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Pixelify',
        tooltipTheme: TooltipThemeData(
          decoration: const BoxDecoration(color: Color(0xFF2A1D14)),
          textStyle: pixelText(14),
        ),
        useMaterial3: true,
      ),
      home: TitleScreen(saveService: saveService),
    );
  }
}
