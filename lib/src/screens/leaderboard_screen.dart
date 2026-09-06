import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';

final class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

final class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late PositionFamily _position;
  late Difficulty _difficulty;
  late Future<List<Map<String, Object?>>> _entries;

  @override
  void initState() {
    super.initState();
    final career = widget.controller.activeCareer;
    _position = career?.player.position ?? PositionFamily.striker;
    _difficulty = career?.difficulty ?? Difficulty.professional;
    _refresh();
  }

  void _refresh() {
    _entries = widget.controller.sync.leaderboard(
      position: _position,
      difficulty: _difficulty,
      rulesVersion:
          widget.controller.activeCareer?.rulesVersion ??
          CareerSnapshot.currentRulesVersion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Scaffold(
      appBar: AppBar(title: Text(uiCopy(locale, 'leaderboards'))),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_refresh);
          try {
            await _entries;
          } on Object {
            // The FutureBuilder owns the visible retry/offline state.
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              uiCopy(locale, 'leaderboardNoPrizes'),
              style: const TextStyle(color: ElevenwardColors.muted),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PositionFamily>(
              initialValue: _position,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: PositionFamily.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(localizedPosition(locale, value.name)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _position = value;
                  _refresh();
                });
              },
            ),
            const SizedBox(height: 10),
            SegmentedButton<Difficulty>(
              segments: Difficulty.values
                  .map(
                    (value) => ButtonSegment(
                      value: value,
                      label: Text(_difficultyLabel(context, value)),
                    ),
                  )
                  .toList(),
              selected: {_difficulty},
              showSelectedIcon: false,
              onSelectionChanged: (values) {
                setState(() {
                  _difficulty = values.single;
                  _refresh();
                });
              },
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<Map<String, Object?>>>(
              future: _entries,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _MessageCard(
                    icon: Icons.cloud_off_outlined,
                    text: uiCopy(locale, 'leaderboardOffline'),
                  );
                }
                final entries = snapshot.data ?? const [];
                if (entries.isEmpty) {
                  return _MessageCard(
                    icon: Icons.emoji_events_outlined,
                    text: uiCopy(locale, 'noLeaderboardEntries'),
                  );
                }
                return Column(
                  children: entries
                      .map((entry) => _EntryTile(entry: entry))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _difficultyLabel(BuildContext context, Difficulty value) =>
      switch (value) {
        Difficulty.story => context.l10n.story,
        Difficulty.professional => context.l10n.professional,
        Difficulty.worldClass => context.l10n.worldClass,
      };
}

final class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final Map<String, Object?> entry;

  @override
  Widget build(BuildContext context) {
    final rank = entry['rank'] as int? ?? 0;
    final score = entry['legacyScore'] as int? ?? 0;
    final metrics = entry['aggregateMetrics'] is Map
        ? (entry['aggregateMetrics'] as Map).cast<String, Object?>()
        : const <String, Object?>{};
    return Semantics(
      label: 'Rank $rank, ${entry['alias']}, $score points',
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: rank <= 3
                ? ElevenwardColors.amber
                : ElevenwardColors.panelLight,
            foregroundColor: ElevenwardColors.ink,
            child: Text('$rank'),
          ),
          title: Text(
            entry['alias'] as String? ?? 'Anonymous',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${metrics['seasons'] ?? 0} seasons · '
            '${metrics['trophies'] ?? 0} trophies',
          ),
          trailing: Text(
            '$score',
            style: const TextStyle(
              color: ElevenwardColors.grass,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

final class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: ElevenwardColors.panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ElevenwardColors.line),
    ),
    child: Column(
      children: [
        Icon(icon, color: ElevenwardColors.muted),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}
