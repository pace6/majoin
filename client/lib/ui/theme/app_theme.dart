import 'package:flutter/material.dart';

/// Line-ish palette + tokens.
class AppTheme {
  // Brand
  static const lineGreen = Color(0xFF06C755);
  static const lineGreenDark = Color(0xFF00B900);

  // Surfaces
  static const chatBg = Color(0xFF8B9DA8);          // muted blue-gray (Line classic)
  static const listBg = Color(0xFFFFFFFF);
  static const dividerColor = Color(0xFFEBEBEB);
  static const subtleText = Color(0xFF8E8E93);

  // Bubbles
  static const myBubble = Color(0xFF06C755);        // green
  static const myBubbleText = Color(0xFFFFFFFF);
  static const theirBubble = Color(0xFFFFFFFF);
  static const theirBubbleText = Color(0xFF1A1A1A);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: lineGreen),
        scaffoldBackgroundColor: listBg,
        dividerColor: dividerColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          shape: Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: Color(0xFFEAFBEF),
          surfaceTintColor: Colors.white,
        ),
        listTileTheme: const ListTileThemeData(
          minVerticalPadding: 10,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: lineGreen,
          brightness: Brightness.dark,
        ),
      );
}
