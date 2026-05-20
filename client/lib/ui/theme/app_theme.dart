import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Pebble" design system — a warm, soft messenger look.
///
/// Off-white base with a fresh mint-green accent, IBM Plex Sans Thai type,
/// generously rounded UI. Legacy field names (lineGreen, myBubble, …) are
/// kept as aliases so existing widgets restyle without edits.
class AppTheme {
  // ─── Palette ──────────────────────────────────────────────────────────
  /// Mint accent.
  static const accent = Color(0xFF22B07D);
  static const accentSoft = Color(0xFFD6F2E5);
  static const accentDeep = Color(0xFF0E7A53);

  /// Warm off-white surfaces.
  static const bg = Color(0xFFFAF8F5);
  static const bgOuter = Color(0xFFEEEAE2);
  static const card = Color(0xFFFFFFFF);

  static const ink = Color(0xFF26241F); // primary text — warm near-black
  static const subtleText = Color(0xFF8B8680); // warm gray
  static const dividerColor = Color(0x14000000);
  static const online = Color(0xFF3CCB7F);

  // ─── Legacy aliases (keep existing widgets working) ───────────────────
  static const lineGreen = accent;
  static const lineGreenDark = accentDeep;
  static const chatBg = bg;
  static const listBg = bg;
  static const myBubble = accent;
  static const myBubbleText = Color(0xFFFFFFFF);
  static const theirBubble = Color(0xFFFFFFFF);
  static const theirBubbleText = ink;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      primary: accent,
      surface: bg,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      dividerColor: dividerColor,
      textTheme: GoogleFonts.ibmPlexSansThaiTextTheme(base.textTheme)
          .apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: bg,
        elevation: 0,
        indicatorColor: accentSoft,
        surfaceTintColor: bg,
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 10),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    );
    final base = ThemeData(
        useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme);
    return base.copyWith(
      textTheme: GoogleFonts.ibmPlexSansThaiTextTheme(base.textTheme),
    );
  }
}
