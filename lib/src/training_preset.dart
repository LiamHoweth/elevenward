import 'package:elevenward_core/elevenward_core.dart';

/// A device-local shortcut, separate from each career's saved weekly focus.
final class TrainingPreset {
  const TrainingPreset({required this.focus, required this.intensity});

  final PlayerAttribute focus;
  final TrainingIntensity intensity;

  /// Unknown or malformed preferences never change a career's training choice.
  static TrainingPreset? fromJson(Object? value) {
    if (value is! Map) return null;
    final focus = PlayerAttribute.values
        .where((candidate) => candidate.name == value['focus'])
        .firstOrNull;
    final intensity = TrainingIntensity.values
        .where((candidate) => candidate.name == value['intensity'])
        .firstOrNull;
    if (focus == null || intensity == null) return null;
    return TrainingPreset(focus: focus, intensity: intensity);
  }

  Map<String, Object?> toJson() => {
    'focus': focus.name,
    'intensity': intensity.name,
  };

  @override
  bool operator ==(Object other) =>
      other is TrainingPreset &&
      other.focus == focus &&
      other.intensity == intensity;

  @override
  int get hashCode => Object.hash(focus, intensity);
}
