import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// The user's design preferences. Persisted and shared by both the client and
/// server so one device honors the same look everywhere.
@immutable
class Personalization {
  final ThemeMode themeMode;
  final String accentId;
  final AppDensity density;

  const Personalization({
    this.themeMode = ThemeMode.system,
    this.accentId = 'indigo',
    this.density = AppDensity.comfortable,
  });

  AccentOption get accent => AccentPalette.byId(accentId);

  Personalization copyWith({
    ThemeMode? themeMode,
    String? accentId,
    AppDensity? density,
  }) =>
      Personalization(
        themeMode: themeMode ?? this.themeMode,
        accentId: accentId ?? this.accentId,
        density: density ?? this.density,
      );
}

/// Shared-preferences keys (shared between client and server).
class _Keys {
  static const themeMode = 'mdk.themeMode';
  static const accent = 'mdk.accent';
  static const density = 'mdk.density';
}

final personalizationProvider =
    NotifierProvider<PersonalizationNotifier, Personalization>(
  PersonalizationNotifier.new,
);

class PersonalizationNotifier extends Notifier<Personalization> {
  @override
  Personalization build() {
    _load();
    return const Personalization();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = Personalization(
        themeMode: _parseThemeMode(prefs.getString(_Keys.themeMode)),
        accentId: prefs.getString(_Keys.accent) ?? 'indigo',
        density: prefs.getString(_Keys.density) == 'compact'
            ? AppDensity.compact
            : AppDensity.comfortable,
      );
    } catch (e) {
      debugPrint('Error loading personalization: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _save(_Keys.themeMode, mode.name);
  }

  Future<void> setAccent(String accentId) async {
    state = state.copyWith(accentId: accentId);
    await _save(_Keys.accent, accentId);
  }

  Future<void> setDensity(AppDensity density) async {
    state = state.copyWith(density: density);
    await _save(_Keys.density, density.name);
  }

  Future<void> _save(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('Error saving personalization: $e');
    }
  }

  static ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
