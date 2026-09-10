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

abstract final class ElevenwardSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class ElevenwardRadii {
  static const control = 14.0;
  static const card = 20.0;
  static const hero = 28.0;
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
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: ElevenwardColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElevenwardRadii.control),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: ElevenwardColors.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: ElevenwardColors.line),
        borderRadius: BorderRadius.circular(ElevenwardRadii.card),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 72,
      backgroundColor: ElevenwardColors.deep,
      indicatorColor: ElevenwardColors.grassDark,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ElevenwardColors.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElevenwardRadii.control),
        borderSide: const BorderSide(color: ElevenwardColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElevenwardRadii.control),
        borderSide: const BorderSide(color: ElevenwardColors.line),
      ),
    ),
  );
}

final class BroadcastPanel extends StatelessWidget {
  const BroadcastPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ElevenwardSpacing.md),
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: ElevenwardColors.panel.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(ElevenwardRadii.card),
      border: Border.all(color: accent ?? ElevenwardColors.line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: child,
  );
}
