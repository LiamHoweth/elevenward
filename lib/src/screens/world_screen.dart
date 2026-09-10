import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../l10n_context.dart';
import '../league_presentation.dart';
import '../theme.dart';
import '../ui_copy.dart';
import '../widgets/football_world_map.dart';
import '../widgets/identity_badge.dart';

typedef _WorldRegion = FootballMapRegion;

final class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key, required this.career, this.definition})
    : initialLeagueId = null,
      highlightClubId = null;

  const WorldScreen.league({
    super.key,
    required this.career,
    required this.initialLeagueId,
    this.definition,
    this.highlightClubId,
  });

  final CareerSnapshot career;
  final String? initialLeagueId;
  final String? highlightClubId;
  final WorldDefinition? definition;

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

final class _WorldScreenState extends State<WorldScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _rankingSearch = TextEditingController();
  late String _leagueId;
  FootballMapRegion? _rankingRegion;
  String? _rankingCountryId;
  DivisionLevel? _rankingDivision;
  int? _statisticsRevision;
  String? _statisticsContentVersion;
  WorldDefinition? _statisticsDefinition;
  WorldSeasonStatistics? _cachedStatistics;

  WorldDefinition get _definition => widget.definition ?? buildLaunchWorld();

  String get _playerCountryId =>
      _definition.nationalTeam(widget.career.player.nationalTeamId).countryId;

  String get _clubCountryId => _definition.club(widget.career.clubId).countryId;

  _WorldRegion get _playerRegion =>
      _regionForCountry(_definition.country(_playerCountryId));

  Set<String> get _playableCountryIds {
    final leagueById = {
      for (final league in _definition.leagues) league.id: league,
    };
    return {
      for (final entry in widget.career.world.leagueParticipants.entries)
        if (entry.value.isNotEmpty && leagueById[entry.key] != null)
          leagueById[entry.key]!.countryId,
    };
  }

  WorldSeasonStatistics get _statistics {
    if (_cachedStatistics == null ||
        _statisticsRevision != widget.career.revision ||
        _statisticsContentVersion != _definition.contentVersion ||
        !identical(_statisticsDefinition, _definition)) {
      _cachedStatistics = const WorldStatisticsCalculator().calculate(
        definition: _definition,
        state: widget.career.world,
      );
      _statisticsRevision = widget.career.revision;
      _statisticsContentVersion = _definition.contentVersion;
      _statisticsDefinition = _definition;
    }
    return _cachedStatistics!;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _leagueId =
        widget.initialLeagueId ??
        widget.career.world.leagueIdForClub(widget.career.clubId);
  }

  @override
  void didUpdateWidget(covariant WorldScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLeagueId != null &&
        widget.initialLeagueId != oldWidget.initialLeagueId) {
      _leagueId = widget.initialLeagueId!;
    }
  }

  @override
  void dispose() {
    _rankingSearch.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialLeagueId == null) return _buildTabbedWorld(context);
    return _buildLeagueView(context);
  }

  Widget _buildLeagueView(BuildContext context) {
    final league = _definition.leagues.firstWhere(
      (item) => item.id == _leagueId,
    );
    final clubNames = {
      for (final club in _definition.clubs) club.id: club.name,
      for (final team in _definition.nationalTeams) team.id: team.countryName,
    };
    final clubsById = {for (final club in _definition.clubs) club.id: club};
    final highlightedClubId = widget.highlightClubId ?? widget.career.clubId;
    final table = widget.career.world.table(_leagueId);
    final playerRank = table.indexWhere(
      (row) => row.clubId == highlightedClubId,
    );
    final playerLeagueFixtures = widget.career.world.playerLeagueFixtures
        .where((fixture) => fixture.competitionId == _leagueId)
        .toList(growable: false)
        .reversed;
    final locale = contentLocale(context);
    return Material(
      type: MaterialType.transparency,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(leagueDisplayName(league)),
            leading: IconButton(
              tooltip: uiCopy(locale, 'worldMap'),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: [
              PopupMenuButton<String>(
                tooltip: context.l10n.allCompetitions,
                initialValue: _leagueId,
                onSelected: (value) => setState(() => _leagueId = value),
                itemBuilder: (context) => _definition.leagues
                    .where((item) => item.countryId == league.countryId)
                    .map(
                      (item) => PopupMenuItem(
                        value: item.id,
                        child: Text(leagueDisplayName(item)),
                      ),
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
                  leagueDisplayName(league),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_definition.country(league.countryId).nameFor(locale)} · ${uiCopy(locale, league.division == DivisionLevel.first ? 'divisionOne' : 'divisionTwo')}',
                ),
                const SizedBox(height: 18),
                if (playerRank >= 0) ...[
                  _TableHeader(
                    label: highlightedClubId == widget.career.clubId
                        ? uiCopy(locale, 'yourClub')
                        : uiCopy(locale, 'clubSpotlight'),
                  ),
                  _StandingTile(
                    rank: playerRank + 1,
                    clubName: clubNames[table[playerRank].clubId]!,
                    club: clubsById[table[playerRank].clubId],
                    row: table[playerRank],
                    isPlayerClub: true,
                  ),
                  const SizedBox(height: 14),
                ],
                _TableHeader(label: context.l10n.leagueTable),
                ...table.indexed.map(
                  (entry) => _StandingTile(
                    rank: entry.$1 + 1,
                    clubName: clubNames[entry.$2.clubId]!,
                    club: clubsById[entry.$2.clubId],
                    row: entry.$2,
                    isPlayerClub: entry.$2.clubId == highlightedClubId,
                  ),
                ),
                if (playerLeagueFixtures.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _TableHeader(label: uiCopy(locale, 'recentResults')),
                  ...playerLeagueFixtures.map(
                    (fixture) => _FixtureTile(
                      key: Key('league-result-${fixture.id}'),
                      fixture: fixture,
                      homeName: clubNames[fixture.homeId] ?? fixture.homeId,
                      awayName: clubNames[fixture.awayId] ?? fixture.awayId,
                      highlightsPlayer: true,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _CompetitionCard(
                  icon: Icons.emoji_events_outlined,
                  title: _definition.domesticCups
                      .firstWhere((cup) => cup.countryId == league.countryId)
                      .name,
                  body: uiCopy(contentLocale(context), 'cupFormat'),
                  progress:
                      widget.career.world.competitions[_definition.domesticCups
                          .firstWhere(
                            (cup) => cup.countryId == league.countryId,
                          )
                          .id],
                  participantNames: clubNames,
                  playerId: widget.career.clubId,
                ),
                const SizedBox(height: 10),
                _CompetitionCard(
                  icon: Icons.travel_explore_rounded,
                  title: _definition.internationalClubCompetition.name,
                  body: uiCopy(contentLocale(context), 'internationalFormat'),
                  progress:
                      widget.career.world.competitions[_definition
                          .internationalClubCompetition
                          .id],
                  participantNames: clubNames,
                  playerId: widget.career.clubId,
                ),
                const SizedBox(height: 10),
                _CompetitionCard(
                  icon: Icons.flag_outlined,
                  title: context.l10n.nationalTeams,
                  body:
                      '${_definition.nationalTeams.length} ${uiCopy(locale, 'countries')} · ${context.l10n.majorTournament}',
                  progress:
                      widget
                          .career
                          .world
                          .competitions[_definition.nationalTeams.length == 48
                          ? 'world-nations-championship'
                          : 'major-national-tournament'],
                  participantNames: clubNames,
                  playerId: widget.career.player.nationalTeamId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabbedWorld(BuildContext context) {
    final locale = contentLocale(context);
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          Material(
            color: ElevenwardColors.deep,
            child: TabBar(
              key: const Key('world-section-tabs'),
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  key: const Key('world-tab-map'),
                  icon: const Icon(Icons.public_rounded),
                  text: uiCopy(locale, 'worldTabMap'),
                ),
                Tab(
                  key: const Key('world-tab-player'),
                  icon: const Icon(Icons.person_outline_rounded),
                  text: uiCopy(locale, 'worldTabPlayer'),
                ),
                Tab(
                  key: const Key('world-tab-club'),
                  icon: const Icon(Icons.shield_outlined),
                  text: uiCopy(locale, 'worldTabClub'),
                ),
                Tab(
                  key: const Key('world-tab-world'),
                  icon: const Icon(Icons.language_rounded),
                  text: uiCopy(locale, 'worldTabWorld'),
                ),
                Tab(
                  key: const Key('world-tab-rankings'),
                  icon: const Icon(Icons.leaderboard_rounded),
                  text: uiCopy(locale, 'worldTabRankings'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMapView(context),
                _buildPlayerTab(context),
                _buildClubTab(context),
                _buildWorldTab(context),
                _buildRankingsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTab(BuildContext context) {
    final locale = contentLocale(context);
    final career = widget.career;
    final player = career.player;
    final country = _definition.country(_playerCountryId);
    final club = _definition.club(career.clubId);
    final archivedTrophies = career.seasonHistory.fold<int>(
      0,
      (total, season) => total + season.trophies.length,
    );
    final representedClubs = {
      club.id,
      ...career.seasonHistory.map((season) => season.clubId),
    };
    return ListView(
      key: const Key('world-player-stats-tab'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
      children: [
        _WorldTabHeading(
          title: uiCopy(locale, 'playerStatistics'),
          body: uiCopy(locale, 'playerStatisticsBody'),
        ),
        BroadcastPanel(
          accent: ElevenwardColors.grass,
          child: Row(
            children: [
              PlayerIdentityBadge(
                playerName: player.name,
                avatarId: 'initials',
                size: 56,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${localizedPosition(locale, player.position.name)} · ${localizedArchetype(locale, player.archetype)}',
                    ),
                    Text('${club.name} · ${country.nameFor(locale)}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _WorldSectionHeader(uiCopy(locale, 'currentSeason')),
        _StatGrid(
          stats: [
            (
              label: uiCopy(locale, 'apps'),
              value: '${career.seasonPerformance.appearances}',
            ),
            (
              label: uiCopy(locale, 'goals'),
              value: '${career.seasonPerformance.goals}',
            ),
            (
              label: uiCopy(locale, 'assists'),
              value: '${career.seasonPerformance.assists}',
            ),
            (
              label: uiCopy(locale, 'rating'),
              value: career.seasonPerformance.averageRating.toStringAsFixed(1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _WorldSectionHeader(uiCopy(locale, 'playerProfile')),
        _StatGrid(
          stats: [
            (label: uiCopy(locale, 'overall'), value: '${player.overall}'),
            (label: uiCopy(locale, 'age'), value: '${player.age}'),
            (label: uiCopy(locale, 'form'), value: '${player.form}'),
            (label: uiCopy(locale, 'fitness'), value: '${player.fitness}'),
            (
              label: uiCopy(locale, 'reputation'),
              value: '${player.reputation}',
            ),
            (
              label: uiCopy(locale, 'clubsRepresented'),
              value: '${representedClubs.length}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _WorldSectionHeader(uiCopy(locale, 'clubCareer')),
        _StatGrid(
          stats: [
            (label: uiCopy(locale, 'apps'), value: '${player.appearances}'),
            (label: uiCopy(locale, 'goals'), value: '${player.goals}'),
            (label: uiCopy(locale, 'assists'), value: '${player.assists}'),
            (
              label: uiCopy(locale, 'archivedHonours'),
              value: '$archivedTrophies',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _WorldSectionHeader(uiCopy(locale, 'internationalCareer')),
        BroadcastPanel(
          accent: ElevenwardColors.grass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                country.nameFor(locale),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _InlineStats(
                values: [
                  (
                    label: uiCopy(locale, 'caps'),
                    value: '${career.nationalTeam.caps}',
                  ),
                  (
                    label: uiCopy(locale, 'goals'),
                    value: '${career.nationalTeam.goals}',
                  ),
                  (
                    label: uiCopy(locale, 'assists'),
                    value: '${career.nationalTeam.assists}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClubTab(BuildContext context) {
    final locale = contentLocale(context);
    final career = widget.career;
    final club = _definition.club(career.clubId);
    final leagueId = career.world.leagueIdForClub(club.id);
    final league = _definition.leagues.firstWhere(
      (item) => item.id == leagueId,
    );
    final table = career.world.table(leagueId);
    final leaguePosition = table.indexWhere((row) => row.clubId == club.id) + 1;
    final ranking = _statistics.rankingForClub(club.id);
    final record = ranking.record;
    final recent =
        <Fixture>[
          ...career.world.playerLeagueFixtures.where(
            (fixture) => fixture.homeId == club.id || fixture.awayId == club.id,
          ),
          ...career.world.competitions.values
              .where(
                (competition) =>
                    competition.kind != CompetitionKind.nationalTournament,
              )
              .expand((competition) => competition.fixtures)
              .where(
                (fixture) =>
                    fixture.isPlayed &&
                    (fixture.homeId == club.id || fixture.awayId == club.id),
              ),
        ]..sort((left, right) {
          final matchweek = left.matchweek.compareTo(right.matchweek);
          return matchweek != 0 ? matchweek : left.id.compareTo(right.id);
        });
    final latestResults = recent.reversed.take(5);
    OpponentContext? nextOpponent;
    if (career.phase == CareerPhase.inSeason) {
      try {
        nextOpponent = const WorldSimulator().opponentFor(
          career,
          definition: _definition,
        );
      } on StateError {
        nextOpponent = null;
      }
    }
    final participantNames = {
      for (final item in _definition.clubs) item.id: item.name,
      for (final team in _definition.nationalTeams) team.id: team.countryName,
    };
    final cup = _definition.domesticCups.firstWhere(
      (item) => item.countryId == league.countryId,
    );
    return ListView(
      key: const Key('world-club-stats-tab'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
      children: [
        _WorldTabHeading(
          title: club.name,
          body:
              '${_definition.country(league.countryId).nameFor(locale)} · ${leagueDisplayName(league)}',
        ),
        BroadcastPanel(
          accent: ElevenwardColors.coral,
          child: Row(
            children: [
              _ClubMark(club: club, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${ranking.rank} ${uiCopy(locale, 'inWorld')}',
                      style: const TextStyle(
                        color: ElevenwardColors.coral,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${uiCopy(locale, 'worldRating')} ${ranking.worldRating.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${uiCopy(locale, 'leaguePosition')} $leaguePosition'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _WorldSectionHeader(uiCopy(locale, 'seasonRecord')),
        _StatGrid(
          stats: [
            (label: 'P', value: '${record.played}'),
            (label: 'W', value: '${record.won}'),
            (label: 'D', value: '${record.drawn}'),
            (label: 'L', value: '${record.lost}'),
            (label: 'GF', value: '${record.goalsFor}'),
            (label: 'GA', value: '${record.goalsAgainst}'),
            (label: 'GD', value: '${record.goalDifference}'),
            (label: uiCopy(locale, 'points'), value: '${record.points}'),
          ],
        ),
        const SizedBox(height: 16),
        _WorldSectionHeader(uiCopy(locale, 'clubStrength')),
        _StatGrid(
          stats: [
            (label: uiCopy(locale, 'quality'), value: '${club.quality}'),
            (label: uiCopy(locale, 'attack'), value: '${club.attack}'),
            (label: uiCopy(locale, 'defense'), value: '${club.defense}'),
          ],
        ),
        if (nextOpponent != null) ...[
          const SizedBox(height: 16),
          _WorldSectionHeader(uiCopy(locale, 'nextOpponent')),
          _SimpleInfoTile(
            icon: Icons.sports_soccer_rounded,
            accent: ElevenwardColors.grass,
            title: nextOpponent.clubName,
            subtitle: nextOpponent.isHome
                ? uiCopy(locale, 'homeFixture')
                : uiCopy(locale, 'awayFixture'),
          ),
        ],
        if (latestResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          _WorldSectionHeader(uiCopy(locale, 'recentResults')),
          ...latestResults.map(
            (fixture) => _FixtureTile(
              fixture: fixture,
              homeName: participantNames[fixture.homeId] ?? fixture.homeId,
              awayName: participantNames[fixture.awayId] ?? fixture.awayId,
              highlightsPlayer: true,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _WorldSectionHeader(uiCopy(locale, 'competitions')),
        _CompetitionCard(
          icon: Icons.emoji_events_outlined,
          title: cup.name,
          body: uiCopy(locale, 'cupFormat'),
          progress: career.world.competitions[cup.id],
          participantNames: participantNames,
          playerId: club.id,
        ),
        const SizedBox(height: 8),
        _CompetitionCard(
          icon: Icons.travel_explore_rounded,
          title: _definition.internationalClubCompetition.name,
          body: uiCopy(locale, 'internationalFormat'),
          progress: career
              .world
              .competitions[_definition.internationalClubCompetition.id],
          participantNames: participantNames,
          playerId: club.id,
        ),
      ],
    );
  }

  Widget _buildWorldTab(BuildContext context) {
    final locale = contentLocale(context);
    final stats = _statistics;
    final names = {
      for (final club in _definition.clubs) club.id: club.name,
      for (final team in _definition.nationalTeams) team.id: team.countryName,
    };
    final international = _definition.internationalClubCompetition;
    final nationalCompetitionId = _definition.nationalTeams.length == 48
        ? 'world-nations-championship'
        : 'major-national-tournament';
    return ListView(
      key: const Key('world-global-stats-tab'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
      children: [
        _WorldTabHeading(
          title: uiCopy(locale, 'worldStatistics'),
          body: uiCopy(locale, 'worldStatisticsBody'),
        ),
        _StatGrid(
          stats: [
            (label: uiCopy(locale, 'matches'), value: '${stats.totalMatches}'),
            (label: uiCopy(locale, 'goals'), value: '${stats.totalGoals}'),
            (
              label: uiCopy(locale, 'goalsPerMatch'),
              value: stats.averageGoalsPerMatch.toStringAsFixed(2),
            ),
            (
              label: uiCopy(locale, 'unbeatenClubs'),
              value: '${stats.unbeatenClubCount}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _WorldSectionHeader(uiCopy(locale, 'worldLeaders')),
        if (stats.strongestAttack == null)
          BroadcastPanel(child: Text(uiCopy(locale, 'noWorldResultsYet')))
        else ...[
          _WorldLeaderTile(
            icon: Icons.sports_soccer_rounded,
            label: uiCopy(locale, 'strongestAttack'),
            entry: stats.strongestAttack!,
            value: '${stats.strongestAttack!.record.goalsFor} GF',
          ),
          _WorldLeaderTile(
            icon: Icons.security_rounded,
            label: uiCopy(locale, 'bestDefense'),
            entry: stats.bestDefense!,
            value: '${stats.bestDefense!.record.goalsAgainst} GA',
          ),
          _WorldLeaderTile(
            icon: Icons.emoji_events_rounded,
            label: uiCopy(locale, 'mostWins'),
            entry: stats.mostWins!,
            value: '${stats.mostWins!.record.won} W',
          ),
        ],
        const SizedBox(height: 16),
        _WorldSectionHeader(uiCopy(locale, 'firstDivisionLeaders')),
        ...stats.firstDivisionLeaders.map(
          (leader) => _LeagueLeaderTile(
            leader: leader,
            country: _definition.country(leader.league.countryId),
            locale: locale,
            onTap: () =>
                _openLeague(leader.league.id, highlightClubId: leader.club.id),
          ),
        ),
        const SizedBox(height: 16),
        _WorldSectionHeader(uiCopy(locale, 'globalCompetitions')),
        _CompetitionCard(
          icon: Icons.travel_explore_rounded,
          title: international.name,
          body: uiCopy(locale, 'internationalFormat'),
          progress: widget.career.world.competitions[international.id],
          participantNames: names,
          playerId: widget.career.clubId,
        ),
        const SizedBox(height: 8),
        _CompetitionCard(
          icon: Icons.flag_outlined,
          title: uiCopy(locale, 'worldNations'),
          body: uiCopy(locale, 'nationalCompetitionBody'),
          progress: widget.career.world.competitions[nationalCompetitionId],
          participantNames: names,
          playerId: widget.career.player.nationalTeamId,
        ),
      ],
    );
  }

  Widget _buildRankingsTab(BuildContext context) {
    final locale = contentLocale(context);
    final term = _rankingSearch.text.trim().toLowerCase();
    final countries =
        _definition.countries
            .where((country) => _playableCountryIds.contains(country.id))
            .where(
              (country) =>
                  _rankingRegion == null ||
                  _regionForCountry(country) == _rankingRegion,
            )
            .toList()
          ..sort(
            (left, right) =>
                left.nameFor(locale).compareTo(right.nameFor(locale)),
          );
    final entries = _statistics.rankings
        .where((entry) {
          final country = _definition.country(entry.league.countryId);
          if (_rankingRegion != null &&
              _regionForCountry(country) != _rankingRegion) {
            return false;
          }
          if (_rankingCountryId != null &&
              entry.league.countryId != _rankingCountryId) {
            return false;
          }
          if (_rankingDivision != null &&
              entry.league.division != _rankingDivision) {
            return false;
          }
          return term.isEmpty ||
              entry.club.name.toLowerCase().contains(term) ||
              country.nameFor(locale).toLowerCase().contains(term) ||
              leagueMatchesSearch(entry.league, term);
        })
        .toList(growable: false);
    final current = _statistics.rankingForClub(widget.career.clubId);
    return CustomScrollView(
      key: const Key('world-rankings-tab'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          sliver: SliverList.list(
            children: [
              _WorldTabHeading(
                title: uiCopy(locale, 'clubWorldRankings'),
                body: uiCopy(locale, 'clubWorldRankingsBody'),
                trailing: IconButton(
                  key: const Key('world-ranking-info'),
                  tooltip: uiCopy(locale, 'howRankingsWork'),
                  onPressed: () => _showRankingInfo(context),
                  icon: const Icon(Icons.info_outline_rounded),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          sliver: SliverList.list(
            children: [
              _RankingTile(
                key: const Key('world-ranking-current-club'),
                entry: current,
                countryName: _definition
                    .country(current.league.countryId)
                    .nameFor(locale),
                isCurrentClub: true,
                onTap: () => _openLeague(
                  current.league.id,
                  highlightClubId: current.club.id,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('world-ranking-search'),
                controller: _rankingSearch,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: uiCopy(locale, 'searchClubsLeaguesCountries'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<FootballMapRegion>(
                key: ValueKey('ranking-region-${_rankingRegion?.name}'),
                initialValue: _rankingRegion,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: uiCopy(locale, 'region'),
                  suffixIcon: _rankingRegion == null
                      ? null
                      : IconButton(
                          tooltip: uiCopy(locale, 'clearFilter'),
                          onPressed: () => setState(() {
                            _rankingRegion = null;
                            _rankingCountryId = null;
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                hint: Text(uiCopy(locale, 'allRegions')),
                items: FootballMapRegion.values
                    .map(
                      (region) => DropdownMenuItem(
                        value: region,
                        child: Text(_regionName(locale, region)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() {
                  _rankingRegion = value;
                  _rankingCountryId = null;
                }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'ranking-country-${_rankingRegion?.name}-$_rankingCountryId',
                ),
                initialValue: _rankingCountryId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: uiCopy(locale, 'country'),
                  suffixIcon: _rankingCountryId == null
                      ? null
                      : IconButton(
                          tooltip: uiCopy(locale, 'clearFilter'),
                          onPressed: () =>
                              setState(() => _rankingCountryId = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                hint: Text(uiCopy(locale, 'allCountries')),
                items: countries
                    .map(
                      (country) => DropdownMenuItem(
                        value: country.id,
                        child: Text(country.nameFor(locale)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _rankingCountryId = value),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(uiCopy(locale, 'allDivisions')),
                    selected: _rankingDivision == null,
                    onSelected: (_) => setState(() => _rankingDivision = null),
                  ),
                  ChoiceChip(
                    label: Text(uiCopy(locale, 'firstDivision')),
                    selected: _rankingDivision == DivisionLevel.first,
                    onSelected: (_) =>
                        setState(() => _rankingDivision = DivisionLevel.first),
                  ),
                  ChoiceChip(
                    label: Text(uiCopy(locale, 'secondDivision')),
                    selected: _rankingDivision == DivisionLevel.second,
                    onSelected: (_) =>
                        setState(() => _rankingDivision = DivisionLevel.second),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _WorldSectionHeader(
                '${entries.length} ${uiCopy(locale, 'clubs')}',
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _RankingTile(
                key: Key('world-ranking-${entry.club.id}'),
                entry: entry,
                countryName: _definition
                    .country(entry.league.countryId)
                    .nameFor(locale),
                isCurrentClub: entry.club.id == widget.career.clubId,
                onTap: () => _openLeague(
                  entry.league.id,
                  highlightClubId: entry.club.id,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showRankingInfo(BuildContext context) {
    final locale = contentLocale(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uiCopy(locale, 'howRankingsWork'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(uiCopy(locale, 'rankingFormulaBody')),
            ],
          ),
        ),
      ),
    );
  }

  void _openLeague(String leagueId, {String? highlightClubId}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WorldScreen.league(
          career: widget.career,
          initialLeagueId: leagueId,
          highlightClubId: highlightClubId,
          definition: _definition,
        ),
      ),
    );
  }

  Widget _buildMapView(BuildContext context) {
    final locale = contentLocale(context);
    return CustomScrollView(
      key: const Key('world-map-view'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 110),
          sliver: SliverList.list(
            children: [
              Text(
                uiCopy(locale, 'worldMap'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                uiCopy(locale, 'worldMapBody'),
                style: const TextStyle(
                  color: ElevenwardColors.muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MapIdentityChip(
                    key: const Key('world-nationality-chip'),
                    icon: Icons.flag_rounded,
                    color: ElevenwardColors.grass,
                    role: uiCopy(locale, 'mapNationality'),
                    country: _definition
                        .country(_playerCountryId)
                        .nameFor(locale),
                    onTap: () => _openExplorer(
                      context,
                      initialCountryId: _playerCountryId,
                    ),
                  ),
                  _MapIdentityChip(
                    key: const Key('world-current-club-chip'),
                    icon: Icons.shield_rounded,
                    color: ElevenwardColors.coral,
                    role: uiCopy(locale, 'mapCurrentClub'),
                    country: _definition
                        .country(_clubCountryId)
                        .nameFor(locale),
                    onTap: () => _openExplorer(
                      context,
                      initialCountryId: _clubCountryId,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AccurateFootballWorldMap(
                definition: _definition,
                homeRegion: _playerRegion,
                homeCountryId: _playerCountryId,
                currentClubCountryId: _clubCountryId,
                playableCountryIds: _playableCountryIds,
                interactive: false,
                onExplore: () => _openExplorer(context),
                onRegionSelected: (_) {},
                onCountrySelected: (_) {},
                onUnavailable: (_) {},
                onReset: () {},
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('world-explore-leagues'),
                onPressed: () => _openExplorer(context),
                icon: const Icon(Icons.travel_explore_rounded),
                label: Text(uiCopy(locale, 'exploreLeagues')),
              ),
              const SizedBox(height: 16),
              _WorldSectionHeader(uiCopy(locale, 'playableRegions')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FootballMapRegion.values
                    .map(
                      (region) => ActionChip(
                        key: Key('world-region-${_regionKey(region)}'),
                        avatar: Icon(
                          region == _playerRegion
                              ? Icons.my_location_rounded
                              : Icons.public_rounded,
                          size: 17,
                        ),
                        label: Text(_regionName(locale, region)),
                        onPressed: () =>
                            _openExplorer(context, initialRegion: region),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 18),
              _WorldSectionHeader(uiCopy(locale, 'latestNews')),
              if (widget.career.newsFeed.isEmpty)
                BroadcastPanel(child: Text(uiCopy(locale, 'noNews')))
              else
                ...widget.career.newsFeed
                    .take(4)
                    .map((story) => _NewsTile(story: story)),
            ],
          ),
        ),
      ],
    );
  }

  void _openExplorer(
    BuildContext context, {
    FootballMapRegion? initialRegion,
    String? initialCountryId,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _WorldExplorerScreen(
          career: widget.career,
          homeCountryId: _playerCountryId,
          homeRegion: _playerRegion,
          clubCountryId: _clubCountryId,
          playableCountryIds: _playableCountryIds,
          initialRegion: initialCountryId == null
              ? initialRegion
              : _regionForCountry(_definition.country(initialCountryId)),
          initialCountryId: initialCountryId,
          definition: _definition,
        ),
      ),
    );
  }
}

final class _WorldTabHeading extends StatelessWidget {
  const _WorldTabHeading({
    required this.title,
    required this.body,
    this.trailing,
  });

  final String title;
  final String body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

final class _WorldSectionHeader extends StatelessWidget {
  const _WorldSectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: ElevenwardColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    ),
  );
}

final class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final List<({String label, String value})> stats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: stats
            .map(
              (stat) => SizedBox(
                width: width,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ElevenwardColors.panel,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: ElevenwardColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.value,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stat.label,
                        style: const TextStyle(
                          color: ElevenwardColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      );
    },
  );
}

final class _InlineStats extends StatelessWidget {
  const _InlineStats({required this.values});

  final List<({String label, String value})> values;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 18,
    runSpacing: 8,
    children: values
        .map(
          (entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                entry.label,
                style: const TextStyle(
                  color: ElevenwardColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        )
        .toList(growable: false),
  );
}

final class _SimpleInfoTile extends StatelessWidget {
  const _SimpleInfoTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ElevenwardColors.panel,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: ElevenwardColors.line),
    ),
    child: Row(
      children: [
        Icon(icon, color: accent),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(
                subtitle,
                style: const TextStyle(
                  color: ElevenwardColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _MapIdentityChip extends StatelessWidget {
  const _MapIdentityChip({
    super.key,
    required this.icon,
    required this.color,
    required this.role,
    required this.country,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String role;
  final String country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$role, $country',
    child: ActionChip(
      avatar: Icon(icon, color: color, size: 18),
      side: BorderSide(color: color),
      label: Text('$role · $country'),
      onPressed: onTap,
    ),
  );
}

final class _WorldLeaderTile extends StatelessWidget {
  const _WorldLeaderTile({
    required this.icon,
    required this.label,
    required this.entry,
    required this.value,
  });

  final IconData icon;
  final String label;
  final ClubWorldRankingEntry entry;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: _SimpleInfoTile(
      icon: icon,
      accent: ElevenwardColors.sky,
      title: entry.club.name,
      subtitle: '$label · $value',
    ),
  );
}

final class _LeagueLeaderTile extends StatelessWidget {
  const _LeagueLeaderTile({
    required this.leader,
    required this.country,
    required this.locale,
    required this.onTap,
  });

  final WorldLeagueLeader leader;
  final CountryDefinition country;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 7),
    child: ListTile(
      leading: _ClubMark(club: leader.club),
      title: Text(
        leader.club.name,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${country.nameFor(locale)} · ${leagueDisplayName(leader.league)}',
      ),
      trailing: Text(
        '${leader.record.points} ${uiCopy(locale, 'pointsShort')}',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      onTap: onTap,
    ),
  );
}

final class _RankingTile extends StatelessWidget {
  const _RankingTile({
    super.key,
    required this.entry,
    required this.countryName,
    required this.isCurrentClub,
    required this.onTap,
  });

  final ClubWorldRankingEntry entry;
  final String countryName;
  final bool isCurrentClub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Semantics(
      button: true,
      label:
          '${uiCopy(locale, 'rank')} ${entry.rank}, ${entry.club.name}, '
          '$countryName, ${leagueDisplayName(entry.league)}, '
          '${entry.record.played} played, ${entry.record.won} won, '
          '${entry.record.drawn} drawn, ${entry.record.lost} lost, '
          '${entry.record.points} points, ${entry.worldRating.toStringAsFixed(1)}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Material(
          color: isCurrentClub
              ? ElevenwardColors.grassDark
              : ElevenwardColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(
              color: isCurrentClub
                  ? ElevenwardColors.grass
                  : ElevenwardColors.line,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: SizedBox(
              width: 55,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${entry.rank}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _ClubMark(club: entry.club),
                ],
              ),
            ),
            title: Text(
              entry.club.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '$countryName · ${leagueDisplayName(entry.league)}\n'
              'P${entry.record.played} W${entry.record.won} D${entry.record.drawn} L${entry.record.lost} · '
              '${entry.record.points}PTS · ${entry.record.goalDifference >= 0 ? '+' : ''}${entry.record.goalDifference}GD',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.worldRating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: ElevenwardColors.sky,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  uiCopy(locale, 'ratingShort'),
                  style: const TextStyle(
                    color: ElevenwardColors.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

enum _WorldExplorerLevel { world, region, country }

final class _WorldExplorerScreen extends StatefulWidget {
  const _WorldExplorerScreen({
    required this.career,
    required this.homeCountryId,
    required this.homeRegion,
    required this.clubCountryId,
    required this.playableCountryIds,
    this.initialRegion,
    this.initialCountryId,
    required this.definition,
  });

  final CareerSnapshot career;
  final String homeCountryId;
  final FootballMapRegion homeRegion;
  final String clubCountryId;
  final Set<String> playableCountryIds;
  final FootballMapRegion? initialRegion;
  final String? initialCountryId;
  final WorldDefinition definition;

  @override
  State<_WorldExplorerScreen> createState() => _WorldExplorerScreenState();
}

final class _WorldExplorerScreenState extends State<_WorldExplorerScreen> {
  late final WorldDefinition _definition;
  late _WorldExplorerLevel _level;
  FootballMapRegion? _region;
  String? _countryId;

  @override
  void initState() {
    super.initState();
    _definition = widget.definition;
    _region = widget.initialRegion;
    _countryId = widget.initialCountryId;
    _level = _countryId != null
        ? _WorldExplorerLevel.country
        : _region == null
        ? _WorldExplorerLevel.world
        : _WorldExplorerLevel.region;
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return PopScope<void>(
      canPop: _level == _WorldExplorerLevel.world,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stepBack();
      },
      child: Scaffold(
        key: const Key('world-explorer'),
        appBar: AppBar(
          leading: IconButton(
            key: const Key('world-map-back'),
            tooltip: uiCopy(locale, 'worldMap'),
            onPressed: _level == _WorldExplorerLevel.world
                ? () => Navigator.of(context).pop()
                : _stepBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            _breadcrumb(locale),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mapHeight = (constraints.maxWidth / 1.72).clamp(
                190.0,
                320.0,
              );
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    child: SizedBox(
                      height: mapHeight,
                      child: AccurateFootballWorldMap(
                        definition: _definition,
                        homeRegion: widget.homeRegion,
                        homeCountryId: widget.homeCountryId,
                        currentClubCountryId: widget.clubCountryId,
                        playableCountryIds: widget.playableCountryIds,
                        selectedRegion: _region,
                        selectedCountryId: _countryId,
                        onRegionSelected: _selectRegion,
                        onCountrySelected: _selectCountry,
                        onUnavailable: (name) => ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                '$name · ${uiCopy(locale, 'noPlayableLeagues')}',
                              ),
                            ),
                          ),
                        onReset: _reset,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _selectionPane(context)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _selectionPane(BuildContext context) {
    final locale = contentLocale(context);
    final countries = _region == null
        ? const <CountryDefinition>[]
        : (_definition.countries
              .where((country) => _regionForCountry(country) == _region)
              .toList()
            ..sort((left, right) {
              if (left.id == widget.homeCountryId) return -1;
              if (right.id == widget.homeCountryId) return 1;
              final leftPlayable = widget.playableCountryIds.contains(left.id);
              final rightPlayable = widget.playableCountryIds.contains(
                right.id,
              );
              if (leftPlayable != rightPlayable) {
                return leftPlayable ? -1 : 1;
              }
              final rank = (left.leagueRank ?? 99).compareTo(
                right.leagueRank ?? 99,
              );
              if (rank != 0) return rank;
              return left.nameFor(locale).compareTo(right.nameFor(locale));
            }));
    final leagues = _countryId == null
        ? const <LeagueDefinition>[]
        : _definition.leagues
              .where((league) => league.countryId == _countryId)
              .toList(growable: false);
    return ListView(
      key: const Key('world-explorer-options'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        _TableHeader(
          label: switch (_level) {
            _WorldExplorerLevel.world => uiCopy(locale, 'playableRegions'),
            _WorldExplorerLevel.region => uiCopy(locale, 'playableCountries'),
            _WorldExplorerLevel.country => uiCopy(locale, 'regionLeagues'),
          },
        ),
        if (_level == _WorldExplorerLevel.world)
          ...FootballMapRegion.values.map(
            (region) => _ExplorerOption(
              key: Key('world-region-${_regionKey(region)}'),
              icon: region == widget.homeRegion
                  ? Icons.my_location_rounded
                  : Icons.public_rounded,
              color: region == widget.homeRegion
                  ? ElevenwardColors.grass
                  : ElevenwardColors.sky,
              title: _regionName(locale, region),
              subtitle: uiCopy(locale, 'chooseCountry'),
              onTap: () => _selectRegion(region),
            ),
          ),
        if (_level == _WorldExplorerLevel.region)
          ...countries.map(
            (country) => _ExplorerOption(
              key: Key('world-country-${country.id}'),
              icon: country.id == widget.homeCountryId
                  ? Icons.home_rounded
                  : country.id == widget.clubCountryId
                  ? Icons.shield_rounded
                  : Icons.flag_outlined,
              color: country.id == widget.homeCountryId
                  ? ElevenwardColors.grass
                  : country.id == widget.clubCountryId
                  ? ElevenwardColors.coral
                  : widget.playableCountryIds.contains(country.id)
                  ? ElevenwardColors.sky
                  : ElevenwardColors.amber,
              title: country.nameFor(locale),
              subtitle: widget.playableCountryIds.contains(country.id)
                  ? '${_definition.leagues.where((league) => league.countryId == country.id).length} ${uiCopy(locale, 'leagues')}'
                  : context.l10n.nationalTeam,
              onTap: () => _selectCountry(country.id),
            ),
          ),
        if (_level == _WorldExplorerLevel.country) ...[
          ...leagues.map(
            (league) => _ExplorerOption(
              key: Key('country-league-${league.id}'),
              icon: Icons.emoji_events_outlined,
              color: ElevenwardColors.sky,
              title: leagueDisplayName(league),
              subtitle: '${league.clubIds.length} ${uiCopy(locale, 'clubs')}',
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => WorldScreen.league(
                    career: widget.career,
                    initialLeagueId: league.id,
                    definition: _definition,
                  ),
                ),
              ),
            ),
          ),
          if (leagues.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TableHeader(label: uiCopy(locale, 'countryCups')),
            _countryCupCard(context),
          ],
          const SizedBox(height: 10),
          _nationalTeamCard(context),
        ],
      ],
    );
  }

  Widget _countryCupCard(BuildContext context) {
    final countryId = _countryId!;
    final cup = _definition.domesticCups.firstWhere(
      (competition) => competition.countryId == countryId,
    );
    final names = {
      for (final club in _definition.clubs) club.id: club.name,
      for (final team in _definition.nationalTeams) team.id: team.countryName,
    };
    return _CompetitionCard(
      icon: Icons.emoji_events_outlined,
      title: cup.name,
      body: uiCopy(contentLocale(context), 'cupFormat'),
      progress: widget.career.world.competitions[cup.id],
      participantNames: names,
      playerId: widget.career.clubId,
    );
  }

  Widget _nationalTeamCard(BuildContext context) {
    final locale = contentLocale(context);
    final country = _definition.country(_countryId!);
    final team = _definition.nationalTeam(country.id);
    final qualification = widget.career.world.nationalQualification;
    final qualified = qualification?.qualified(country.id);
    final status = qualification == null
        ? 'Next qualifying cycle begins in season ${((widget.career.season ~/ 4) + 1) * 4}.'
        : qualified == true
        ? 'Qualified for the season ${qualification.cycleSeason} championship.'
        : 'Did not qualify for the season ${qualification.cycleSeason} championship.';
    return BroadcastPanel(
      accent: country.id == widget.homeCountryId
          ? ElevenwardColors.grass
          : country.id == widget.clubCountryId
          ? ElevenwardColors.coral
          : ElevenwardColors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${country.nameFor(locale)} · ${team.confederation.name.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text('$status National-team quality: ${team.quality}.'),
        ],
      ),
    );
  }

  String _breadcrumb(String locale) => [
    uiCopy(locale, 'worldMap'),
    if (_region != null) _regionName(locale, _region!),
    if (_countryId != null) _definition.country(_countryId!).nameFor(locale),
  ].join(' › ');

  void _selectRegion(FootballMapRegion region) => setState(() {
    _region = region;
    _countryId = null;
    _level = _WorldExplorerLevel.region;
  });

  void _selectCountry(String countryId) => setState(() {
    _region = _regionForCountry(_definition.country(countryId));
    _countryId = countryId;
    _level = _WorldExplorerLevel.country;
  });

  void _stepBack() => setState(() {
    if (_level == _WorldExplorerLevel.country) {
      _countryId = null;
      _level = _WorldExplorerLevel.region;
    } else {
      _region = null;
      _countryId = null;
      _level = _WorldExplorerLevel.world;
    }
  });

  void _reset() => setState(() {
    _region = null;
    _countryId = null;
    _level = _WorldExplorerLevel.world;
  });
}

final class _ExplorerOption extends StatelessWidget {
  const _ExplorerOption({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: ElevenwardColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: ElevenwardColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minVerticalPadding: 10,
        leading: RoleIconBadge(icon: icon, label: title, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );
}

_WorldRegion _regionForCountry(CountryDefinition country) =>
    switch (country.region) {
      FootballRegion.europe => _WorldRegion.europe,
      FootballRegion.southAmerica => _WorldRegion.southAmerica,
      FootballRegion.northAmerica => _WorldRegion.northAmerica,
      FootballRegion.asia => _WorldRegion.asia,
      FootballRegion.africa => _WorldRegion.africa,
      FootballRegion.oceania => _WorldRegion.oceania,
    };

String _regionName(String locale, _WorldRegion region) {
  const names = <_WorldRegion, Map<String, String>>{
    _WorldRegion.europe: {
      'en': 'Europe',
      'es': 'Europa',
      'pt-BR': 'Europa',
      'fr': 'Europe',
    },
    _WorldRegion.northAmerica: {
      'en': 'North America',
      'es': 'Norteamérica',
      'pt-BR': 'América do Norte',
      'fr': 'Amérique du Nord',
    },
    _WorldRegion.southAmerica: {
      'en': 'South America',
      'es': 'Sudamérica',
      'pt-BR': 'América do Sul',
      'fr': 'Amérique du Sud',
    },
    _WorldRegion.asia: {
      'en': 'Asia',
      'es': 'Asia',
      'pt-BR': 'Ásia',
      'fr': 'Asie',
    },
    _WorldRegion.africa: {
      'en': 'Africa',
      'es': 'África',
      'pt-BR': 'África',
      'fr': 'Afrique',
    },
    _WorldRegion.oceania: {
      'en': 'Oceania',
      'es': 'Oceanía',
      'pt-BR': 'Oceania',
      'fr': 'Océanie',
    },
  };
  return names[region]?[locale] ?? names[region]!['en']!;
}

String _regionKey(_WorldRegion region) => region.name.replaceAllMapped(
  RegExp('[A-Z]'),
  (match) => '-${match.group(0)!.toLowerCase()}',
);

IconData _newsIcon(String category) => switch (category) {
  'manager' || 'coach' => Icons.manage_accounts_outlined,
  'sponsor' || 'commercial' => Icons.campaign_outlined,
  'rival' || 'match' => Icons.sports_soccer_rounded,
  'injury' || 'fitness' => Icons.health_and_safety_outlined,
  _ => Icons.newspaper_rounded,
};

Color _newsColor(String category) => switch (category) {
  'sponsor' || 'commercial' => ElevenwardColors.amber,
  'rival' || 'match' => ElevenwardColors.coral,
  'manager' || 'coach' => ElevenwardColors.sky,
  _ => ElevenwardColors.grass,
};

final class _NewsTile extends StatelessWidget {
  const _NewsTile({required this.story});

  final CareerNewsItem story;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ElevenwardColors.panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ElevenwardColors.line),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoleIconBadge(
          icon: _newsIcon(story.category),
          label: story.category,
          size: 46,
          color: _newsColor(story.category),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'S${story.season} · W${story.week} · ${story.category.toUpperCase()}',
                style: const TextStyle(
                  color: ElevenwardColors.grass,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                story.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                story.body,
                style: const TextStyle(
                  color: ElevenwardColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
        SizedBox(
          width: 102,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              uiCopy(contentLocale(context), 'tableColumns'),
              style: const TextStyle(
                color: ElevenwardColors.muted,
                fontSize: 11,
              ),
            ),
          ),
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$rank',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text('${row.played}'),
          ),
        ),
        SizedBox(
          width: 38,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${row.goalDifference >= 0 ? '+' : ''}${row.goalDifference}',
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${row.points}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
  );
}

final class _ClubMark extends StatelessWidget {
  const _ClubMark({required this.club, this.size = 27});

  final ClubDefinition club;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${club.name} ${uiCopy(contentLocale(context), 'clubMark')}',
    image: true,
    child: Container(
      width: size,
      height: size * 31 / 27,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(club.primaryColor),
        border: Border.all(
          color: Color(club.secondaryColor),
          width: size > 35 ? 3 : 2,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(size * .26),
          bottom: Radius.circular(size * .4),
        ),
      ),
      child: Text(
        club.shortName.characters.take(2).toString().toUpperCase(),
        style: TextStyle(
          color: Color(club.secondaryColor),
          fontSize: size * .3,
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
    return Material(
      color: ElevenwardColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ElevenwardColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: ElevenwardColors.amber),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('$status · $body', style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => _CompetitionDetailScreen(
              icon: icon,
              title: title,
              body: body,
              status: status,
              competition: competition,
              fixtures: fixtures,
              participantNames: participantNames,
              playerId: playerId,
            ),
          ),
        ),
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

final class _CompetitionDetailScreen extends StatelessWidget {
  const _CompetitionDetailScreen({
    required this.icon,
    required this.title,
    required this.body,
    required this.status,
    required this.competition,
    required this.fixtures,
    required this.participantNames,
    required this.playerId,
  });

  final IconData icon;
  final String title;
  final String body;
  final String status;
  final CompetitionProgress? competition;
  final List<Fixture> fixtures;
  final Map<String, String> participantNames;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final bracketFixtures = competition == null
        ? <Fixture>[]
        : fixtures
              .where(
                (fixture) =>
                    competition!.kind == CompetitionKind.domesticCup ||
                    fixture.id.contains('-r'),
              )
              .toList(growable: false);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(pinned: true, title: Text(title)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverList.list(
              children: [
                BroadcastPanel(
                  accent: ElevenwardColors.amber,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: ElevenwardColors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(body),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (fixtures.isEmpty)
                  BroadcastPanel(child: Text(uiCopy(locale, 'noFixtures')))
                else ...[
                  if (competition case final competition?
                      when competition.kind != CompetitionKind.domesticCup) ...[
                    Text(
                      '${uiCopy(locale, competition.kind == CompetitionKind.internationalClub ? 'internationalQualification' : 'nationalQualification')} '
                      '${uiCopy(locale, 'groupTiebreaks')}',
                      style: const TextStyle(
                        color: ElevenwardColors.muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (bracketFixtures.isNotEmpty) ...[
                    _CompetitionBracket(
                      fixtures: bracketFixtures,
                      participantNames: participantNames,
                      playerId: playerId,
                    ),
                    const Divider(height: 28),
                  ],
                  Text(
                    uiCopy(locale, 'allFixtures').toUpperCase(),
                    style: const TextStyle(
                      color: ElevenwardColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 6),
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
              ],
            ),
          ),
        ],
      ),
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
    super.key,
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
