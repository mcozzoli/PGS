import 'package:flutter/material.dart';
import 'config.dart';

class PgsColors {
  static const blue800 = Color(Config.blue800);
  static const blue = Color(Config.blue);
  static const orange = Color(Config.orange);
  static const bg = Color(0xFFF2F5FB);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PgsColors.blue,
      primary: PgsColors.blue,
      secondary: PgsColors.orange,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: PgsColors.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: PgsColors.blue800,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PgsColors.orange,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PgsColors.blue800,
      contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}
