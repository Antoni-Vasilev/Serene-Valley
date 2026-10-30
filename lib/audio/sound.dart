import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Music, ambience and sound effects (made by tool/generate_audio.dart).
///
/// Silent until [init] is called, so tests run without audio.
class Sound extends ChangeNotifier with WidgetsBindingObserver {
  static final Sound instance = Sound._();

  Sound._();

  /// Each effect and how many copies of it can play at once.
  static const _effects = {
    'chop': 3,
    'mine': 3,
    'pickup': 3,
    'splash': 2,
    'nibble': 2,
    'pick': 3,
    'eat': 2,
    'step': 3,
    'step_wood': 3,
    'open': 2,
    'close': 2,
    'blip_low': 3,
    'blip_mid': 3,
    'blip_high': 3,
    'accept': 1,
    'quest': 1,
    'levelup': 1,
    'craft': 2,
    'place': 1,
    'sizzle': 2,
    'water': 2,
    'plant': 2,
    'sleep': 1,
    'deny': 2,
    'fanfare': 1,
    'torch': 1,
    'fizzle': 1,
    'swish': 2,
    'crumble': 1,
    'smelt': 2,
    'chime': 2,
    'climb': 1,
  };
  static const _loops = [
    'music_day',
    'music_night',
    'music_mine',
    'ambience_day',
    'ambience_night',
    'ambience_mine',
    'river',
    'fire',
  ];
  static const _musicVolume = 0.5;
  static const _ambienceVolume = 0.45;

  final Map<String, List<AudioPlayer>> _effectPlayers = {};
  final Map<String, int> _nextPlayer = {};
  final Map<String, AudioPlayer> _loopPlayers = {};
  final Map<String, double> _volume = {};
  final Map<String, double> _target = {};
  final Set<String> _playing = {};
  SharedPreferencesAsync? _prefs;
  Timer? _timer;
  // Music and ambience can play once their loops are loaded; effects follow.
  bool _loopsReady = false;
  bool _effectsReady = false;
  bool _inBackground = false;

  bool musicOn = true;
  bool soundOn = true;

  // What the current scene sounds like.
  double _darkness = 0;
  double _water = 0;
  double _fire = 0;
  bool _ambience = false;
  bool _underground = false;

  Future<void> init() async {
    try {
      final prefs = _prefs = SharedPreferencesAsync();
      musicOn = await prefs.getBool('music_on') ?? true;
      soundOn = await prefs.getBool('sound_on') ?? true;
      // Mix with whatever else is playing, e.g. the player's own music.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      for (final name in _loops) {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setVolume(0);
        await player.setSource(AssetSource('audio/$name.wav'));
        _loopPlayers[name] = player;
        _volume[name] = 0;
      }
      WidgetsBinding.instance.addObserver(this);
      _loopsReady = true;
      _updateTargets();
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _fade(0.05));

      for (final e in _effects.entries) {
        _effectPlayers[e.key] = [
          for (var i = 0; i < e.value; i++) await _effectPlayer(e.key),
        ];
        _nextPlayer[e.key] = 0;
      }
      _effectsReady = true;
    } catch (e) {
      debugPrint('Sound is unavailable: $e');
    }
  }

  Future<AudioPlayer> _effectPlayer(String name) async {
    final player = AudioPlayer();
    await player.setPlayerMode(PlayerMode.lowLatency);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource('audio/$name.wav'));
    return player;
  }

  /// Plays a sound effect.
  void play(String name, {double volume = 1}) {
    if (!_effectsReady || !soundOn || _inBackground) return;
    final players = _effectPlayers[name];
    if (players == null) return;
    // Take turns, so the same sound can overlap itself.
    final i = _nextPlayer[name]!;
    _nextPlayer[name] = (i + 1) % players.length;
    final player = players[i];
    unawaited(() async {
      try {
        await player.stop();
        await player.setVolume(volume);
        await player.resume();
      } catch (e) {
        debugPrint('Could not play $name: $e');
      }
    }());
  }

  /// Sets what should be heard: [darkness] runs from 0 by day to 1 at night;
  /// [water] and [fire] from 0 (far away) to 1 (right next to it). The mine
  /// has music and sounds of its own. Without [ambience], e.g. on the title
  /// screen, only the music plays.
  void setScene({
    double darkness = 0,
    double water = 0,
    double fire = 0,
    bool underground = false,
    bool ambience = true,
  }) {
    _darkness = darkness.clamp(0.0, 1.0);
    _water = water.clamp(0.0, 1.0);
    _fire = fire.clamp(0.0, 1.0);
    _underground = underground;
    _ambience = ambience;
    _updateTargets();
  }

  Future<void> setMusicOn(bool on) async {
    musicOn = on;
    _updateTargets();
    notifyListeners();
    await _prefs?.setBool('music_on', on);
  }

  Future<void> setSoundOn(bool on) async {
    soundOn = on;
    _updateTargets();
    notifyListeners();
    await _prefs?.setBool('sound_on', on);
  }

  void _updateTargets() {
    final music = musicOn ? _musicVolume : 0.0;
    final ambience = soundOn && _ambience ? _ambienceVolume : 0.0;
    final valley = _underground ? 0.0 : 1.0;
    _target['music_day'] = music * (1 - _darkness) * valley;
    _target['music_night'] = music * _darkness * valley;
    _target['music_mine'] = music * (1 - valley);
    _target['ambience_day'] = ambience * (1 - _darkness) * valley;
    _target['ambience_night'] = ambience * _darkness * valley;
    _target['ambience_mine'] = ambience * (1 - valley);
    _target['river'] = ambience * 1.5 * _water;
    _target['fire'] = ambience * 1.5 * _fire;
  }

  /// Eases every loop towards its target volume.
  void _fade(double dt) {
    if (!_loopsReady || _inBackground) return;
    for (final name in _loops) {
      final player = _loopPlayers[name]!;
      final current = _volume[name]!;
      final target = _target[name] ?? 0;
      final next = current + (target - current).clamp(-dt * 0.8, dt * 0.8);
      if ((next - current).abs() > 0.004 || (next == 0 && current != 0)) {
        _volume[name] = next;
        unawaited(player.setVolume(next));
      }
      // Silent loops are paused to save battery, and resumed when needed.
      if (next > 0.001 && _playing.add(name)) {
        unawaited(player.resume());
      } else if (next <= 0.001 && target == 0 && _playing.remove(name)) {
        unawaited(player.pause());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (background == _inBackground) return;
    _inBackground = background;
    for (final name in _playing) {
      final player = _loopPlayers[name]!;
      unawaited(background ? player.pause() : player.resume());
    }
  }

  /// How loud something [distance] tiles away is, fading out at [range].
  static double nearness(double distance, double range) => max(0, 1 - distance / range);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
