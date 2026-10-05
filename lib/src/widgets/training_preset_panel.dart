import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../l10n_context.dart';
import '../online_copy.dart';
import '../theme.dart';
import '../training_preset.dart';
import '../ui_copy.dart';

/// A controlled favorite: the owner publishes it only after durable storage.
final class TrainingPresetPanel extends StatefulWidget {
  const TrainingPresetPanel({
    super.key,
    required this.focus,
    required this.intensity,
    this.preset,
    required this.onSave,
    required this.onClear,
    required this.onApply,
    this.enabled = true,
  });

  final PlayerAttribute focus;
  final TrainingIntensity intensity;
  final TrainingPreset? preset;
  final Future<void> Function(TrainingPreset) onSave;
  final Future<void> Function() onClear;
  final void Function(TrainingPreset) onApply;
  final bool enabled;

  @override
  State<TrainingPresetPanel> createState() => _TrainingPresetPanelState();
}

class _TrainingPresetPanelState extends State<TrainingPresetPanel> {
  _PresetWrite? _pending;
  _PresetWrite? _failed;
  TrainingPreset? _failedPreset;

  bool get _enabled => widget.enabled && _pending == null;

  Future<void> _write(_PresetWrite action, [TrainingPreset? preset]) async {
    if (!_enabled) return;
    setState(() {
      _pending = action;
      _failed = null;
      _failedPreset = null;
    });
    try {
      if (action == _PresetWrite.save) {
        await widget.onSave(preset!);
      } else {
        await widget.onClear();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = action;
        _failedPreset = preset;
      });
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final preset = widget.preset;
    final matches =
        preset != null &&
        preset.focus == widget.focus &&
        preset.intensity == widget.intensity;
    final status = preset == null
        ? _copy(locale, 'empty')
        : '${localizedPlayerAttribute(locale, preset.focus)} · ${_loadName(locale, preset.intensity)}';

    return BroadcastPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bookmark_outline, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _copy(locale, 'title'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(status, key: const Key('training-preset-summary')),
          if (matches) ...[
            const SizedBox(height: 10),
            Row(
              key: const Key('training-preset-active'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, color: ElevenwardColors.grass),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _copy(locale, 'using'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ] else if (preset != null) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('apply-training-preset'),
              onPressed: _enabled && !matches
                  ? () => widget.onApply(preset)
                  : null,
              icon: Icon(matches ? Icons.check : Icons.play_arrow_rounded),
              label: Text(_copy(locale, matches ? 'using' : 'apply')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
          if (!matches || _pending == _PresetWrite.save) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('save-training-preset'),
              onPressed: _enabled && !matches
                  ? () => _write(
                      _PresetWrite.save,
                      TrainingPreset(
                        focus: widget.focus,
                        intensity: widget.intensity,
                      ),
                    )
                  : null,
              icon: _pending == _PresetWrite.save
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_outlined),
              label: Text(
                _copy(
                  locale,
                  _pending == _PresetWrite.save
                      ? 'saving'
                      : preset == null
                      ? 'save'
                      : 'replace',
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
          if (preset != null)
            TextButton(
              key: const Key('clear-training-preset'),
              onPressed: _enabled ? () => _write(_PresetWrite.clear) : null,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                _copy(
                  locale,
                  _pending == _PresetWrite.clear ? 'clearing' : 'clear',
                ),
              ),
            ),
          if (_failed != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _copy(
                  locale,
                  _failed == _PresetWrite.save ? 'saveError' : 'clearError',
                ),
                key: const Key('training-preset-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              key: const Key('retry-training-preset'),
              onPressed: _enabled
                  ? () => _write(_failed!, _failedPreset)
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(_copy(locale, 'retry')),
            ),
          ],
        ],
      ),
    );
  }
}

enum _PresetWrite { save, clear }

String _loadName(String locale, TrainingIntensity intensity) =>
    switch (intensity) {
      TrainingIntensity.light => onlineCopy(locale, 'trainingLight'),
      TrainingIntensity.balanced => uiCopy(locale, 'balanced'),
      TrainingIntensity.intensive => onlineCopy(locale, 'trainingIntensive'),
    };

String _copy(String locale, String key) =>
    _presetCopy[key]![switch (locale) {
      'es' => 1,
      'pt-BR' || 'pt' => 2,
      'fr' => 3,
      _ => 0,
    }];

const _presetCopy = <String, List<String>>{
  'title': [
    'Favorite training',
    'Entrenamiento favorito',
    'Treino favorito',
    'Entraînement favori',
  ],
  'empty': [
    'Save your current focus and load for quick use next week.',
    'Guarda tu enfoque y carga actuales para usarlos la próxima semana.',
    'Salve seu foco e carga atuais para usar na próxima semana.',
    'Enregistrez votre priorité et votre charge pour la semaine prochaine.',
  ],
  'apply': [
    'Use favorite',
    'Usar favorito',
    'Usar favorito',
    'Utiliser le favori',
  ],
  'using': [
    'Using favorite',
    'Favorito en uso',
    'Favorito em uso',
    'Favori utilisé',
  ],
  'save': [
    'Save current settings',
    'Guardar ajustes actuales',
    'Salvar ajustes atuais',
    'Enregistrer ces réglages',
  ],
  'replace': [
    'Replace with current settings',
    'Reemplazar con ajustes actuales',
    'Substituir pelos ajustes atuais',
    'Remplacer par ces réglages',
  ],
  'clear': [
    'Remove favorite',
    'Eliminar favorito',
    'Remover favorito',
    'Supprimer le favori',
  ],
  'saving': ['Saving…', 'Guardando…', 'Salvando…', 'Enregistrement…'],
  'clearing': ['Removing…', 'Eliminando…', 'Removendo…', 'Suppression…'],
  'saveError': [
    'Couldn’t save your favorite. Try again.',
    'No se pudo guardar tu favorito. Inténtalo de nuevo.',
    'Não foi possível salvar seu favorito. Tente novamente.',
    'Impossible d’enregistrer votre favori. Réessayez.',
  ],
  'clearError': [
    'Couldn’t remove your favorite. Try again.',
    'No se pudo eliminar tu favorito. Inténtalo de nuevo.',
    'Não foi possível remover seu favorito. Tente novamente.',
    'Impossible de supprimer votre favori. Réessayez.',
  ],
  'retry': ['Try again', 'Reintentar', 'Tentar novamente', 'Réessayer'],
};
