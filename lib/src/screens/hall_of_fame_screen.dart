import 'dart:async';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../feature_copy.dart';
import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';
import '../widgets/career_feature_panels.dart';
import '../widgets/identity_badge.dart';
import 'career_journal_screen.dart';

final class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

final class _HallOfFameScreenState extends State<HallOfFameScreen> {
  late Future<List<CareerSnapshot>> _careers;
  late int _archiveGeneration;
  final Set<String> _removingCareers = {};
  @override
  void initState() {
    super.initState();
    _careers = widget.controller.localHallOfFame();
    _archiveGeneration = widget.controller.archiveGeneration;
    widget.controller.addListener(_archivesChanged);
    unawaited(widget.controller.refreshHallOfFame());
  }

  void _archivesChanged() {
    if (_archiveGeneration == widget.controller.archiveGeneration) return;
    _archiveGeneration = widget.controller.archiveGeneration;
    _reload();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_archivesChanged);
    super.dispose();
  }

  void _reload() {
    setState(() {
      _careers = widget.controller.localHallOfFame();
    });
  }

  Future<void> _refresh() async {
    await widget.controller.refreshHallOfFame();
    if (!mounted) return;
    final next = widget.controller.localHallOfFame();
    setState(() {
      _careers = next;
    });
    await next;
  }

  Future<void> _retrySync() async {
    await widget.controller.synchronize();
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Scaffold(
      key: const Key('hall-of-fame-screen'),
      appBar: AppBar(title: Text(featureCopy(locale, 'hallOfFame'))),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => FutureBuilder<List<CareerSnapshot>>(
          future: _careers,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(featureCopy(locale, 'loadFailed')),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _reload,
                        child: Text(
                          MaterialLocalizations.of(context)
                              .refreshIndicatorSemanticLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(featureCopy(locale, 'hallBody')),
                  if (widget.controller.archiveBackupPending ||
                      (widget.controller.account != null &&
                          widget.controller.syncStatus ==
                              SyncUiStatus.failed)) ...[
                    const SizedBox(height: 10),
                    Text(featureCopy(locale, 'archiveBackupPending')),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: widget.controller.busy ? null : _retrySync,
                        child: Text(uiCopy(locale, 'retrySync')),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (snapshot.data!.isEmpty)
                    BroadcastPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            color: ElevenwardColors.amber,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(featureCopy(locale, 'hallEmpty')),
                        ],
                      ),
                    ),
                  for (final career in snapshot.data!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ArchivedCareerCard(
                        career: career,
                        removing: _removingCareers.contains(career.careerId),
                        onOpen: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ArchivedCareerScreen(
                              controller: widget.controller,
                              career: career,
                            ),
                          ),
                        ),
                        onRemove: () => _remove(career),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _remove(CareerSnapshot career) async {
    if (_removingCareers.contains(career.careerId)) return;
    setState(() => _removingCareers.add(career.careerId));
    final locale = contentLocale(context);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(featureCopy(locale, 'deleteArchive')),
          scrollable: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                career.player.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(career.clubName),
              const SizedBox(height: 12),
              Text(featureCopy(locale, 'deleteArchiveBody')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(featureCopy(locale, 'remove')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.controller.deleteArchivedCareer(career.careerId);
      if (mounted) _reload();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(featureCopy(locale, 'archiveDeleteFailed'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _removingCareers.remove(career.careerId));
      }
    }
  }
}

final class _ArchivedCareerCard extends StatelessWidget {
  const _ArchivedCareerCard({
    required this.career,
    required this.removing,
    required this.onOpen,
    required this.onRemove,
  });

  final CareerSnapshot career;
  final bool removing;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final verdict = calculateLegacyVerdict(career);
    return BroadcastPanel(
      accent: ElevenwardColors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: PlayerIdentityBadge(
                  playerName: career.player.name,
                  portraitId: career.player.portraitId,
                  avatarId: 'initials',
                  size: 48,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      career.player.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(career.clubName),
                    Text(
                      localizedPosition(locale, career.player.position.name),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            uiCopy(locale, 'legacyScore'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${verdict.score} · ${localizedLegacyTier(locale, verdict.tier)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ElevenwardColors.amber,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${career.seasonHistory.length} ${uiCopy(locale, 'seasons')} · '
            '${career.player.appearances} ${uiCopy(locale, 'appearances')}',
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            key: Key('archived-career-${career.careerId}'),
            onPressed: onOpen,
            child: Text(
              uiCopy(locale, 'viewLegacy'),
              textAlign: TextAlign.center,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: Key('remove-archived-career-${career.careerId}'),
              onPressed: removing ? null : onRemove,
              icon: const Icon(Icons.delete_outline),
              label: Text(featureCopy(locale, 'remove')),
            ),
          ),
        ],
      ),
    );
  }
}

final class ArchivedCareerScreen extends StatelessWidget {
  const ArchivedCareerScreen({
    super.key,
    required this.controller,
    required this.career,
  });
  final AppController controller;
  final CareerSnapshot career;
  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final verdict = calculateLegacyVerdict(career);
    return Scaffold(
      key: const Key('archived-career-screen'),
      appBar: AppBar(title: Text(career.player.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: PlayerIdentityBadge(
              playerName: career.player.name,
              portraitId: career.player.portraitId,
              avatarId: 'initials',
              size: 96,
            ),
          ),
          const SizedBox(height: 18),
          BroadcastPanel(
            accent: ElevenwardColors.amber,
            child: Column(
              children: [
                Text(
                  uiCopy(locale, 'legacyScore'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${verdict.score}',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                Text(localizedLegacyTier(locale, verdict.tier)),
                const SizedBox(height: 8),
                Text(
                  localizedLegacyHeadline(locale, verdict.tier),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LegacyBreakdownPanel(career: career),
          const SizedBox(height: 14),
          BroadcastPanel(
            key: const Key('archived-career-totals'),
            child: _ArchiveStatRows(
              rows: [
                (uiCopy(locale, 'apps'), '${career.player.appearances}'),
                (uiCopy(locale, 'goals'), '${career.player.goals}'),
                (uiCopy(locale, 'assists'), '${career.player.assists}'),
                (
                  uiCopy(locale, 'trophies'),
                  '${career.seasonHistory.fold<int>(0, (total, season) => total + season.trophies.length)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CareerRoleStatsPanel(
            stats: career.roleStats,
            position: career.player.position,
          ),
          if (career.careerGoal != null) ...[
            const SizedBox(height: 14),
            CareerAmbitionPanel(career: career),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => CareerJournalScreen(
                  controller: controller,
                  archivedCareer: career,
                ),
              ),
            ),
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(featureCopy(locale, 'history')),
          ),
          if (career.seasonHistory.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              uiCopy(locale, 'archive'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
          ],
          for (final season in career.seasonHistory)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BroadcastPanel(
                key: Key('archived-season-${season.season}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${uiCopy(locale, 'season')} ${season.season}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _ArchiveStatRows(
                      rows: [
                        (uiCopy(locale, 'apps'), '${season.appearances}'),
                        (uiCopy(locale, 'goals'), '${season.goals}'),
                        (uiCopy(locale, 'assists'), '${season.assists}'),
                        (
                          uiCopy(locale, 'rating'),
                          season.averageRating.toStringAsFixed(1),
                        ),
                        (
                          uiCopy(locale, 'trophies'),
                          '${season.trophies.length}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _ArchiveStatRows extends StatelessWidget {
  const _ArchiveStatRows({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(row.$1)),
                const SizedBox(width: 12),
                Text(
                  row.$2,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
