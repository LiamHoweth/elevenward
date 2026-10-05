import 'package:elevenward_core/elevenward_core.dart';

/// Deterministic, production-engine career states used only by the App Store
/// simulator capture workflow. Nothing in this file is linked into release
/// builds.
final class AppStoreCareerFixture {
  const AppStoreCareerFixture({
    required this.seed,
    required this.midCareer,
    required this.lateCareer,
  });

  final int seed;
  final CareerSnapshot midCareer;
  final CareerSnapshot lateCareer;
}

final class AppStoreCareerFixtureBuilder {
  const AppStoreCareerFixtureBuilder();

  static const _weekly = WeeklySimulator();
  static const _worldSimulator = WorldSimulator();
  static const _engine = CareerEngine();

  AppStoreCareerFixture build({int maximumSeed = 500}) {
    final world = buildLaunchWorld();
    final catalog = buildLaunchContent();
    for (var seed = 1; seed <= maximumSeed; seed++) {
      var snapshot = CareerSnapshot.newCareer(
        careerId: 'app-store-career',
        seed: seed,
        updatedAt: DateTime.utc(2026, 1, 1),
        contentVersion: catalog.version,
        worldDefinition: world,
        player: PlayerState.newCareer(
          id: 'app-store-player',
          name: 'Mika Vale',
          archetype: Archetype.completeForward,
          nationalTeamId: 'united-states',
        ),
      );
      CareerSnapshot? midCareer;
      CareerSnapshot? lateCareer;

      while (!snapshot.retired && snapshot.player.age <= 34) {
        if (midCareer == null && _isQualifiedMidCareer(snapshot, world)) {
          final qualifyingSeason = snapshot.season;
          while (snapshot.season == qualifyingSeason &&
              (snapshot.phase != CareerPhase.inSeason || snapshot.week < 8)) {
            snapshot = _advance(snapshot, world, catalog);
          }
          if (snapshot.phase == CareerPhase.inSeason) {
            midCareer = _enrichMidCareer(snapshot, world, catalog);
            snapshot = midCareer;
          }
        }
        if (snapshot.player.age == 34 &&
            snapshot.phase == CareerPhase.inSeason) {
          lateCareer = snapshot;
          break;
        }
        snapshot = _advance(snapshot, world, catalog);
      }

      if (midCareer != null && lateCareer != null) {
        return AppStoreCareerFixture(
          seed: seed,
          midCareer: midCareer,
          lateCareer: lateCareer,
        );
      }
    }
    throw StateError(
      'No qualifying screenshot career found through seed $maximumSeed.',
    );
  }

  CareerSnapshot _advance(
    CareerSnapshot snapshot,
    WorldDefinition world,
    ContentCatalog catalog,
  ) {
    if (snapshot.phase == CareerPhase.internationalCallup) {
      return _engine.decideNationalTeamCallUp(
        snapshot: snapshot,
        accept: true,
        updatedAt: snapshot.updatedAt.add(const Duration(minutes: 1)),
        definition: world,
      );
    }
    if (snapshot.phase == CareerPhase.inSeason ||
        snapshot.phase == CareerPhase.internationalTournament) {
      final wasClubSeason = snapshot.phase == CareerPhase.inSeason;
      final opponent = _worldSimulator.opponentFor(snapshot, definition: world);
      final situations = catalog.matchSituations
          .where((item) => item.position == snapshot.player.position)
          .toList(growable: false);
      final situation =
          situations[(snapshot.seed ^ snapshot.revision).abs() %
              situations.length];
      final approach =
          SpotlightApproach.values[(snapshot.seed + snapshot.revision) % 3];
      final focus = PlayerAttribute
          .values[(snapshot.seed + snapshot.week + snapshot.season) % 8];
      final intensity = snapshot.player.fitness < 64
          ? TrainingIntensity.light
          : TrainingIntensity.intensive;
      var next = _weekly
          .advance(
            snapshot: snapshot,
            choice: WeeklyChoice(
              focus: focus,
              intensity: intensity,
              spotlightApproach: approach,
            ),
            opponent: opponent,
            situationOption: situation.options.firstWhere(
              (option) => option.approach == approach,
            ),
            updatedAt: snapshot.updatedAt.add(const Duration(days: 7)),
            definition: world,
          )
          .snapshot;
      if (wasClubSeason && next.phase == CareerPhase.inSeason) {
        final events = _engine.eligibleEvents(next, catalog);
        if (events.isNotEmpty) {
          final event =
              events[(next.seed ^ next.revision).abs() % events.length];
          final choice =
              event.choices[(next.seed + next.week) % event.choices.length];
          next = _engine.applyEventChoice(
            snapshot: next,
            event: event,
            choice: choice,
            updatedAt: next.updatedAt.add(const Duration(minutes: 1)),
          );
        }
      }
      return next;
    }
    if (snapshot.phase == CareerPhase.offseason ||
        snapshot.phase == CareerPhase.contractDecision ||
        snapshot.phase == CareerPhase.retirementDecision) {
      ContractOffer? offer;
      final renewal = _engine.renewalOffer(snapshot, definition: world);
      if (snapshot.contract.seasonsRemaining <= 1 && renewal == null) {
        final offers = _engine.contractOffers(snapshot, definition: world);
        if (offers.isNotEmpty) offer = offers.first;
      }
      return _engine.completeOffseason(
        snapshot,
        acceptedOffer: offer,
        definition: world,
        updatedAt: snapshot.updatedAt.add(const Duration(days: 21)),
      );
    }
    throw StateError('Unsupported fixture phase ${snapshot.phase.name}.');
  }

  bool _isQualifiedMidCareer(CareerSnapshot snapshot, WorldDefinition world) {
    if (snapshot.phase != CareerPhase.inSeason ||
        snapshot.player.age < 26 ||
        snapshot.player.age > 29 ||
        snapshot.player.overall < 80 ||
        snapshot.player.overall > 88 ||
        snapshot.nationalTeam.caps == 0) {
      return false;
    }
    final trophyCount = snapshot.seasonHistory.fold<int>(
      0,
      (total, season) => total + season.trophies.length,
    );
    final leagueId = snapshot.world.leagueIdForClub(snapshot.clubId);
    final league = world.leagues.firstWhere((item) => item.id == leagueId);
    return trophyCount >= 2 && league.division == DivisionLevel.first;
  }

  CareerSnapshot _enrichMidCareer(
    CareerSnapshot snapshot,
    WorldDefinition world,
    ContentCatalog catalog,
  ) {
    var enriched = snapshot;
    if (enriched.activeAgentId == 'agent-independent') {
      enriched = _engine.chooseAgent(
        snapshot: enriched,
        agentId: 'agent-global-network',
        updatedAt: enriched.updatedAt.add(const Duration(minutes: 1)),
      );
    }
    if (enriched.sponsorContracts.isEmpty) {
      final sponsorEvents = _engine
          .eligibleEvents(enriched, catalog)
          .where((event) => event.category == CareerEventCategory.sponsor)
          .toList(growable: false);
      if (sponsorEvents.isNotEmpty) {
        final event = sponsorEvents.first;
        enriched = _engine.applyEventChoice(
          snapshot: enriched,
          event: event,
          choice: event.choices.first,
          updatedAt: enriched.updatedAt.add(const Duration(minutes: 1)),
        );
      }
    }
    final currentCountry = world.club(enriched.clubId).countryId;
    final targetLeague = world.leagues.firstWhere(
      (league) =>
          league.division == DivisionLevel.first &&
          league.countryId != currentCountry &&
          enriched.world.leagueParticipants[league.id]!.isNotEmpty,
    );
    final preferredClubId =
        enriched.world.leagueParticipants[targetLeague.id]!.first;
    return _engine.fileTransferRequest(
      snapshot: enriched,
      targetLeagueId: targetLeague.id,
      preferredClubId: preferredClubId,
      updatedAt: enriched.updatedAt.add(const Duration(minutes: 1)),
      definition: world,
    );
  }
}
