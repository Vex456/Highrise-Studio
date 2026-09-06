import 'package:flutter/material.dart';

class StudioTheme {
  // Base Palette
  static const Color background = Color(0xFF0B0F19); // Deep Obsidian
  static const Color surface = Color(0xFF0F172A);    // Slate Navy
  static const Color card = Color(0xFF1E293B);       // Slate Card
  static const Color cardBorder = Color(0xFF334155); // Border
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Status Colors
  static const Color online = Color(0xFF10B981);
  static const Color offline = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color accent = Color(0xFF38BDF8);

  // Bot Fleet Palette
  static const Color bot1 = Color(0xFF38BDF8); // Bot 1: Moderation (Cyan)
  static const Color bot2 = Color(0xFF818CF8); // Bot 2: Concierge (Indigo)
  static const Color bot3 = Color(0xFFF59E0B); // Bot 3: Tracking (Amber)
  static const Color bot4 = Color(0xFFA855F7); // Bot 4: Radio (Purple)
  static const Color bot5 = Color(0xFFF43F5E); // Bot 5: Games (Rose)
  static const Color bot6 = Color(0xFF10B981); // Bot 6: Chaty (Emerald)

  // Extended Convenience Aliases
  static const Color cardDark = card;
  static const Color borderDark = cardBorder;
  static const Color surfaceDark = surface;
  static const Color bgDark = background;
  static const Color accentSky = accent;
  static const Color accentPink = bot5;
  static const Color accentPurple = bot4;
  static const Color accentYellow = warning;
  static const Color accentEmerald = bot6;
  static const Color accentRed = offline;

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      canvasColor: surface,
      cardColor: card,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: bot4,
        surface: card,
        background: background,
        error: offline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}
