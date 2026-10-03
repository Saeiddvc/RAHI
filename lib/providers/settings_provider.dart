import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/map_service.dart';

class SettingsState {
  final Locale locale;
  final ThemeMode themeMode;
  final bool voiceEnabled;
  final RouteType routeType;

  const SettingsState({
    this.locale = const Locale('fa', 'IR'),
    this.themeMode = ThemeMode.system,
    this.voiceEnabled = true,
    this.routeType = RouteType.car,
  });

  SettingsState copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool? voiceEnabled,
    RouteType? routeType,
  }) {
    return SettingsState(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      routeType: routeType ?? this.routeType,
    );
  }

  String get languageCode => locale.languageCode;
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();

    final language = preferences.getString('lang') ?? 'fa';
    final theme = preferences.getString('theme') ?? 'system';
    final voice = preferences.getBool('voice') ?? true;
    final routeType = preferences.getString('routeType') ?? 'car';

    state = SettingsState(
      locale: _localeFromCode(language),
      themeMode: _themeFromCode(theme),
      voiceEnabled: voice,
      routeType: _routeTypeFromCode(routeType),
    );
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('lang', locale.languageCode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('theme', _themeToCode(mode));
  }

  Future<void> setVoice(bool enabled) async {
    state = state.copyWith(voiceEnabled: enabled);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('voice', enabled);
  }

  Future<void> setRouteType(RouteType routeType) async {
    state = state.copyWith(routeType: routeType);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('routeType', routeType.name);
  }

  Locale _localeFromCode(String code) {
    return switch (code) {
      'ar' => const Locale('ar', 'SA'),
      'en' => const Locale('en', 'US'),
      _ => const Locale('fa', 'IR'),
    };
  }

  ThemeMode _themeFromCode(String code) {
    return switch (code) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String _themeToCode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  RouteType _routeTypeFromCode(String code) {
    return RouteType.values.firstWhere(
      (value) => value.name == code,
      orElse: () => RouteType.car,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
