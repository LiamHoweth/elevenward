import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../league_presentation.dart';
import '../theme.dart';
import '../ui_copy.dart';
import '../widgets/football_world_map.dart';
import '../widgets/identity_badge.dart';

typedef _WorldRegion = FootballMapRegion;

final class WorldScreen extends StatefulWidget {
  const WorldScreen({
    super.key,
    required this.career,
    this.definition,
    this.controller,
  }) : initialLeagueId = null,
       highlightClubId = null;

  const WorldScreen.league({
    super.key,
    required this.career,
    required this.initialLeagueId,
    this.definition,
    this.highlightClubId,
    this.controller,
  });

  final CareerSnapshot career;
  final String? initialLeagueId;
  final String? highlightClubId;
  final WorldDefinition? definition;
  final AppController? controller;

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
    final controller = widget.controller;
    if (controller == null) return _buildWorld(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildWorld(context),
    );
  }

  Widget _buildWorld(BuildContext context) {
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
              if (widget.controller case final controller?)
                _BookmarkButton(
                  key: Key('favorite-league-${league.id}'),
                  name: leagueDisplayName(league),
                  selected: controller.favoriteLeagueIds.contains(league.id),
                  onPressed: () => controller.toggleFavoriteLeague(league.id),
                ),
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
                if (widget.controller case final controller?
                    when playerRank >= 0 &&
                        clubsById[highlightedClubId] != null) ...[
                  _FavoriteClubTile(
                    key: Key('league-club-spotlight-$highlightedClubId'),
                    club: clubsById[highlightedClubId]!,
                    subtitle: uiCopy(locale, 'clubSpotlight'),
                    controller: controller,
                  ),
                  const SizedBox(height: 14),
                ],
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
                  _TableHeader(
                    label: uiCopy(locale, 'recentResults'),
                    showColumns: false,
                  ),
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
                portraitId: player.portraitId,
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
          trailing: widget.controller == null
              ? null
              : _BookmarkButton(
                  key: Key('favorite-club-${club.id}'),
                  name: club.name,
                  selected: widget.controller!.favoriteClubIds.contains(
                    club.id,
                  ),
                  onPressed: () =>
                      widget.controller!.toggleFavoriteClub(club.id),
                ),
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
                      style: TextStyle(
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
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('world-club-open-league'),
          onPressed: () => _openLeague(leagueId, highlightClubId: club.id),
          icon: const Icon(Icons.table_chart_outlined),
          label: Text(context.l10n.leagueTable),
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
    final term = _worldSearchText(_rankingSearch.text.trim());
    final hasFilters =
        term.isNotEmpty ||
        _rankingRegion != null ||
        _rankingCountryId != null ||
        _rankingDivision != null;
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
              _worldSearchText(entry.club.name).contains(term) ||
              _worldSearchText(entry.club.shortName).contains(term) ||
              country.names.values.any(
                (name) => _worldSearchText(name).contains(term),
              ) ||
              _worldSearchText(leagueDisplayName(entry.league))
                  .contains(term) ||
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
                textInputAction: TextInputAction.search,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: InputDecoration(
                  labelText: uiCopy(locale, 'searchClubsLeaguesCountries'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _rankingSearch.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('world-ranking-clear-search'),
                          tooltip: _worldPolishCopy(locale, 'clearSearch'),
                          onPressed: () => setState(_rankingSearch.clear),
                          icon: const Icon(Icons.close_rounded),
                        ),
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
              if (entries.isEmpty)
                BroadcastPanel(
                  key: const Key('world-ranking-empty'),
                  child: Text(_worldPolishCopy(locale, 'rankingNoResults')),
                ),
              if (hasFilters) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('world-ranking-reset-filters'),
                  onPressed: _resetRankingFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: Text(_worldPolishCopy(locale, 'clearAllFilters')),
                ),
                const SizedBox(height: 8),
              ],
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

  void _resetRankingFilters() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _rankingSearch.clear();
      _rankingRegion = null;
      _rankingCountryId = null;
      _rankingDivision = null;
    });
  }

  void _showRankingInfo(BuildContext context) {
    final locale = contentLocale(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          key: const Key('world-ranking-help-scroll'),
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
          controller: widget.controller,
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
                style: TextStyle(color: ElevenwardColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('world-search-open'),
                onPressed: () => _openExplorer(context, focusSearch: true),
                icon: const Icon(Icons.search_rounded),
                label: Text(_worldPolishCopy(locale, 'searchPrompt')),
              ),
              const SizedBox(height: 12),
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
              if (widget.controller != null) ...[
                const SizedBox(height: 20),
                _buildFavorites(context),
              ],
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

  Widget _buildFavorites(BuildContext context) {
    final controller = widget.controller!;
    final locale = contentLocale(context);
    final clubs =
        _definition.clubs
            .where((club) => controller.favoriteClubIds.contains(club.id))
            .where(
              (club) => widget.career.world.leagueParticipants.values.any(
                (participants) => participants.contains(club.id),
              ),
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    final leagues =
        _definition.leagues
            .where((league) => controller.favoriteLeagueIds.contains(league.id))
            .where(
              (league) =>
                  widget
                      .career
                      .world
                      .leagueParticipants[league.id]
                      ?.isNotEmpty ??
                  false,
            )
            .toList()
          ..sort(
            (left, right) =>
                leagueDisplayName(left).compareTo(leagueDisplayName(right)),
          );
    return Column(
      key: const Key('world-favorites'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorldSectionHeader(_worldPolishCopy(locale, 'favorites')),
        if (clubs.isEmpty && leagues.isEmpty)
          BroadcastPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.bookmark_border_rounded,
                  color: ElevenwardColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_worldPolishCopy(locale, 'favoritesEmpty')),
                ),
              ],
            ),
          ),
        ...clubs.map((club) {
          final leagueId = widget.career.world.leagueIdForClub(club.id);
          final league = _definition.leagues.firstWhere(
            (league) => league.id == leagueId,
          );
          return _FavoriteClubTile(
            key: Key('world-favorite-club-${club.id}'),
            club: club,
            subtitle:
                '${_definition.country(club.countryId).nameFor(locale)} · ${leagueDisplayName(league)}',
            controller: controller,
            onTap: () => _openLeague(leagueId, highlightClubId: club.id),
          );
        }),
        ...leagues.map(
          (league) => _ExplorerOption(
            key: Key('world-favorite-league-${league.id}'),
            icon: Icons.emoji_events_outlined,
            color: ElevenwardColors.sky,
            title: leagueDisplayName(league),
            subtitle: _definition.country(league.countryId).nameFor(locale),
            trailing: _BookmarkButton(
              key: Key('favorite-league-${league.id}'),
              name: leagueDisplayName(league),
              selected: true,
              onPressed: () => controller.toggleFavoriteLeague(league.id),
            ),
            onTap: () => _openLeague(league.id),
          ),
        ),
      ],
    );
  }

  void _openExplorer(
    BuildContext context, {
    FootballMapRegion? initialRegion,
    String? initialCountryId,
    bool focusSearch = false,
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
          controller: widget.controller,
          focusSearch: focusSearch,
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
      style: TextStyle(
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
                        style: TextStyle(
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
                style: TextStyle(color: ElevenwardColors.muted, fontSize: 10),
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
                style: TextStyle(color: ElevenwardColors.muted, fontSize: 11),
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
      excludeSemantics: true,
      onTap: onTap,
      label:
          '${uiCopy(locale, 'rank')} ${entry.rank}, ${entry.club.name}, '
          '$countryName, ${leagueDisplayName(entry.league)}, '
          '${_worldPolishCopy(locale, 'rankingRecord').replaceAll('{played}', '${entry.record.played}').replaceAll('{won}', '${entry.record.won}').replaceAll('{drawn}', '${entry.record.drawn}').replaceAll('{lost}', '${entry.record.lost}')}, '
          '${entry.record.points} ${uiCopy(locale, 'points')}, '
          '${uiCopy(locale, 'worldRating')} ${entry.worldRating.toStringAsFixed(1)}',
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
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ClubMark(club: entry.club),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.rank}. ${entry.club.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '$countryName · ${leagueDisplayName(entry.league)}',
                              style: TextStyle(color: ElevenwardColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    children: [
                      Text(
                        'P${entry.record.played} W${entry.record.won} '
                        'D${entry.record.drawn} L${entry.record.lost}',
                      ),
                      Text(
                        '${entry.record.points} ${uiCopy(locale, 'pointsShort')} · '
                        '${entry.record.goalDifference >= 0 ? '+' : ''}${entry.record.goalDifference} GD',
                      ),
                      Text(
                        '${uiCopy(locale, 'worldRating')} ${entry.worldRating.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: ElevenwardColors.sky,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
    this.controller,
    this.focusSearch = false,
  });

  final CareerSnapshot career;
  final String homeCountryId;
  final FootballMapRegion homeRegion;
  final String clubCountryId;
  final Set<String> playableCountryIds;
  final FootballMapRegion? initialRegion;
  final String? initialCountryId;
  final WorldDefinition definition;
  final AppController? controller;
  final bool focusSearch;

  @override
  State<_WorldExplorerScreen> createState() => _WorldExplorerScreenState();
}

final class _WorldExplorerScreenState extends State<_WorldExplorerScreen> {
  late final WorldDefinition _definition;
  late _WorldExplorerLevel _level;
  FootballMapRegion? _region;
  String? _countryId;
  String? _spotlightClubId;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _selectionScroll = ScrollController();

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
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _selectionScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null) return _buildExplorer(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildExplorer(context),
    );
  }

  Widget _buildExplorer(BuildContext context) {
    final locale = contentLocale(context);
    // Scaffold removes the consumed keyboard inset from its body MediaQuery.
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
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
              final mapHeight = (constraints.maxWidth / 1.72)
                  .clamp(110.0, 320.0)
                  .clamp(0.0, constraints.maxHeight * .42);
              return Column(
                children: [
                  Offstage(
                    key: const Key('world-explorer-map-area'),
                    offstage: keyboardVisible,
                    child: Padding(
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
      controller: _selectionScroll,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        TextField(
          key: const Key('world-search-field'),
          controller: _search,
          focusNode: _searchFocus,
          autofocus: widget.focusSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: _worldPolishCopy(locale, 'searchPrompt'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    key: const Key('world-search-clear'),
                    tooltip: _worldPolishCopy(locale, 'clearSearch'),
                    onPressed: () => setState(_search.clear),
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _searchFocus.unfocus(),
        ),
        const SizedBox(height: 16),
        if (_search.text.trim().isNotEmpty) ...[
          ..._searchResults(context),
        ] else ...[
          if (_spotlightClubId case final clubId?) ...[
            _searchClubSpotlight(context, _definition.club(clubId)),
            const SizedBox(height: 16),
          ],
          _WorldSectionHeader(switch (_level) {
            _WorldExplorerLevel.world => uiCopy(locale, 'playableRegions'),
            _WorldExplorerLevel.region => uiCopy(locale, 'playableCountries'),
            _WorldExplorerLevel.country => uiCopy(locale, 'regionLeagues'),
          }),
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
                trailing: widget.controller == null
                    ? null
                    : _BookmarkButton(
                        key: Key('favorite-league-${league.id}'),
                        name: leagueDisplayName(league),
                        selected: widget.controller!.favoriteLeagueIds.contains(
                          league.id,
                        ),
                        onPressed: () =>
                            widget.controller!.toggleFavoriteLeague(league.id),
                      ),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => WorldScreen.league(
                      career: widget.career,
                      initialLeagueId: league.id,
                      definition: _definition,
                      controller: widget.controller,
                    ),
                  ),
                ),
              ),
            ),
            if (leagues.isNotEmpty) ...[
              const SizedBox(height: 10),
              _WorldSectionHeader(uiCopy(locale, 'countryCups')),
              _countryCupCard(context),
            ],
            const SizedBox(height: 10),
            _nationalTeamCard(context),
          ],
        ],
      ],
    );
  }

  List<Widget> _searchResults(BuildContext context) {
    final locale = contentLocale(context);
    final query = _worldSearchText(_search.text.trim());
    final participantIds = {
      for (final participants in widget.career.world.leagueParticipants.values)
        ...participants,
    };
    final countries =
        _definition.countries
            .where(
              (country) =>
                  country.names.values.any(
                    (name) => _worldSearchText(name).contains(query),
                  ) ||
                  country.id.replaceAll('-', ' ').contains(query),
            )
            .toList()
          ..sort(
            (left, right) =>
                left.nameFor(locale).compareTo(right.nameFor(locale)),
          );
    final clubs =
        _definition.clubs
            .where(
              (club) =>
                  _worldSearchText(club.name).contains(query) ||
                  _worldSearchText(club.shortName).contains(query),
            )
            .where((club) => participantIds.contains(club.id))
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    if (countries.isEmpty && clubs.isEmpty) {
      return [
        BroadcastPanel(
          key: const Key('world-search-empty'),
          child: Text(_worldPolishCopy(locale, 'noResults')),
        ),
      ];
    }
    return [
      if (countries.isNotEmpty) ...[
        _WorldSectionHeader(uiCopy(locale, 'countries')),
        ...countries.map(
          (country) => _ExplorerOption(
            key: Key('world-search-country-${country.id}'),
            icon: Icons.flag_outlined,
            color: ElevenwardColors.sky,
            title: country.nameFor(locale),
            subtitle: widget.playableCountryIds.contains(country.id)
                ? _worldPolishCopy(locale, 'showLeagues')
                : context.l10n.nationalTeam,
            onTap: () => _selectSearchCountry(country.id),
          ),
        ),
      ],
      if (clubs.isNotEmpty) ...[
        _WorldSectionHeader(uiCopy(locale, 'clubs')),
        ...clubs
            .take(30)
            .map(
              (club) => _ExplorerOption(
                key: Key('world-search-club-${club.id}'),
                icon: Icons.shield_outlined,
                color: ElevenwardColors.coral,
                title: club.name,
                subtitle: _definition.country(club.countryId).nameFor(locale),
                onTap: () =>
                    _selectSearchCountry(club.countryId, clubId: club.id),
              ),
            ),
        if (clubs.length > 30)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_worldPolishCopy(locale, 'refineSearch')),
          ),
      ],
    ];
  }

  Widget _searchClubSpotlight(BuildContext context, ClubDefinition club) {
    final locale = contentLocale(context);
    final leagueId = widget.career.world.leagueIdForClub(club.id);
    final league = _definition.leagues.firstWhere(
      (item) => item.id == leagueId,
    );
    return BroadcastPanel(
      key: Key('world-search-spotlight-${club.id}'),
      accent: ElevenwardColors.coral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClubMark(club: club, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(leagueDisplayName(league)),
                  ],
                ),
              ),
              if (widget.controller case final controller?)
                _BookmarkButton(
                  key: Key('favorite-club-${club.id}'),
                  name: club.name,
                  selected: controller.favoriteClubIds.contains(club.id),
                  onPressed: () => controller.toggleFavoriteClub(club.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: Key('world-search-open-league-${club.id}'),
            icon: const Icon(Icons.emoji_events_outlined),
            label: Text(_worldPolishCopy(locale, 'openLeague')),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => WorldScreen.league(
                  career: widget.career,
                  initialLeagueId: league.id,
                  definition: _definition,
                  highlightClubId: club.id,
                  controller: widget.controller,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectSearchCountry(String countryId, {String? clubId}) {
    _searchFocus.unfocus();
    setState(() {
      _search.clear();
      _spotlightClubId = clubId;
      _region = _regionForCountry(_definition.country(countryId));
      _countryId = countryId;
      _level = _WorldExplorerLevel.country;
    });
    if (_selectionScroll.hasClients) _selectionScroll.jumpTo(0);
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
        ? _worldPolishCopy(
            locale,
            'nextQualification',
          ).replaceAll('{season}', '${((widget.career.season ~/ 4) + 1) * 4}')
        : _worldPolishCopy(
            locale,
            qualified == true ? 'qualified' : 'notQualified',
          ).replaceAll('{season}', '${qualification.cycleSeason}');
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
          Text(
            '$status ${_worldPolishCopy(locale, 'nationalQuality').replaceAll('{quality}', '${team.quality}')}',
          ),
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
    _search.clear();
    _searchFocus.unfocus();
    _spotlightClubId = null;
    _region = region;
    _countryId = null;
    _level = _WorldExplorerLevel.region;
  });

  void _selectCountry(String countryId) => setState(() {
    _search.clear();
    _searchFocus.unfocus();
    _spotlightClubId = null;
    _region = _regionForCountry(_definition.country(countryId));
    _countryId = countryId;
    _level = _WorldExplorerLevel.country;
  });

  void _stepBack() => setState(() {
    _spotlightClubId = null;
    _search.clear();
    _searchFocus.unfocus();
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
    _spotlightClubId = null;
    _search.clear();
    _searchFocus.unfocus();
    _region = null;
    _countryId = null;
    _level = _WorldExplorerLevel.world;
  });
}

final class _FavoriteClubTile extends StatelessWidget {
  const _FavoriteClubTile({
    super.key,
    required this.club,
    required this.subtitle,
    required this.controller,
    this.onTap,
  });

  final ClubDefinition club;
  final String subtitle;
  final AppController controller;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _WorldBrowseTile(
    leading: _ClubMark(club: club, size: 34),
    title: club.name,
    subtitle: subtitle,
    trailing: _BookmarkButton(
      key: Key('favorite-club-${club.id}'),
      name: club.name,
      selected: controller.favoriteClubIds.contains(club.id),
      onPressed: () => controller.toggleFavoriteClub(club.id),
    ),
    onTap: onTap,
  );
}

final class _BookmarkButton extends StatefulWidget {
  const _BookmarkButton({
    super.key,
    required this.name,
    required this.selected,
    required this.onPressed,
  });

  final String name;
  final bool selected;
  final Future<void> Function() onPressed;

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

final class _BookmarkButtonState extends State<_BookmarkButton> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Semantics(
      toggled: widget.selected,
      child: IconButton(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        tooltip:
            '${_worldPolishCopy(locale, _saving
                ? 'saving'
                : widget.selected
                ? 'removeFavorite'
                : 'addFavorite')} · ${widget.name}',
        onPressed: _saving ? null : _toggle,
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                widget.selected
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
      ),
    );
  }

  Future<void> _toggle() async {
    setState(() => _saving = true);
    try {
      await widget.onPressed();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                _worldPolishCopy(contentLocale(context), 'favoriteFailed'),
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _worldSearchText(String value) {
  const letters = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'œ': 'oe',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };
  return value
      .toLowerCase()
      .split('')
      .map((letter) => letters[letter] ?? letter)
      .join()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _worldPolishCopy(String locale, String key) {
  const copy = <String, Map<String, String>>{
    'searchPrompt': {
      'en': 'Search countries and clubs',
      'es': 'Buscar países y clubes',
      'pt-BR': 'Buscar países e clubes',
      'fr': 'Rechercher pays et clubs',
    },
    'clearSearch': {
      'en': 'Clear search',
      'es': 'Borrar búsqueda',
      'pt-BR': 'Limpar busca',
      'fr': 'Effacer la recherche',
    },
    'noResults': {
      'en': 'No countries or clubs found. Try another name.',
      'es': 'No se encontraron países ni clubes. Prueba otro nombre.',
      'pt-BR': 'Nenhum país ou clube encontrado. Tente outro nome.',
      'fr': 'Aucun pays ou club trouvé. Essayez un autre nom.',
    },
    'rankingNoResults': {
      'en': 'No clubs match this search and these filters. Clear the filters or try another name.',
      'es': 'Ningún club coincide con esta búsqueda y estos filtros. Borra los filtros o prueba otro nombre.',
      'pt-BR': 'Nenhum clube corresponde à busca e aos filtros. Limpe os filtros ou tente outro nome.',
      'fr': 'Aucun club ne correspond à la recherche et aux filtres. Effacez les filtres ou essayez un autre nom.',
    },
    'clearAllFilters': {
      'en': 'Clear all filters',
      'es': 'Borrar todos los filtros',
      'pt-BR': 'Limpar todos os filtros',
      'fr': 'Effacer tous les filtres',
    },
    'rankingRecord': {
      'en': '{played} played, {won} won, {drawn} drawn, {lost} lost',
      'es':
          '{played} jugados, {won} ganados, {drawn} empatados, {lost} perdidos',
      'pt-BR': '{played} jogados, {won} vencidos, {drawn} empatados, {lost} perdidos',
      'fr': '{played} joués, {won} gagnés, {drawn} nuls, {lost} perdus',
    },
    'standingSummary': {
      'en': 'Rank {rank}, {club}, {played} played, goal difference {difference}, {points} points',
      'es': 'Puesto {rank}, {club}, {played} jugados, diferencia de goles {difference}, {points} puntos',
      'pt-BR': 'Posição {rank}, {club}, {played} jogados, saldo de gols {difference}, {points} pontos',
      'fr': 'Rang {rank}, {club}, {played} joués, différence de buts {difference}, {points} points',
    },
    'goalDifferenceShort': {'en': 'GD', 'es': 'DG', 'pt-BR': 'SG', 'fr': 'DB'},
    'refineSearch': {
      'en': 'Showing the first 30 clubs. Enter more of the name to narrow your search.',
      'es': 'Se muestran los primeros 30 clubes. Escribe más del nombre para precisar la búsqueda.',
      'pt-BR': 'Mostrando os primeiros 30 clubes. Digite mais do nome para refinar a busca.',
      'fr': 'Les 30 premiers clubs sont affichés. Précisez le nom pour affiner la recherche.',
    },
    'showLeagues': {
      'en': 'Show country and leagues',
      'es': 'Ver país y ligas',
      'pt-BR': 'Ver país e ligas',
      'fr': 'Voir le pays et les ligues',
    },
    'openLeague': {
      'en': 'View club in league',
      'es': 'Ver club en la liga',
      'pt-BR': 'Ver clube na liga',
      'fr': 'Voir le club dans sa ligue',
    },
    'favorites': {
      'en': 'Favorites',
      'es': 'Favoritos',
      'pt-BR': 'Favoritos',
      'fr': 'Favoris',
    },
    'favoritesEmpty': {
      'en': 'Bookmark a club or league to find it here. Start with search or Explore leagues.',
      'es': 'Marca un club o una liga para encontrarlo aquí. Empieza buscando o explorando ligas.',
      'pt-BR': 'Marque um clube ou liga para encontrá-lo aqui. Comece buscando ou explorando ligas.',
      'fr': 'Ajoutez un club ou une ligue aux favoris pour le retrouver ici. Recherchez ou explorez les ligues.',
    },
    'addFavorite': {
      'en': 'Add to favorites',
      'es': 'Añadir a favoritos',
      'pt-BR': 'Adicionar aos favoritos',
      'fr': 'Ajouter aux favoris',
    },
    'removeFavorite': {
      'en': 'Remove from favorites',
      'es': 'Quitar de favoritos',
      'pt-BR': 'Remover dos favoritos',
      'fr': 'Retirer des favoris',
    },
    'saving': {
      'en': 'Saving favorite',
      'es': 'Guardando favorito',
      'pt-BR': 'Salvando favorito',
      'fr': 'Enregistrement du favori',
    },
    'nextQualification': {
      'en': 'The next qualifying cycle begins in season {season}.',
      'es': 'El próximo ciclo de clasificación comienza en la temporada {season}.',
      'pt-BR': 'O próximo ciclo de classificação começa na temporada {season}.',
      'fr': 'Le prochain cycle de qualification commence à la saison {season}.',
    },
    'qualified': {
      'en': 'Qualified for the season {season} championship.',
      'es': 'Clasificado para el campeonato de la temporada {season}.',
      'pt-BR': 'Classificado para o campeonato da temporada {season}.',
      'fr': 'Qualifié pour le championnat de la saison {season}.',
    },
    'notQualified': {
      'en': 'Did not qualify for the season {season} championship.',
      'es': 'No se clasificó para el campeonato de la temporada {season}.',
      'pt-BR': 'Não se classificou para o campeonato da temporada {season}.',
      'fr': 'Non qualifié pour le championnat de la saison {season}.',
    },
    'nationalQuality': {
      'en': 'National-team quality: {quality}.',
      'es': 'Calidad de la selección: {quality}.',
      'pt-BR': 'Qualidade da seleção: {quality}.',
      'fr': 'Qualité de la sélection : {quality}.',
    },
    'favoriteFailed': {
      'en': 'Could not save this favorite. Try again.',
      'es': 'No se pudo guardar este favorito. Inténtalo de nuevo.',
      'pt-BR': 'Não foi possível salvar este favorito. Tente novamente.',
      'fr': 'Impossible d’enregistrer ce favori. Réessayez.',
    },
  };
  return copy[key]?[locale] ?? copy[key]?['en'] ?? key;
}

final class _ExplorerOption extends StatelessWidget {
  const _ExplorerOption({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => _WorldBrowseTile(
    leading: RoleIconBadge(icon: icon, label: title, color: color),
    title: title,
    subtitle: subtitle,
    trailing: trailing,
    onTap: onTap,
  );
}

final class _WorldBrowseTile extends StatelessWidget {
  const _WorldBrowseTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: ElevenwardColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: ElevenwardColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
          final stacked = constraints.maxWidth / textScale < 240;
          if (!stacked) {
            return ListTile(
              minVerticalPadding: 10,
              leading: leading,
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(subtitle),
              trailing:
                  trailing ??
                  (onTap == null
                      ? null
                      : const Icon(Icons.chevron_right_rounded)),
              onTap: onTap,
            );
          }
          return Semantics(
            button: onTap != null,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ExcludeSemantics(child: leading),
                        if (trailing != null)
                          trailing!
                        else if (onTap != null)
                          const ExcludeSemantics(
                            child: Icon(Icons.chevron_right_rounded),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
                style: TextStyle(
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
                style: TextStyle(
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
  const _TableHeader({required this.label, this.showColumns = true});
  final String label;
  final bool showColumns;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final title = Text(
          label.toUpperCase(),
          style: TextStyle(
            color: ElevenwardColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        );
        if (!showColumns) return title;
        final columns = Text(
          uiCopy(contentLocale(context), 'tableColumns'),
          style: TextStyle(color: ElevenwardColors.muted, fontSize: 11),
        );
        if (MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 5), columns],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            SizedBox(
              width: 102,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: columns,
              ),
            ),
          ],
        );
      },
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
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final difference =
        '${row.goalDifference >= 0 ? '+' : ''}${row.goalDifference}';
    return Semantics(
      label: _worldPolishCopy(locale, 'standingSummary')
          .replaceAll('{rank}', '$rank')
          .replaceAll('{club}', clubName)
          .replaceAll('{played}', '${row.played}')
          .replaceAll('{difference}', difference)
          .replaceAll('{points}', '${row.points}'),
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isPlayerClub
              ? ElevenwardColors.grassDark
              : ElevenwardColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlayerClub
                ? ElevenwardColors.grass
                : ElevenwardColors.line,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (club != null) ...[
                        _ClubMark(club: club!),
                        const SizedBox(width: 9),
                      ],
                      Expanded(
                        child: Text(
                          '$rank. $clubName',
                          style: TextStyle(
                            fontWeight: isPlayerClub
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    children: [
                      Text('${uiCopy(locale, 'matches')} ${row.played}'),
                      Text(
                        '${_worldPolishCopy(locale, 'goalDifferenceShort')} $difference',
                      ),
                      Text(
                        '${row.points} ${uiCopy(locale, 'pointsShort')}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              );
            }
            return Row(
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
                if (club != null) ...[
                  _ClubMark(club: club!),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    clubName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isPlayerClub
                          ? FontWeight.w900
                          : FontWeight.w600,
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
            );
          },
        ),
      ),
    );
  }
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
        side: BorderSide(color: ElevenwardColors.line),
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
                      style: TextStyle(
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
                    style: TextStyle(
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
            style: TextStyle(
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
            style: TextStyle(color: ElevenwardColors.muted, fontSize: 10),
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
                style: TextStyle(
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
