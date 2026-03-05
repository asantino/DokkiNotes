import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static final PrefsService _instance = PrefsService._internal();
  factory PrefsService() => _instance;
  PrefsService._internal();

  late SharedPreferences _prefs;

  // Уведомлялка внутри класса
  final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.system);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final isDark = _prefs.getBool('is_dark_mode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  bool get isDarkMode => _prefs.getBool('is_dark_mode') ?? false;

  // === Добавлено для поддержки биометрии ===
  bool get isBiometricEnabled => _prefs.getBool('biometric_enabled') ?? false;

  Future<void> setBiometricEnabled(bool value) async {
    await _prefs.setBool('biometric_enabled', value);
  }

  // Два дополнительных метода для биометрии
  bool get biometricAvailable => _prefs.getBool('biometric_available') ?? false;

  Future<void> setBiometricAvailable(bool value) async {
    await _prefs.setBool('biometric_available', value);
  }
  // === Конец добавленного ===

  set isDarkMode(bool value) {
    _prefs.setBool('is_dark_mode', value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  String get sortType => _prefs.getString('sort_type') ?? 'date';
  set sortType(String value) => _prefs.setString('sort_type', value);

  // === Онбординг ===
  bool get isOnboardingCompleted =>
      _prefs.getBool('onboarding_completed') ?? false;

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool('onboarding_completed', value);
  }
}

// Глобальная переменная - только сам сервис
final prefs = PrefsService();
