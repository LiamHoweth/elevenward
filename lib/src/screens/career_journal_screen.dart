import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../feature_copy.dart';
import '../l10n_context.dart';
import '../league_presentation.dart';
import '../match_feedback.dart';
import '../theme.dart';
import '../ui_copy.dart';
import '../widgets/career_feature_panels.dart';

final class CareerJournalScreen extends StatelessWidget {
  const CareerJournalScreen({
    super.key,
    required this.controller,
    this.archivedCareer,
  });
  final AppController controller;
  final CareerSnapshot? archivedCareer;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final career = archivedCareer ?? controller.activeCareer;
      final activeCatalog = controller.activeContent?.catalog;
      final catalog = activeCatalog?.version == career?.contentVersion
          ? activeCatalog!
          : career?.contentVersion == '2026.4.0'
          ? buildLatestContent()
          : buildLaunchContent();
      return Scaffold(
        key: const Key('career-journal-screen'),
        appBar: AppBar(
          title: Text(featureCopy(contentLocale(context), 'history')),
        ),
        body: _JournalBody(career: career, catalog: catalog),
      );
    },
  );
}

enum _JournalFilter { all, matches, decisions }

final class _JournalBody extends StatefulWidget {
  const _JournalBody({required this.career, required this.catalog});

  final CareerSnapshot? career;
  final ContentCatalog catalog;

  @override
  State<_JournalBody> createState() => _JournalBodyState();
}

final class _JournalBodyState extends State<_JournalBody> {
  _JournalFilter _filter = _JournalFilter.all;
  String? _competition;
  int? _season;

  @override
  void didUpdateWidget(covariant _JournalBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.career?.careerId != widget.career?.careerId) {
      _filter = _JournalFilter.all;
      _competition = null;
      _season = null;
    } else if (_competition != null &&
        !(widget.career?.matchJournal.any(
              (match) =>
                  _journalCompetitionKey(match, widget.catalog.world) ==
                  _competition,
            ) ??
            false)) {
      _competition = null;
    }
    if (_season != null &&
        !(widget.career?.matchJournal.any((match) => match.season == _season) ??
            false) &&
        !(widget.career?.decisionJournal.any(
              (decision) => decision.season == _season,
            ) ??
            false)) {
      _season = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final career = widget.career;
    final locale = contentLocale(context);
    final labels = _journalCompetitionLabels(widget.catalog.world, locale);
    final seasons = {
      for (final match in career?.matchJournal ?? <MatchJournalEntry>[])
        match.season,
      for (final decision
          in career?.decisionJournal ?? <DecisionJournalEntry>[])
        decision.season,
    }.toList()..sort((a, b) => b.compareTo(a));
    final competitions = {
      for (final match in career?.matchJournal ?? <MatchJournalEntry>[])
        _journalCompetitionKey(match, widget.catalog.world),
    }.toList()..sort((a, b) => labels[a]!.compareTo(labels[b]!));
    final matches = _filter == _JournalFilter.decisions
        ? <MatchJournalEntry>[]
        : (career?.matchJournal ?? <MatchJournalEntry>[])
              .where(
                (match) =>
                    (_season == null || match.season == _season) &&
                    (_filter != _JournalFilter.matches ||
                        _competition == null ||
                        _journalCompetitionKey(match, widget.catalog.world) ==
                            _competition),
              )
              .toList(growable: false);
    final decisions = _filter == _JournalFilter.matches
        ? <DecisionJournalEntry>[]
        : (career?.decisionJournal ?? <DecisionJournalEntry>[])
              .where(
                (decision) => _season == null || decision.season == _season,
              )
              .toList(growable: false);
    final hasHistory =
        career != null &&
        (career.matchJournal.isNotEmpty || career.decisionJournal.isNotEmpty);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(featureCopy(locale, 'historyLimit')),
        if (career != null) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final filter in _JournalFilter.values)
                ChoiceChip(
                  key: Key('journal-filter-${filter.name}'),
                  label: Text(_journalCopy(locale, filter.name)),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
          if (seasons.length > 1) ...[
            const SizedBox(height: 14),
            Text(
              uiCopy(locale, 'seasonLabel'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  key: const Key('journal-season-all'),
                  label: Semantics(
                    label: _journalCopy(locale, 'allSeasons'),
                    excludeSemantics: true,
                    child: Text(_journalCopy(locale, 'all')),
                  ),
                  selected: _season == null,
                  onSelected: (_) => setState(() => _season = null),
                ),
                for (final season in seasons)
                  ChoiceChip(
                    key: Key('journal-season-$season'),
                    label: Semantics(
                      label: '${uiCopy(locale, 'seasonLabel')} $season',
                      excludeSemantics: true,
                      child: Text('$season'),
                    ),
                    selected: _season == season,
                    onSelected: (_) => setState(() => _season = season),
                  ),
              ],
            ),
          ],
          if (_filter == _JournalFilter.matches && competitions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _journalCopy(locale, 'competition'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Material(
              color: ElevenwardColors.panel,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ElevenwardRadii.card),
                side: BorderSide(color: ElevenwardColors.line),
              ),
              child: RadioGroup<String>(
                groupValue: _competition ?? 'all',
                onChanged: (value) => setState(
                  () => _competition = value == 'all' ? null : value,
                ),
                child: Column(
                  children: [
                    for (final competition in ['all', ...competitions])
                      RadioListTile<String>(
                        key: Key('journal-competition-$competition'),
                        value: competition,
                        selected: competition == (_competition ?? 'all'),
                        selectedTileColor: ElevenwardColors.grassDark,
                        activeColor: ElevenwardColors.grass,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        title: competition == 'all'
                            ? Semantics(
                                label: _journalCopy(locale, 'allCompetitions'),
                                excludeSemantics: true,
                                child: Text(
                                  _journalCopy(locale, 'allCompetitionOptions'),
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                ),
                              )
                            : Text(
                                labels[competition]!,
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 18),
        if (hasHistory) ...[
          Text(
            _journalCopy(locale, 'entryCount')
                .replaceAll('{matches}', '${matches.length}')
                .replaceAll('{decisions}', '${decisions.length}'),
            key: const Key('journal-entry-count'),
            style: TextStyle(color: ElevenwardColors.muted),
          ),
          const SizedBox(height: 10),
        ],
        if (matches.isEmpty && decisions.isEmpty)
          BroadcastPanel(
            key: const Key('journal-filter-empty'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _season != null ||
                          (_filter == _JournalFilter.matches &&
                              _competition != null)
                      ? _journalCopy(locale, 'filteredEmpty')
                      : switch (_filter) {
                          _JournalFilter.all => featureCopy(
                            locale,
                            'historyEmpty',
                          ),
                          _JournalFilter.matches => _journalCopy(
                            locale,
                            'matchesEmpty',
                          ),
                          _JournalFilter.decisions => _journalCopy(
                            locale,
                            'decisionsEmpty',
                          ),
                        },
                ),
                if (hasHistory &&
                    (_filter != _JournalFilter.all || _season != null)) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('journal-show-all'),
                    onPressed: () => setState(() {
                      _filter = _JournalFilter.all;
                      _competition = null;
                      _season = null;
                    }),
                    child: Text(_journalCopy(locale, 'showAll')),
                  ),
                ],
              ],
            ),
          ),
        if (career != null) ...[
          if (matches.isNotEmpty) ...[
            Text(
              featureCopy(locale, 'recentMatches'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final match in matches)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: ElevenwardColors.panel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ElevenwardRadii.card),
                    side: BorderSide(color: ElevenwardColors.line),
                  ),
                  child: ListTile(
                    key: Key('journal-match-${match.id}'),
                    title: Text(
                      '${match.isHome ? match.clubName : match.opponentName} · ${match.isHome ? match.opponentName : match.clubName}',
                    ),
                    subtitle: Text(
                      '${labels[_journalCompetitionKey(match, widget.catalog.world)]}\n${context.l10n.seasonWeek(match.season, match.week)}\n${match.homeScore} — ${match.awayScore} · ${match.appeared ? '${match.rating.toStringAsFixed(1)} ${uiCopy(locale, 'rating')}' : featureCopy(locale, 'didNotAppear')}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => JournalMatchScreen(
                          match: match,
                          playerName: career.player.name,
                          position: career.player.position,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (decisions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              featureCopy(locale, 'careerChoices'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final decision in decisions)
              _DecisionCard(decision: decision, catalog: widget.catalog),
          ],
        ],
      ],
    );
  }
}

String _journalCompetitionKey(MatchJournalEntry match, WorldDefinition world) {
  final id = match.competitionId;
  if (world.leagues.any((league) => league.id == id) ||
      world.domesticCups.any((cup) => cup.id == id) ||
      world.internationalClubCompetition.id == id ||
      id == 'world-nations-championship' ||
      id == 'major-national-tournament') {
    return id!;
  }
  if (id?.startsWith('qualifier-') ?? false) return 'national-qualifiers';
  return 'other';
}

Map<String, String> _journalCompetitionLabels(
  WorldDefinition world,
  String locale,
) => {
  for (final league in world.leagues) league.id: leagueDisplayName(league),
  for (final cup in world.domesticCups) cup.id: cup.name,
  world.internationalClubCompetition.id:
      world.internationalClubCompetition.name,
  'world-nations-championship': uiCopy(locale, 'worldNations'),
  'major-national-tournament': uiCopy(locale, 'worldNations'),
  'national-qualifiers': uiCopy(locale, 'nationalQualifier'),
  'other': _journalCopy(locale, 'otherMatches'),
};

String _journalCopy(String locale, String key) =>
    _journalCopyValues[key]![switch (locale) {
      'es' => 1,
      'pt' || 'pt-BR' => 2,
      'fr' => 3,
      _ => 0,
    }];

const _journalCopyValues = <String, List<String>>{
  'all': ['All', 'Todo', 'Tudo', 'Tout'],
  'matches': ['Matches', 'Partidos', 'Partidas', 'Matchs'],
  'decisions': ['Decisions', 'Decisiones', 'Decisões', 'Choix'],
  'competition': ['Competition', 'Competición', 'Competição', 'Compétition'],
  'allSeasons': [
    'All seasons',
    'Todas las temporadas',
    'Todas as temporadas',
    'Toutes les saisons',
  ],
  'entryCount': [
    'Matches: {matches} · Decisions: {decisions}',
    'Partidos: {matches} · Decisiones: {decisions}',
    'Partidas: {matches} · Decisões: {decisions}',
    'Matchs : {matches} · Choix : {decisions}',
  ],
  'filteredEmpty': [
    'No entries match these filters. Try another season or competition.',
    'Ningún registro coincide con estos filtros. Prueba otra temporada o competición.',
    'Nenhum registro corresponde a estes filtros. Tente outra temporada ou competição.',
    'Aucune entrée ne correspond à ces filtres. Essayez une autre saison ou compétition.',
  ],
  'noStatChanges': [
    'No stat changes from this choice.',
    'Esta decisión no cambió las estadísticas.',
    'Esta escolha não alterou as estatísticas.',
    'Ce choix n’a pas modifié les statistiques.',
  ],
  'allCompetitionOptions': ['All', 'Todas', 'Todas', 'Toutes'],
  'allCompetitions': [
    'All competitions',
    'Todas las competiciones',
    'Todas as competições',
    'Toutes les compétitions',
  ],
  'otherMatches': [
    'Other matches',
    'Otros partidos',
    'Outras partidas',
    'Autres matchs',
  ],
  'matchesEmpty': [
    'No matches recorded yet. Completed matches will appear here.',
    'Aún no hay partidos registrados. Los partidos completados aparecerán aquí.',
    'Ainda não há partidas registradas. As partidas concluídas aparecerão aqui.',
    'Aucun match enregistré pour le moment. Les matchs terminés apparaîtront ici.',
  ],
  'decisionsEmpty': [
    'No decisions recorded yet. Confirmed career choices will appear here.',
    'Aún no hay decisiones registradas. Las elecciones de carrera confirmadas aparecerán aquí.',
    'Ainda não há decisões registradas. As escolhas de carreira confirmadas aparecerão aqui.',
    'Aucun choix enregistré pour le moment. Les choix de carrière confirmés apparaîtront ici.',
  ],
  'showAll': [
    'Show all history',
    'Ver todo el historial',
    'Ver todo o histórico',
    'Afficher tout l’historique',
  ],
};

final class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.decision, required this.catalog});
  final DecisionJournalEntry decision;
  final ContentCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final event = const CareerEngine().eventById(decision.eventId, catalog);
    final choice = event?.choices
        .where((item) => item.id == decision.choiceId)
        .firstOrNull;
    final effects = decision.effects.entries
        .where((effect) => effect.value != 0)
        .toList(growable: false);
    final outcome =
        choice?.outcome?.forLocale(locale) ??
        (locale == 'en' ? decision.outcome : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BroadcastPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event?.title.forLocale(locale) ?? decision.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              context.l10n.seasonWeek(decision.season, decision.week),
              style: TextStyle(color: ElevenwardColors.muted),
            ),
            const SizedBox(height: 7),
            Text(choice?.label.forLocale(locale) ?? decision.choiceLabel),
            if (outcome.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(outcome),
            ],
            if (effects.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                featureCopy(locale, 'choiceEffects'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              for (final effect in effects)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${uiCopy(locale, switch (effect.key) {
                      'money' => 'income',
                      'reputation' => 'reputationLong',
                      _ => effect.key,
                    })}: ${effect.value >= 0 ? '+' : ''}${['money', 'weeklyWage', 'appearanceBonus'].contains(effect.key) ? '£' : ''}${effect.value}',
                  ),
                ),
            ] else if (decision.effects.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(_journalCopy(locale, 'noStatChanges')),
            ],
          ],
        ),
      ),
    );
  }
}

final class JournalMatchScreen extends StatelessWidget {
  const JournalMatchScreen({
    super.key,
    required this.match,
    required this.playerName,
    required this.position,
  });
  final MatchJournalEntry match;
  final String playerName;
  final PositionFamily position;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final home = match.isHome ? match.clubName : match.opponentName;
    final away = match.isHome ? match.opponentName : match.clubName;
    return Scaffold(
      key: const Key('journal-match-screen'),
      appBar: AppBar(title: Text(featureCopy(locale, 'matchDetail'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BroadcastPanel(
            child: Column(
              children: [
                Text(home, textAlign: TextAlign.center),
                Text(
                  '${match.homeScore} — ${match.awayScore}',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                Text(away, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(context.l10n.seasonWeek(match.season, match.week)),
                const SizedBox(height: 12),
                Text(
                  journalMatchHeadline(match, locale),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(journalMatchReport(match, locale, playerName)),
          const SizedBox(height: 16),
          Text(
            '${match.goals} ${uiCopy(locale, 'goals')} · ${match.assists} ${uiCopy(locale, 'assists')} · ${match.appeared ? '${match.rating.toStringAsFixed(1)} ${uiCopy(locale, 'rating')}' : featureCopy(locale, 'didNotAppear')}',
          ),
          const SizedBox(height: 16),
          CareerRoleStatsPanel(stats: match.roleStats, position: position),
        ],
      ),
    );
  }
}
