import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';

/// Where the save game is kept.
abstract class SaveStorage {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

class PrefsSaveStorage implements SaveStorage {
  static const _key = 'save_game';
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  @override
  Future<String?> read() => _prefs.getString(_key);

  @override
  Future<void> write(String data) => _prefs.setString(_key, data);

  @override
  Future<void> clear() => _prefs.remove(_key);
}

/// Keeps the save in memory; used by tests.
class MemorySaveStorage implements SaveStorage {
  String? data;

  MemorySaveStorage([this.data]);

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async => this.data = data;

  @override
  Future<void> clear() async => data = null;
}

/// A short description of a save, for the title screen.
class SaveSummary {
  final int day;
  final int level;
  final String progress;

  const SaveSummary({required this.day, required this.level, required this.progress});
}

class SaveService {
  final SaveStorage storage;
  Future<void> _pending = Future.value();

  SaveService({SaveStorage? storage}) : storage = storage ?? PrefsSaveStorage();

  Future<void> save(GameState state) {
    final data = jsonEncode(state.toJson());
    // Chain writes so an older save can never land after a newer one.
    _pending = _pending.then((_) => storage.write(data)).catchError((Object e) {
      debugPrint('Saving failed: $e');
    });
    return _pending;
  }

  /// Loads the saved game, or returns null if there is none or it can't be read.
  Future<GameState?> load() async {
    try {
      final data = await storage.read();
      if (data == null) return null;
      return GameState.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Ignoring unreadable save: $e');
      return null;
    }
  }

  Future<SaveSummary?> summary() async {
    final state = await load();
    if (state == null) return null;
    final quest = state.currentQuest;
    return SaveSummary(
      day: state.world.day,
      level: state.player.level,
      progress: quest == null ? 'Chapter 1 complete' : quest.title,
    );
  }

  Future<void> delete() => storage.clear();
}
