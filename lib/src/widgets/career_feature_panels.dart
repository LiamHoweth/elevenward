import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../feature_copy.dart';
import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';
import 'stat_explanation.dart';

List<(String, int)> roleStatRows(
  RoleStats stats,
  PositionFamily position,
  String locale,
) => [
  if (position == PositionFamily.midfielder ||
      position == PositionFamily.winger) ...[
    (featureCopy(locale, 'keyPasses'), stats.keyPasses),
    (featureCopy(locale, 'chancesCreated'), stats.chancesCreated),
  ],
  if (position == PositionFamily.winger)
    (featureCopy(locale, 'successfulDribbles'), stats.successfulDribbles),
  if (position == PositionFamily.defender) ...[
    (featureCopy(locale, 'tackles'), stats.tackles),
    (featureCopy(locale, 'interceptions'), stats.interceptions),
    (featureCopy(locale, 'cleanSheets'), stats.cleanSheets),
  ],
  (featureCopy(locale, 'playerOfMatchAwards'), stats.playerOfMatchAwards),
];

final class CareerRoleStatsPanel extends StatelessWidget {
  const CareerRoleStatsPanel({
    super.key,
    required this.stats,
    required this.position,
  });
  final RoleStats stats;
  final PositionFamily position;

  @override
  Widget build(BuildContext context) => BroadcastPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          featureCopy(contentLocale(context), 'roleContributions'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final row in roleStatRows(stats, position, contentLocale(context)))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(row.$1)),
                const SizedBox(width: 8),
                Text(
                  '${row.$2}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

String careerGoalTitle(String locale, CareerGoalKind kind, {int? target}) =>
    formatFeatureCopy(
      locale,
      switch (kind) {
        CareerGoalKind.appearances => 'goalAppearances',
        CareerGoalKind.goals => 'goalGoals',
        CareerGoalKind.assists => 'goalAssists',
        CareerGoalKind.cleanSheets => 'goalCleanSheets',
        CareerGoalKind.nationalSelection => 'goalNationalSelection',
        CareerGoalKind.trophy => 'goalTrophy',
        CareerGoalKind.promotion => 'goalPromotion',
      },
      {'target': target ?? careerGoalTarget(kind)},
    );

int careerGoalTarget(CareerGoalKind kind) => switch (kind) {
  CareerGoalKind.appearances => 25,
  CareerGoalKind.goals || CareerGoalKind.assists => 20,
  CareerGoalKind.cleanSheets => 10,
  _ => 1,
};

final class CareerAmbitionPanel extends StatelessWidget {
  const CareerAmbitionPanel({super.key, required this.career, this.controller});
  final CareerSnapshot career;
  final AppController? controller;

  @override
  Widget build(BuildContext context) {
    final goal = career.careerGoal;
    final locale = contentLocale(context);
    final achieved =
        goal != null &&
        (goal.completed || goal.progress(career) >= goal.target);
    return BroadcastPanel(
      accent: achieved ? ElevenwardColors.amber : ElevenwardColors.grass,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            featureCopy(
              locale,
              achieved ? 'ambitionComplete' : 'careerAmbition',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            goal == null
                ? featureCopy(locale, 'ambitionBody')
                : careerGoalTitle(locale, goal.kind, target: goal.target),
          ),
          if (goal != null) ...[
            const SizedBox(height: 9),
            LinearProgressIndicator(value: goal.progress(career) / goal.target),
            const SizedBox(height: 6),
            Text('${goal.progress(career)} / ${goal.target}'),
          ],
          if (controller != null && !career.retired) ...[
            const SizedBox(height: 9),
            OutlinedButton.icon(
              key: const Key('choose-career-ambition'),
              onPressed: controller!.busy ? null : () => _choose(context),
              icon: const Icon(Icons.flag_outlined),
              label: Text(
                featureCopy(
                  locale,
                  goal == null ? 'chooseAmbition' : 'changeAmbition',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final locale = contentLocale(context);
    final generation = controller!.activeCareerGeneration;
    final selected = await showModalBottomSheet<CareerGoalKind>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .8,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                featureCopy(locale, 'chooseAmbition'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(featureCopy(locale, 'ambitionBody')),
              const SizedBox(height: 12),
              for (final kind in CareerGoalKind.values)
                if ((kind != CareerGoalKind.nationalSelection ||
                        careerGoalValue(career, kind) == 0) &&
                    (kind != CareerGoalKind.cleanSheets ||
                        (career.usesModernCareerRules &&
                            career.player.position == PositionFamily.defender)))
                  ListTile(
                    key: Key('career-ambition-${kind.name}'),
                    leading: Icon(
                      kind == career.careerGoal?.kind
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(careerGoalTitle(locale, kind)),
                    onTap: () => Navigator.pop(context, kind),
                  ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || generation != controller!.activeCareerGeneration) {
      return;
    }
    try {
      await controller!.chooseCareerGoal(
        selected,
        target: careerGoalTarget(selected),
      );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uiCopy(locale, 'progressSaveFailed'))),
        );
      }
    }
  }
}

final class LegacyBreakdownPanel extends StatelessWidget {
  const LegacyBreakdownPanel({super.key, required this.career});
  final CareerSnapshot career;
  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final factors = legacyScoreContributions(career);
    String label(String key) => switch (key) {
      'roleContributions' || 'averageRating' => featureCopy(locale, key),
      'reputation' => uiCopy(locale, 'reputationLong'),
      'overall' => 'OVR',
      _ => uiCopy(locale, key),
    };
    return BroadcastPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  featureCopy(locale, 'legacyReasons'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              StatExplanationButton(
                stat: ExplainedStat.legacyScore,
                career: career,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final factor in factors.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(label(factor.key))),
                  const SizedBox(width: 8),
                  Text(
                    '+${factor.value.toStringAsFixed(factor.value == factor.value.roundToDouble() ? 0 : 1)}',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

final class CareerStylePanel extends StatelessWidget {
  const CareerStylePanel({super.key, required this.career, required this.club});
  final CareerSnapshot career;
  final ClubDefinition club;
  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final style = featureCopy(locale, switch (club.playingStyle) {
      ClubPlayingStyle.possession => 'stylePossession',
      ClubPlayingStyle.highPress => 'stylePressing',
      ClubPlayingStyle.counterAttack => 'styleCounter',
      ClubPlayingStyle.direct => 'styleDirect',
      ClubPlayingStyle.defensive => 'styleDefensive',
    });
    return BroadcastPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  featureCopy(locale, 'clubStyle'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              StatExplanationButton(
                stat: ExplainedStat.tacticalFit,
                career: career,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '$style · ${calculateTacticalFit(career, club)}% ${uiCopy(locale, 'fit')}',
          ),
          const SizedBox(height: 7),
          Text(featureCopy(locale, 'clubStyleBody')),
          const SizedBox(height: 14),
          Text(
            featureCopy(locale, 'ageDevelopment'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            formatFeatureCopy(locale, 'ageDevelopmentBody', {
              'age': career.player.age,
              'factor':
                  (career.usesModernCareerRules
                          ? ageDevelopmentMultiplier(career.player.age)
                          : 1.0)
                      .toStringAsFixed(2),
            }),
          ),
        ],
      ),
    );
  }
}

final class MentorStoryPanel extends StatelessWidget {
  const MentorStoryPanel({super.key, required this.career});
  final CareerSnapshot career;
  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final stage = career.storyFlags['mentor.stage'];
    final path = career.storyFlags['mentor.path'];
    final outcome = career.storyFlags['mentor.outcome'];
    return BroadcastPanel(
      accent: ElevenwardColors.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            featureCopy(locale, 'mentorStory'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            stage == null
                ? featureCopy(locale, 'mentorWaiting')
                : formatFeatureCopy(locale, 'mentorStage', {'stage': stage}),
          ),
          if (path != null) ...[
            const SizedBox(height: 7),
            Text(
              featureCopy(
                locale,
                path == 'shared' ? 'mentorAccepted' : 'mentorIndependent',
              ),
            ),
          ],
          if (outcome != null) ...[
            const SizedBox(height: 7),
            Text(
              featureCopy(locale, switch (outcome) {
                'alliance' => 'mentorAlliance',
                'respect' => 'mentorRespect',
                _ => 'mentorRivalry',
              }),
            ),
          ],
        ],
      ),
    );
  }
}
