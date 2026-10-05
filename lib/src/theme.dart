import 'package:flutter/material.dart';

Duration motionDuration(BuildContext context, Duration preferred) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : preferred;

abstract final class ElevenwardColors {
  // Existing presentation components use these semantic aliases. The palette
  // is selected by ElevenwardApp before its route subtree builds.
  static ElevenwardPalette _active = ElevenwardPalette.dark;

  static void use(Brightness brightness) {
    _active = brightness == Brightness.dark
        ? ElevenwardPalette.dark
        : ElevenwardPalette.light;
  }

  static Color get ink => _active.ink;
  static Color get deep => _active.deep;
  static Color get panel => _active.panel;
  static Color get panelLight => _active.panelLight;
  static Color get line => _active.line;
  static Color get grass => _active.action;
  static Color get grassDark => _active.actionSurface;
  static Color get cream => _active.text;
  static Color get muted => _active.muted;
  static Color get amber => _active.warning;
  static Color get coral => _active.danger;
  static Color get sky => _active.info;
  static Color get onAction => _active.onAction;
}

final class ElevenwardPalette {
  const ElevenwardPalette({
    required this.ink,
    required this.deep,
    required this.panel,
    required this.panelLight,
    required this.line,
    required this.action,
    required this.actionSurface,
    required this.text,
    required this.muted,
    required this.warning,
    required this.danger,
    required this.info,
    required this.onAction,
  });

  final Color ink;
  final Color deep;
  final Color panel;
  final Color panelLight;
  final Color line;
  final Color action;
  final Color actionSurface;
  final Color text;
  final Color muted;
  final Color warning;
  final Color danger;
  final Color info;
  final Color onAction;

  static const dark = ElevenwardPalette(
    ink: Color(0xFF0B0C0F),
    deep: Color(0xFF111317),
    panel: Color(0xFF191B1F),
    panelLight: Color(0xFF23262B),
    line: Color(0xFF373C43),
    action: Color(0xFFA5BED2),
    actionSurface: Color(0xFF273847),
    text: Color(0xFFF1F0EC),
    muted: Color(0xFFAEB4BC),
    warning: Color(0xFFFFCB70),
    danger: Color(0xFFFF9080),
    info: Color(0xFF8CC8DD),
    onAction: Color(0xFF0B0C0F),
  );

  static const light = ElevenwardPalette(
    ink: Color(0xFFF5F4F0),
    deep: Color(0xFFEDECE8),
    panel: Color(0xFFFFFFFF),
    panelLight: Color(0xFFE9E8E4),
    line: Color(0xFFCDD0D3),
    action: Color(0xFF496783),
    actionSurface: Color(0xFFDCE6EE),
    text: Color(0xFF17191D),
    muted: Color(0xFF5A6068),
    warning: Color(0xFF775000),
    danger: Color(0xFFA7382B),
    info: Color(0xFF2F6681),
    onAction: Color(0xFFFFFFFF),
  );

  Color cosmeticAccent(String id) => switch (id) {
    'ocean' => info,
    'violet' => const Color(0xFFAA95CB),
    'sunset' => danger,
    _ => action,
  };
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

ThemeData buildElevenwardTheme([
  String themeId = 'graphite',
  Brightness brightness = Brightness.dark,
]) {
  final palette = brightness == Brightness.dark
      ? ElevenwardPalette.dark
      : ElevenwardPalette.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.action,
        brightness: brightness,
        surface: palette.panel,
      ).copyWith(
        primary: palette.action,
        onPrimary: palette.onAction,
        secondary: palette.cosmeticAccent(themeId),
        onSecondary: palette.onAction,
        surface: palette.panel,
        onSurface: palette.text,
        outline: palette.line,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.ink,
    dividerColor: palette.line,
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 52,
        height: 0.92,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.1,
        color: palette.text,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: palette.text,
      ),
      headlineMedium: TextStyle(
        fontSize: 23,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: palette.text,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: palette.text,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.42, color: palette.text),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: palette.muted),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: palette.action,
        foregroundColor: palette.onAction,
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
        side: BorderSide(color: palette.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElevenwardRadii.control),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: palette.line),
        borderRadius: BorderRadius.circular(ElevenwardRadii.card),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: palette.deep,
      indicatorColor: palette.actionSurface,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElevenwardRadii.control),
        borderSide: BorderSide(color: palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElevenwardRadii.control),
        borderSide: BorderSide(color: palette.line),
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
