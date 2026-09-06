import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';

final class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key, required this.career});

  final CareerSnapshot career;

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

final class _WorldScreenState extends State<WorldScreen> {
  final _definition = buildLaunchWorld();
  late String _leagueId;

  @override
  void initState() {
    super.initState();
    _leagueId = widget.career.world.leagueIdForClub(widget.career.clubId);
  }

  @override
  Widget build(BuildContext context) {
    final league = _definition.leagues.firstWhere(
      (item) => item.id == _leagueId,
    );
    final clubNames = {
      for (final club in _definition.clubs) club.id: club.name,
      for (final team in _definition.nationalTeams) team.id: team.countryName,
    };
    final clubsById = {for (final club in _definition.clubs) club.id: club};
    final table = widget.career.world.table(_leagueId);
    final locale = contentLocale(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          pinned: true,
          title: Text(context.l10n.world),
          actions: [
            PopupMenuButton<String>(
              tooltip: context.l10n.allCompetitions,
              initialValue: _leagueId,
              onSelected: (value) => setState(() => _leagueId = value),
              itemBuilder: (context) => _definition.leagues
                  .map(
                    (item) =>
                        PopupMenuItem(value: item.id, child: Text(item.name)),
                  )
                  .toList(),
              icon: const Icon(Icons.public_rounded),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          sliver: SliverList.list(
            children: [
              Text(
                league.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${localizedFootballNation(locale, league.nation)} · ${uiCopy(locale, league.division == DivisionLevel.first ? 'divisionOne' : 'divisionTwo')}',
              ),
              const SizedBox(height: 18),
              _TableHeader(label: context.l10n.leagueTable),
              ...table.indexed.map(
                (entry) => _StandingTile(
                  rank: entry.$1 + 1,
                  clubName: clubNames[entry.$2.clubId]!,
                  club: clubsById[entry.$2.clubId],
                  row: entry.$2,
                  isPlayerClub: entry.$2.clubId == widget.career.clubId,
                ),
              ),
              const SizedBox(height: 22),
              _CompetitionCard(
                icon: Icons.emoji_events_outlined,
                title: _definition.domesticCups[league.nation.index].name,
                body: uiCopy(contentLocale(context), 'cupFormat'),
                progress:
                    widget.career.world.competitions[_definition
                        .domesticCups[league.nation.index]
                        .id],
                participantNames: clubNames,
                playerId: widget.career.clubId,
              ),
              const SizedBox(height: 10),
              _CompetitionCard(
                icon: Icons.travel_explore_rounded,
                title: _definition.internationalClubCompetition.name,
                body: uiCopy(contentLocale(context), 'internationalFormat'),
                progress: widget
                    .career
                    .world
                    .competitions[_definition.internationalClubCompetition.id],
                participantNames: clubNames,
                playerId: widget.career.clubId,
              ),
              const SizedBox(height: 10),
              _CompetitionCard(
                icon: Icons.flag_outlined,
                title: context.l10n.nationalTeams,
                body:
                    '${_definition.nationalTeams.length} ${uiCopy(locale, 'countries')} · ${context.l10n.majorTournament}',
                progress: widget
                    .career
                    .world
                    .competitions['major-national-tournament'],
                participantNames: clubNames,
                playerId: widget.career.player.nationalTeamId,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: ElevenwardColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ),
        Text(
          uiCopy(contentLocale(context), 'tableColumns'),
          style: const TextStyle(color: ElevenwardColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

final class _StandingTile extends StatelessWidget {
  const _StandingTile({
    required this.rank,
    required this.clubName,
    required this.club,
    required this.row,
    required this.isPlayerClub,
  });

  final int rank;
  final String clubName;
  final ClubDefinition? club;
  final StandingRow row;
  final bool isPlayerClub;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: isPlayerClub ? ElevenwardColors.grassDark : ElevenwardColors.panel,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isPlayerClub ? ElevenwardColors.grass : ElevenwardColors.line,
      ),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '$rank',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (club != null) ...[_ClubMark(club: club!), const SizedBox(width: 9)],
        Expanded(
          child: Text(
            clubName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isPlayerClub ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text('${row.played}', textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '${row.goalDifference >= 0 ? '+' : ''}${row.goalDifference}',
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${row.points}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

final class _ClubMark extends StatelessWidget {
  const _ClubMark({required this.club});

  final ClubDefinition club;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${club.name} ${uiCopy(contentLocale(context), 'clubMark')}',
    image: true,
    child: Container(
      width: 27,
      height: 31,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(club.primaryColor),
        border: Border.all(color: Color(club.secondaryColor), width: 2),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(7),
          bottom: Radius.circular(11),
        ),
      ),
      child: Text(
        club.shortName.characters.take(2).toString().toUpperCase(),
        style: TextStyle(
          color: Color(club.secondaryColor),
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

final class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.progress,
    required this.participantNames,
    required this.playerId,
  });
  final IconData icon;
  final String title;
  final String body;
  final CompetitionProgress? progress;
  final Map<String, String> participantNames;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final competition = progress;
    final locale = contentLocale(context);
    final fixtures = competition?.fixtures.toList() ?? <Fixture>[];
    fixtures.sort((left, right) {
      final byWeek = left.matchweek.compareTo(right.matchweek);
      return byWeek != 0 ? byWeek : left.id.compareTo(right.id);
    });
    final status = competition == null
        ? uiCopy(locale, 'notScheduledThisSeason')
        : competition.winnerId != null
        ? '${uiCopy(locale, 'winner')}: ${participantNames[competition.winnerId] ?? competition.winnerId}'
        : _activeRoundLabel(locale, competition, fixtures);
    final bracketFixtures = competition == null
        ? <Fixture>[]
        : fixtures
              .where(
                (fixture) =>
                    competition.kind == CompetitionKind.domesticCup ||
                    fixture.id.contains('-r'),
              )
              .toList(growable: false);
    return Material(
      color: ElevenwardColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ElevenwardColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: ElevenwardColors.amber),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('$status · $body', style: const TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: fixtures.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(uiCopy(locale, 'noFixtures')),
                ),
              ]
            : [
                if (competition != null &&
                    competition.kind != CompetitionKind.domesticCup)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                    child: Text(
                      '${uiCopy(locale, competition.kind == CompetitionKind.internationalClub ? 'internationalQualification' : 'nationalQualification')} '
                      '${uiCopy(locale, 'groupTiebreaks')}',
                      style: const TextStyle(
                        color: ElevenwardColors.muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (bracketFixtures.isNotEmpty) ...[
                  _CompetitionBracket(
                    fixtures: bracketFixtures,
                    participantNames: participantNames,
                    playerId: playerId,
                  ),
                  const Divider(height: 24),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 3),
                    child: Text(
                      uiCopy(locale, 'allFixtures').toUpperCase(),
                      style: const TextStyle(
                        color: ElevenwardColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                ),
                ...fixtures.map(
                  (fixture) => _FixtureTile(
                    fixture: fixture,
                    homeName:
                        participantNames[fixture.homeId] ?? fixture.homeId,
                    awayName:
                        participantNames[fixture.awayId] ?? fixture.awayId,
                    highlightsPlayer:
                        fixture.homeId == playerId ||
                        fixture.awayId == playerId,
                  ),
                ),
              ],
      ),
    );
  }

  String _activeRoundLabel(
    String locale,
    CompetitionProgress competition,
    List<Fixture> fixtures,
  ) {
    if (competition.stage == 0) {
      return uiCopy(
        locale,
        competition.kind == CompetitionKind.domesticCup
            ? 'preliminaryRound'
            : 'groupStage',
      );
    }
    final knockout = fixtures.where((fixture) => fixture.id.contains('-r'));
    if (knockout.isEmpty) {
      return '${uiCopy(locale, 'stage')} ${competition.stage + 1}';
    }
    final latestWeek = knockout
        .map((fixture) => fixture.matchweek)
        .reduce((left, right) => left > right ? left : right);
    return _roundLabel(
      locale,
      knockout.where((fixture) => fixture.matchweek == latestWeek).toList(),
    );
  }
}

final class _CompetitionBracket extends StatelessWidget {
  const _CompetitionBracket({
    required this.fixtures,
    required this.participantNames,
    required this.playerId,
  });

  final List<Fixture> fixtures;
  final Map<String, String> participantNames;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final byWeek = <int, List<Fixture>>{};
    for (final fixture in fixtures) {
      byWeek.putIfAbsent(fixture.matchweek, () => []).add(fixture);
    }
    final weeks = byWeek.keys.toList()..sort();
    final locale = contentLocale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 9),
          child: Text(
            uiCopy(locale, 'knockoutBracket').toUpperCase(),
            style: const TextStyle(
              color: ElevenwardColors.amber,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: weeks
                .map((week) {
                  final roundFixtures = byWeek[week]!;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 3, bottom: 5),
                            child: Text(
                              _roundLabel(locale, roundFixtures),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          ...roundFixtures.map(
                            (fixture) => _BracketFixture(
                              fixture: fixture,
                              homeName:
                                  participantNames[fixture.homeId] ??
                                  fixture.homeId,
                              awayName:
                                  participantNames[fixture.awayId] ??
                                  fixture.awayId,
                              highlightsPlayer:
                                  fixture.homeId == playerId ||
                                  fixture.awayId == playerId,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

final class _BracketFixture extends StatelessWidget {
  const _BracketFixture({
    required this.fixture,
    required this.homeName,
    required this.awayName,
    required this.highlightsPlayer,
  });

  final Fixture fixture;
  final String homeName;
  final String awayName;
  final bool highlightsPlayer;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$homeName ${uiCopy(contentLocale(context), 'versus')} $awayName',
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: highlightsPlayer
            ? ElevenwardColors.grassDark
            : ElevenwardColors.panelLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlightsPlayer
              ? ElevenwardColors.grass
              : ElevenwardColors.line,
        ),
      ),
      child: Column(
        children: [
          _BracketTeam(
            name: homeName,
            score: fixture.homeGoals,
            winner: fixture.isPlayed && fixture.homeGoals! > fixture.awayGoals!,
          ),
          const SizedBox(height: 5),
          _BracketTeam(
            name: awayName,
            score: fixture.awayGoals,
            winner: fixture.isPlayed && fixture.awayGoals! > fixture.homeGoals!,
          ),
        ],
      ),
    ),
  );
}

final class _BracketTeam extends StatelessWidget {
  const _BracketTeam({
    required this.name,
    required this.score,
    required this.winner,
  });
  final String name;
  final int? score;
  final bool winner;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: winner ? FontWeight.w900 : FontWeight.w600,
            color: winner ? ElevenwardColors.cream : null,
          ),
        ),
      ),
      Text(
        score?.toString() ?? '—',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: winner ? ElevenwardColors.amber : ElevenwardColors.muted,
        ),
      ),
    ],
  );
}

String _roundLabel(String locale, List<Fixture> fixtures) {
  if (fixtures.any((fixture) => fixture.id.contains('preliminary'))) {
    return uiCopy(locale, 'preliminaryRound');
  }
  return uiCopy(locale, switch (fixtures.length) {
    8 => 'roundOf16',
    4 => 'quarterfinals',
    2 => 'semifinals',
    1 => 'finalRound',
    _ => 'stage',
  });
}

final class _FixtureTile extends StatelessWidget {
  const _FixtureTile({
    required this.fixture,
    required this.homeName,
    required this.awayName,
    required this.highlightsPlayer,
  });

  final Fixture fixture;
  final String homeName;
  final String awayName;
  final bool highlightsPlayer;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 5),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: highlightsPlayer
          ? ElevenwardColors.grassDark
          : ElevenwardColors.panelLight,
      borderRadius: BorderRadius.circular(10),
      border: highlightsPlayer
          ? Border.all(color: ElevenwardColors.grass)
          : null,
    ),
    child: Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            'W${fixture.matchweek}',
            style: const TextStyle(color: ElevenwardColors.muted, fontSize: 10),
          ),
        ),
        Expanded(
          child: Text(
            '$homeName  —  $awayName',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: highlightsPlayer ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fixture.isPlayed
                  ? '${fixture.homeGoals}–${fixture.awayGoals}'
                  : '—',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (fixture.isPlayed &&
                fixture.decision != FixtureDecision.regulation)
              Text(
                uiCopy(
                  contentLocale(context),
                  fixture.decision == FixtureDecision.extraTime
                      ? 'extraTimeShort'
                      : 'penaltiesShort',
                ),
                style: const TextStyle(
                  color: ElevenwardColors.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
