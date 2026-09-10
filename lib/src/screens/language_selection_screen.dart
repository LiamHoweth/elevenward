import 'package:flutter/material.dart';

import '../theme.dart';

/// The only first-launch decision. Copy is intentionally shown in every
/// supported language so the player can make this choice before localization.
final class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key, required this.onSelected});

  final Future<void> Function(Locale locale) onSelected;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

final class _LanguageSelectionScreenState
    extends State<LanguageSelectionScreen> {
  bool _selecting = false;

  Future<void> _select(Locale locale) async {
    if (_selecting) return;
    setState(() => _selecting = true);
    await widget.onSelected(locale);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.language_rounded,
                  color: ElevenwardColors.grass,
                  size: 52,
                ),
                const SizedBox(height: 20),
                Text(
                  'Choose your language',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elige tu idioma · Escolha seu idioma · Choisissez votre langue',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ElevenwardColors.muted, height: 1.4),
                ),
                const SizedBox(height: 32),
                for (final option in _options) ...[
                  _LanguageOption(
                    label: option.label,
                    subtitle: option.subtitle,
                    onTap: _selecting ? null : () => _select(option.locale),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

const _options = <({Locale locale, String label, String subtitle})>[
  (locale: Locale('en'), label: 'English', subtitle: 'English'),
  (locale: Locale('es'), label: 'Español', subtitle: 'Spanish'),
  (
    locale: Locale('pt'),
    label: 'Português (Brasil)',
    subtitle: 'Brazilian Portuguese',
  ),
  (locale: Locale('fr'), label: 'Français', subtitle: 'French'),
];

final class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $subtitle',
    child: Material(
      color: ElevenwardColors.panelLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              const Icon(
                Icons.translate_rounded,
                color: ElevenwardColors.grass,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: ElevenwardColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ),
  );
}
