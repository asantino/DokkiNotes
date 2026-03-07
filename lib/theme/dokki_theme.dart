import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class DokkiTheme {
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: DokkiColors.primaryTeal,
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: Colors.black),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: DokkiColors.primaryTeal,
      foregroundColor: Colors.white,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: DokkiColors.primaryTeal,
      selectionColor: Color(0x4400BFA5),
      selectionHandleColor: DokkiColors.primaryTeal,
    ),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: DokkiColors.primaryTeal,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: DokkiColors.primaryTeal,
      foregroundColor: Colors.white,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: DokkiColors.primaryTeal,
      selectionColor: Color(0x4400BFA5),
      selectionHandleColor: DokkiColors.primaryTeal,
    ),
  );
}

class DokkiColors {
  static const Color primaryTeal = Color(0xFF00BFA5);
}
