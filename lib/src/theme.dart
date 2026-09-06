import 'package:flutter/material.dart';

Duration motionDuration(BuildContext context, Duration preferred) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : preferred;

abstract final class ElevenwardColors {
  static const ink = Color(0xFF07110C);
  static const deep = Color(0xFF0B1911);
  static const panel = Color(0xFF10231A);
  static const panelLight = Color(0xFF173025);
  static const line = Color(0xFF294638);
  static const grass = Color(0xFFB7F34A);
  static const grassDark = Color(0xFF1B3B27);
  static const cream = Color(0xFFF3F0E5);
  static const muted = Color(0xFF9DB0A5);
  static const amber = Color(0xFFFFC65B);
  static const coral = Color(0xFFFF806B);
  static const sky = Color(0xFF75C8E8);
}

IconData elevenwardAvatarIcon(String avatarId) => switch (avatarId) {
  'captain' => Icons.shield_rounded,
  'creator' => Icons.auto_awesome_rounded,
  'finisher' => Icons.sports_soccer_rounded,
  _ => Icons.person_rounded,
};

Color elevenwardCosmeticColor(String value) => switch (value) {
  'ocean' || 'stadium' => ElevenwardColors.sky,
  'violet' || 'midnight' => const Color(0xFFBA9BFF),
  'sunset' || 'editorial' => ElevenwardColors.coral,
  'captain' => ElevenwardColors.amber,
  'creator' => ElevenwardColors.sky,
  'finisher' => ElevenwardColors.coral,
  _ => ElevenwardColors.grass,
};

ThemeData buildElevenwardTheme([String themeId = 'pitch']) {
  final seed = switch (themeId) {
    'ocean' => ElevenwardColors.sky,
    'violet' => const Color(0xFFBA9BFF),
    'sunset' => ElevenwardColors.coral,
    _ => ElevenwardColors.grass,
  };
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
    surface: ElevenwardColors.panel,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ElevenwardColors.ink,
    dividerColor: ElevenwardColors.line,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 52,
        height: 0.92,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.1,
        color: ElevenwardColors.cream,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: ElevenwardColors.cream,
      ),
      headlineMedium: TextStyle(
        fontSize: 23,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: ElevenwardColors.cream,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ElevenwardColors.cream,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.42,
        color: ElevenwardColors.cream,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: ElevenwardColors.muted,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: seed,
        foregroundColor: ElevenwardColors.ink,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
