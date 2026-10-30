import 'package:flutter/material.dart';

import '../audio/sound.dart';
import 'pixel_ui.dart';

/// Buttons that switch the music and the sound effects on and off.
class SoundToggles extends StatelessWidget {
  const SoundToggles({super.key});

  @override
  Widget build(BuildContext context) {
    final sound = Sound.instance;
    return ListenableBuilder(
      listenable: sound,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggle('music', 'Music', sound.musicOn, () => sound.setMusicOn(!sound.musicOn)),
          const SizedBox(width: 10),
          _toggle('speaker', 'Sounds', sound.soundOn, () => sound.setSoundOn(!sound.soundOn)),
        ],
      ),
    );
  }

  Widget _toggle(String icon, String label, bool on, VoidCallback onPressed) {
    return PixelButton(
      onPressed: onPressed,
      tooltip: '$label ${on ? 'on' : 'off'}',
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelIcon(icon, size: 20, opacity: on ? 1 : 0.35),
          const SizedBox(width: 6),
          Text(on ? 'On' : 'Off', style: pixelText(14, bold: true, color: on ? UiColors.cream : UiColors.faded)),
        ],
      ),
    );
  }
}
