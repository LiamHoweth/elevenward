import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../career_engagement.dart';
import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';

final class CareerTargetPanel extends StatelessWidget {
  const CareerTargetPanel({super.key, required this.career});
  final CareerSnapshot career;

  @override
  Widget build(BuildContext context) {
    final target = careerTarget(career);
    if (target == null) return const SizedBox.shrink();
    final locale = contentLocale(context);
    final description = formatUiCopy(locale, 'targetBody', {
      'current': target.current,
      'goal': target.goal,
      'metric': milestoneLabel(locale, target.kind),
    });
    final remaining = formatUiCopy(locale, 'targetRemaining', {
      'remaining': target.goal - target.current,
      'metric': milestoneLabel(locale, target.kind),
    });
    final progressLabel = formatUiCopy(locale, 'targetProgress', {
      'goal': target.goal,
      'metric': milestoneLabel(locale, target.kind),
    });
    return BroadcastPanel(
      key: const Key('career-target-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiCopy(locale, 'personalTarget'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(description, key: const Key('career-target-description')),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            key: const Key('career-target-progress'),
            value: target.current / target.goal,
            semanticsLabel: '$progressLabel. $description. $remaining',
          ),
          const SizedBox(height: 6),
          Text(
            remaining,
            key: const Key('career-target-remaining'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            uiCopy(locale, 'targetHint'),
            style: TextStyle(color: ElevenwardColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

final class CoachingTipPanel extends StatelessWidget {
  const CoachingTipPanel({super.key, required this.copyKey, this.onDismiss});
  final String copyKey;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return BroadcastPanel(
      accent: ElevenwardColors.sky,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              uiCopy(locale, copyKey),
              style: const TextStyle(height: 1.4),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: uiCopy(locale, 'dismissTip'),
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}
