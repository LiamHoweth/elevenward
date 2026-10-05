import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../l10n_context.dart';
import '../online_copy.dart';
import '../theme.dart';
import '../ui_copy.dart';

/// Descriptive display bands, not simulation or injury thresholds.
enum FitnessBand { low, moderate, high }

FitnessBand fitnessBandFor(int fitness) => switch (fitness) {
  < 50 => FitnessBand.low,
  < 80 => FitnessBand.moderate,
  _ => FitnessBand.high,
};

/// Reads the exact core preview without recalculating training or match effects.
final class FitnessGuidance extends StatelessWidget {
  const FitnessGuidance({
    super.key,
    required this.preview,
    this.focus,
    this.intensity,
    this.loadPreviews = const {},
    this.onIntensityChanged,
  });

  final TrainingPreview preview;
  final PlayerAttribute? focus;
  final TrainingIntensity? intensity;
  final Map<TrainingIntensity, TrainingPreview> loadPreviews;
  final ValueChanged<TrainingIntensity>? onIntensityChanged;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final band = fitnessBandFor(preview.fitnessAfter);
    final bandLabel = _copy(locale, band.name);
    final range = switch (band) {
      FitnessBand.low => '1–49',
      FitnessBand.moderate => '50–79',
      FitnessBand.high => '80–100',
    };
    final accent = switch (band) {
      FitnessBand.low => ElevenwardColors.coral,
      FitnessBand.moderate => ElevenwardColors.amber,
      FitnessBand.high => ElevenwardColors.grass,
    };
    final icon = switch (band) {
      FitnessBand.low => Icons.battery_2_bar_rounded,
      FitnessBand.moderate => Icons.battery_5_bar_rounded,
      FitnessBand.high => Icons.battery_full_rounded,
    };
    final advice = preview.paused
        ? uiCopy(locale, 'nationalMatchdayPaused')
        : _copy(
            locale,
            preview.fitnessChange > 0
                ? 'recovering'
                : preview.fitnessChange < 0
                ? 'cost'
                : preview.fitnessAfter == 100
                ? 'maximum'
                : preview.fitnessAfter < 50
                ? 'lowHint'
                : 'unchanged',
          );
    final semantics = _copy(locale, 'semantics')
        .replaceAll('{before}', '${preview.fitnessBefore}')
        .replaceAll('{after}', '${preview.fitnessAfter}')
        .replaceAll('{band}', bandLabel);
    final guidance = Semantics(
      label: '$semantics $advice',
      excludeSemantics: true,
      child: Container(
        key: const Key('fitness-guidance'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ElevenwardColors.deep,
          borderRadius: BorderRadius.circular(ElevenwardRadii.control),
          border: Border.all(color: ElevenwardColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _copy(locale, 'projected'),
              style: TextStyle(
                color: ElevenwardColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${preview.fitnessBefore} → ${preview.fitnessAfter} / 100',
                  key: const Key('fitness-guidance-values'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: accent, size: 16),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '$bandLabel · $range',
                          key: const Key('fitness-guidance-band'),
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              advice,
              style: TextStyle(color: ElevenwardColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
    if (loadPreviews.isEmpty || preview.paused) return guidance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        guidance,
        _TrainingLoadComparison(
          focus: focus,
          intensity: intensity,
          previews: loadPreviews,
          onChanged: onIntensityChanged,
        ),
      ],
    );
  }
}

/// Shows supplied core projections; selecting a row changes the weekly choice.
final class _TrainingLoadComparison extends StatefulWidget {
  const _TrainingLoadComparison({
    required this.focus,
    required this.intensity,
    required this.previews,
    required this.onChanged,
  });

  final PlayerAttribute? focus;
  final TrainingIntensity? intensity;
  final Map<TrainingIntensity, TrainingPreview> previews;
  final ValueChanged<TrainingIntensity>? onChanged;

  @override
  State<_TrainingLoadComparison> createState() =>
      _TrainingLoadComparisonState();
}

class _TrainingLoadComparisonState extends State<_TrainingLoadComparison> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final attribute = widget.focus == null
        ? _copy(locale, 'attribute')
        : localizedPlayerAttribute(locale, widget.focus!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          key: const Key('training-load-comparison-toggle'),
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          label: Text(_copy(locale, _expanded ? 'hideLoads' : 'compareLoads')),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            alignment: Alignment.centerLeft,
          ),
        ),
        if (_expanded) ...[
          Text(
            uiCopy(locale, 'trainingOnly'),
            style: TextStyle(color: ElevenwardColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final load in TrainingIntensity.values)
            if (widget.previews[load] case final preview?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _loadRow(locale, attribute, load, preview),
              ),
        ],
      ],
    );
  }

  Widget _loadRow(
    String locale,
    String attribute,
    TrainingIntensity load,
    TrainingPreview preview,
  ) {
    final selected = widget.intensity == load;
    final canChoose = widget.onChanged != null && !preview.paused;
    final label = switch (load) {
      TrainingIntensity.light => onlineCopy(locale, 'trainingLight'),
      TrainingIntensity.balanced => uiCopy(locale, 'balanced'),
      TrainingIntensity.intensive => onlineCopy(locale, 'trainingIntensive'),
    };
    final fitness =
        '${_copy(locale, 'fitness')} ${preview.fitnessBefore} → ${preview.fitnessAfter} / 100';
    final development =
        '$attribute ${preview.attributeBefore} → ${preview.attributeAfter}';
    // Floor the displayed percentage: a fractional point must never appear
    // complete before the engine has awarded it. Attribute caps have no next
    // point, so retained legacy remainders are not shown there.
    final progress = preview.attributeAfter < 99 && preview.remainder > 0
        ? _copy(locale, 'nextPoint').replaceAll(
            '{progress}',
            preview.remainder < .01
                ? '<1'
                : '${(preview.remainder * 100).floor().clamp(0, 99)}',
          )
        : null;
    final summary =
        '$development. $fitness.${progress == null ? '' : ' $progress'}';
    return Semantics(
      key: Key('training-compare-${load.name}'),
      label: '$label. $summary',
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: canChoose,
      enabled: canChoose,
      onTap: canChoose ? () => widget.onChanged!(load) : null,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? ElevenwardColors.grass.withValues(alpha: .10)
            : ElevenwardColors.deep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElevenwardRadii.control),
          side: BorderSide(
            color: selected ? ElevenwardColors.grass : ElevenwardColors.line,
          ),
        ),
        child: InkWell(
          onTap: canChoose ? () => widget.onChanged!(load) : null,
          borderRadius: BorderRadius.circular(ElevenwardRadii.control),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected
                      ? ElevenwardColors.grass
                      : ElevenwardColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(development),
                      Text(fitness),
                      if (progress != null)
                        Text(
                          progress,
                          style: TextStyle(
                            color: ElevenwardColors.muted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _copy(String locale, String key) =>
    _translations[key]![locale] ?? _translations[key]!['en']!;

const _translations = <String, Map<String, String>>{
  'fitness': {
    'en': 'Fitness',
    'es': 'Forma física',
    'pt-BR': 'Condicionamento',
    'fr': 'Condition physique',
  },
  'compareLoads': {
    'en': 'Compare training loads',
    'es': 'Comparar cargas de entrenamiento',
    'pt-BR': 'Comparar cargas de treino',
    'fr': 'Comparer les charges d’entraînement',
  },
  'hideLoads': {
    'en': 'Hide comparison',
    'es': 'Ocultar comparación',
    'pt-BR': 'Ocultar comparação',
    'fr': 'Masquer la comparaison',
  },
  'attribute': {
    'en': 'Attribute',
    'es': 'Atributo',
    'pt-BR': 'Atributo',
    'fr': 'Attribut',
  },
  'nextPoint': {
    'en': 'Progress after training: {progress}% toward the next point.',
    'es': 'Progreso tras el entrenamiento: {progress}% para el próximo punto.',
    'pt-BR': 'Progresso após o treino: {progress}% para o próximo ponto.',
    'fr': 'Progression après l’entraînement : {progress}% vers le prochain point.',
  },
  'projected': {
    'en': 'Fitness after training',
    'es': 'Forma física tras el entrenamiento',
    'pt-BR': 'Condicionamento após o treino',
    'fr': 'Condition physique après l’entraînement',
  },
  'low': {'en': 'Low', 'es': 'Baja', 'pt-BR': 'Baixo', 'fr': 'Faible'},
  'moderate': {
    'en': 'Moderate',
    'es': 'Moderada',
    'pt-BR': 'Moderado',
    'fr': 'Modérée',
  },
  'high': {'en': 'High', 'es': 'Alta', 'pt-BR': 'Alto', 'fr': 'Élevée'},
  'recovering': {
    'en': 'This load restores fitness.',
    'es': 'Esta carga recupera la forma física.',
    'pt-BR': 'Esta carga recupera o condicionamento.',
    'fr': 'Cette intensité améliore la condition physique.',
  },
  'cost': {
    'en': 'This load costs fitness. Light training helps recovery.',
    'es': 'Esta carga reduce la forma física. El entrenamiento ligero ayuda a recuperarla.',
    'pt-BR': 'Esta carga reduz o condicionamento. O treino leve ajuda na recuperação.',
    'fr': 'Cette intensité réduit la condition physique. Un entraînement léger favorise la récupération.',
  },
  'maximum': {
    'en': 'Fitness is at its maximum.',
    'es': 'La forma física está al máximo.',
    'pt-BR': 'O condicionamento está no máximo.',
    'fr': 'La condition physique est au maximum.',
  },
  'lowHint': {
    'en': 'Try light training to restore fitness.',
    'es': 'Prueba un entrenamiento ligero para recuperar la forma física.',
    'pt-BR': 'Experimente um treino leve para recuperar o condicionamento.',
    'fr': 'Essayez un entraînement léger pour retrouver votre condition physique.',
  },
  'unchanged': {
    'en': 'Fitness stays the same with this load.',
    'es': 'La forma física no cambia con esta carga.',
    'pt-BR': 'O condicionamento não muda com esta carga.',
    'fr': 'La condition physique reste identique avec cette intensité.',
  },
  'semantics': {
    'en': 'Fitness: {before} out of 100. After training: {after} out of 100, {band}.',
    'es': 'Forma física: {before} de 100. Tras el entrenamiento: {after} de 100, {band}.',
    'pt-BR': 'Condicionamento: {before} de 100. Após o treino: {after} de 100, {band}.',
    'fr': 'Condition physique : {before} sur 100. Après l’entraînement : {after} sur 100, {band}.',
  },
};
