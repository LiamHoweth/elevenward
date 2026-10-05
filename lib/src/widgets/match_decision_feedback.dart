import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../l10n_context.dart';
import '../match_feedback.dart';
import '../theme.dart';

/// A compact recap of the saved decision and its original, evidence-backed odds.
final class MatchDecisionFeedback extends StatelessWidget {
  const MatchDecisionFeedback({super.key, required this.result});

  final WeeklyResult result;

  @override
  Widget build(BuildContext context) {
    final summary = matchDecisionSummary(result, contentLocale(context));
    return BroadcastPanel(
      key: const Key('match-decision-feedback'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (summary.probability case final probability?) ...[
            const SizedBox(height: 8),
            Text(probability, key: const Key('match-decision-probability')),
          ],
          const SizedBox(height: 8),
          Text(
            summary.outcome,
            key: const Key('match-decision-outcome'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final influence in summary.influences)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(influence),
            ),
          const SizedBox(height: 8),
          Text(
            summary.context,
            style: TextStyle(color: ElevenwardColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
