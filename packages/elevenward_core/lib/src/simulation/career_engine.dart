import '../content/content_models.dart';
import '../model/career_lifecycle.dart';
import '../model/career_progress.dart';
import '../model/career_snapshot.dart';
import '../model/career_types.dart';
import '../world/world_generator.dart';
import '../world/world_models.dart';
import 'world_simulator.dart';

final class CareerEngine {
  const CareerEngine();

  static const _worldSimulator = WorldSimulator();

  List<ContractOffer> contractOffers(
    CareerSnapshot snapshot, {
    WorldDefinition? definition,
  }) {
    final world = definition ?? buildLaunchWorld();
    final agent = agentFor(snapshot.activeAgentId);
    final clubs = [...world.clubs]..sort((left, right) {
        final leftInterest = _interest(snapshot, left);
        final rightInterest = _interest(snapshot, right);
        final comparison = rightInterest.compareTo(leftInterest);
        return comparison != 0 ? comparison : left.id.compareTo(right.id);
      });
    final standardCandidates = clubs
        .where((club) => club.id != snapshot.clubId)
        .where((club) => _interest(snapshot, club) >= 42)
        .take(3)
        .toList(growable: false);
    final freeAgencyFallback = snapshot.contract.seasonsRemaining <= 1 &&
        renewalOffer(snapshot, definition: world) == null &&
        standardCandidates.isEmpty;
    final candidates = freeAgencyFallback
        ? clubs
            .where((club) => club.id != snapshot.clubId)
            .where((club) => club.division == DivisionLevel.second)
            .take(3)
            .toList(growable: false)
        : standardCandidates;
    return candidates.map((club) {
      final fit = _tacticalFit(snapshot, club);
      final interest = _interest(snapshot, club);
      return ContractOffer(
        clubId: club.id,
        seasons: freeAgencyFallback
            ? 1
            : 2 + ((snapshot.seed ^ _stableHash(club.id)) & 1),
        weeklyWage: (((freeAgencyFallback ? 400 : 700) +
                    club.quality * (freeAgencyFallback ? 24 : 35) +
                    snapshot.player.reputation * 18) *
                (100 + agent.wageBonusPercent) /
                100)
            .round(),
        appearanceBonus: (freeAgencyFallback ? 75 : 150) + club.quality * 8,
        promisedRole: snapshot.player.overall >= club.quality + 2
            ? 'important'
            : snapshot.player.overall >= club.quality - 5
                ? 'rotation'
                : 'prospect',
        tacticalFit: fit,
        interestReason: freeAgencyFallback
            ? 'A second-division club offers a one-year route back through free agency.'
            : interest >= 70
                ? 'Your level and profile fit an immediate first-team need.'
                : fit >= 70
                    ? 'The manager believes your style fits the system.'
                    : 'The recruitment team sees room for you to grow.',
      );
    }).toList(growable: false);
  }

  ContractOffer? renewalOffer(
    CareerSnapshot snapshot, {
    WorldDefinition? definition,
  }) {
    if (snapshot.contract.seasonsRemaining > 1) return null;
    if (snapshot.player.managerTrust < 38 ||
        snapshot.contract.roleSatisfaction < 30) {
      return null;
    }
    final world = definition ?? buildLaunchWorld();
    final club = world.clubs.firstWhere((item) => item.id == snapshot.clubId);
    final strongSeason = snapshot.seasonPerformance.averageRating >= 7.0;
    return ContractOffer(
      clubId: club.id,
      seasons: strongSeason ? 3 : 2,
      weeklyWage:
          (snapshot.contract.weeklyWage * (strongSeason ? 1.25 : 1.10)).round(),
      appearanceBonus:
          snapshot.contract.appearanceBonus + (strongSeason ? 150 : 75),
      promisedRole:
          snapshot.player.overall >= club.quality ? 'important' : 'rotation',
      tacticalFit: _tacticalFit(snapshot, club),
      interestReason: strongSeason
          ? 'The club wants to reward your season with a longer renewal.'
          : 'Your trust and role record earned a renewal offer.',
    );
  }

  ContractOffer negotiateOffer({
    required CareerSnapshot snapshot,
    required ContractOffer offer,
    required NegotiationPriority priority,
  }) {
    final leverage = snapshot.player.reputation +
        snapshot.relationships.agent ~/ 2 +
        agentFor(snapshot.activeAgentId).wageBonusPercent;
    final accepted = leverage >=
        switch (priority) {
          NegotiationPriority.wage => 70,
          NegotiationPriority.role => 78,
          NegotiationPriority.term => 62,
        };
    if (!accepted) {
      return ContractOffer(
        clubId: offer.clubId,
        seasons: offer.seasons,
        weeklyWage: offer.weeklyWage,
        appearanceBonus: offer.appearanceBonus,
        promisedRole: offer.promisedRole,
        tacticalFit: offer.tacticalFit,
        interestReason:
            '${offer.interestReason} The club declined your requested ${priority.name} change because your leverage was $leverage.',
      );
    }
    return ContractOffer(
      clubId: offer.clubId,
      seasons: priority == NegotiationPriority.term
          ? offer.seasons + 1
          : offer.seasons,
      weeklyWage: priority == NegotiationPriority.wage
          ? (offer.weeklyWage * 1.08).round()
          : offer.weeklyWage,
      appearanceBonus: offer.appearanceBonus,
      promisedRole: priority == NegotiationPriority.role
          ? 'important'
          : offer.promisedRole,
      tacticalFit: offer.tacticalFit,
      interestReason:
          '${offer.interestReason} The club accepted your ${priority.name} request.',
    );
  }

  AgentDefinition agentFor(String id) => launchAgents.firstWhere(
        (agent) => agent.id == id,
        orElse: () => launchAgents.first,
      );

  /// Reports both successful and rejected interest so the UI never presents
  /// an unexplained transfer rejection.
  List<TransferInterest> transferMarketReport(
    CareerSnapshot snapshot, {
    WorldDefinition? definition,
  }) {
    final world = definition ?? buildLaunchWorld();
    final entries =
        world.clubs.where((club) => club.id != snapshot.clubId).map((club) {
      final interest = _interest(snapshot, club);
      final levelGap = club.quality - snapshot.player.overall;
      final reason = interest >= 42
          ? interest >= 70
              ? 'Your level and profile meet an immediate first-team need.'
              : 'Your form, reputation, and tactical fit cleared the club’s threshold.'
          : levelGap >= 8
              ? 'The club needs a higher current level for this role.'
              : snapshot.player.reputation < 35
                  ? 'Your reputation has not reached this recruitment network yet.'
                  : _tacticalFit(snapshot, club) < 65
                      ? 'The manager sees a weak fit with the current system.'
                      : 'The club chose a player with stronger recent form.';
      return TransferInterest(
        clubId: club.id,
        interest: interest.clamp(0, 100),
        accepted: interest >= 42,
        reason: reason,
      );
    }).toList();
    entries.sort((left, right) {
      final result = right.interest.compareTo(left.interest);
      return result != 0 ? result : left.clubId.compareTo(right.clubId);
    });
    return List.unmodifiable(entries);
  }

  CareerSnapshot completeOffseason(
    CareerSnapshot snapshot, {
    required DateTime updatedAt,
    ContractOffer? acceptedOffer,
    bool retire = false,
    WorldDefinition? definition,
  }) {
    if (snapshot.phase != CareerPhase.offseason) {
      throw StateError('The career is not in the offseason.');
    }
    final world = definition ?? buildLaunchWorld();
    final nextWorld = _worldSimulator.beginNextSeason(
      snapshot.world,
      snapshot.seed,
      definition: world,
    );
    final trophies = _playerTrophies(snapshot, world, nextWorld);
    final performance = snapshot.seasonPerformance;
    final summary = SeasonSummary(
      season: snapshot.season,
      age: snapshot.player.age,
      clubId: snapshot.clubId,
      appearances: performance.appearances,
      goals: performance.goals,
      assists: performance.assists,
      averageRating: performance.averageRating,
      trophies: trophies,
    );
    final withHistory = snapshot.copyWith(
      seasonHistory: [...snapshot.seasonHistory, summary],
      updatedAt: updatedAt.toUtc(),
    );
    if (retire || mustRetire(withHistory)) {
      if (retire &&
          !canChooseRetirement(withHistory) &&
          !mustRetire(withHistory)) {
        throw StateError('Retirement is not available yet.');
      }
      return retireCareer(withHistory, updatedAt.toUtc());
    }

    final validOffers = contractOffers(withHistory, definition: world);
    bool matchesTerms(ContractOffer candidate, ContractOffer accepted) =>
        candidate.clubId == accepted.clubId &&
        candidate.seasons == accepted.seasons &&
        candidate.weeklyWage == accepted.weeklyWage &&
        candidate.appearanceBonus == accepted.appearanceBonus &&
        candidate.promisedRole == accepted.promisedRole &&
        candidate.tacticalFit == accepted.tacticalFit;
    if (acceptedOffer != null &&
        !validOffers.any((offer) =>
            matchesTerms(offer, acceptedOffer) ||
            NegotiationPriority.values.any((priority) => matchesTerms(
                negotiateOffer(
                    snapshot: withHistory, offer: offer, priority: priority),
                acceptedOffer)))) {
      throw StateError('That contract offer is no longer available.');
    }
    final club = acceptedOffer == null
        ? world.clubs.firstWhere((item) => item.id == snapshot.clubId)
        : world.clubs.firstWhere((item) => item.id == acceptedOffer.clubId);
    final renewal = renewalOffer(withHistory, definition: world);
    if (acceptedOffer == null &&
        snapshot.contract.seasonsRemaining <= 1 &&
        renewal == null) {
      throw StateError(
        'The contract expired and the club did not offer a renewal. Choose a new club.',
      );
    }
    final contract = acceptedOffer == null
        ? snapshot.contract.seasonsRemaining <= 1
            ? ContractState(
                clubId: snapshot.clubId,
                seasonsRemaining: renewal!.seasons,
                weeklyWage: renewal.weeklyWage,
                appearanceBonus: renewal.appearanceBonus,
                promisedRole: renewal.promisedRole,
              )
            : snapshot.contract.copyWith(
                clubId: snapshot.clubId,
                seasonsRemaining: snapshot.contract.seasonsRemaining - 1,
              )
        : ContractState(
            clubId: acceptedOffer.clubId,
            seasonsRemaining: acceptedOffer.seasons,
            weeklyWage: acceptedOffer.weeklyWage,
            appearanceBonus: acceptedOffer.appearanceBonus,
            promisedRole: acceptedOffer.promisedRole,
          );
    return withHistory.copyWith(
      revision: snapshot.revision + 1,
      updatedAt: updatedAt.toUtc(),
      season: snapshot.season + 1,
      week: 1,
      clubId: club.id,
      clubName: club.name,
      points: 0,
      player: snapshot.player.copyWith(
        age: snapshot.player.age + 1,
        fitness: (snapshot.player.fitness + 12).clamp(1, 100),
        form: 55,
      ),
      phase: CareerPhase.inSeason,
      world: nextWorld,
      seasonPerformance: const SeasonPerformance(),
      contract: contract,
    );
  }

  CareerSnapshot applyEventChoice({
    required CareerSnapshot snapshot,
    required CareerEventDefinition event,
    required EventChoiceDefinition choice,
    required DateTime updatedAt,
  }) {
    if (!event.choices.any((candidate) => candidate.id == choice.id)) {
      throw ArgumentError('Choice does not belong to this event.');
    }
    final token = '${snapshot.season}:${snapshot.week}:${event.id}';
    if (snapshot.resolvedEventIds.contains(token)) {
      throw StateError('This event has already been resolved.');
    }
    final relationships = switch (event.category) {
      CareerEventCategory.manager => snapshot.relationships.copyWith(
          manager: snapshot.relationships.manager + choice.trustDelta,
        ),
      CareerEventCategory.teammate => snapshot.relationships.copyWith(
          teammates: snapshot.relationships.teammates + choice.trustDelta + 1,
        ),
      CareerEventCategory.agent => snapshot.relationships.copyWith(
          agent: snapshot.relationships.agent + choice.trustDelta + 1,
        ),
      CareerEventCategory.family => snapshot.relationships.copyWith(
          family: snapshot.relationships.family + choice.wellnessDelta,
        ),
      CareerEventCategory.community => snapshot.relationships.copyWith(
          community: snapshot.relationships.community + choice.reputationDelta,
        ),
      _ => snapshot.relationships,
    };
    final startsSponsor = event.category == CareerEventCategory.sponsor &&
        choice.moneyDelta > 0 &&
        !snapshot.sponsorIds.contains(event.id);
    return snapshot.copyWith(
      revision: snapshot.revision + 1,
      updatedAt: updatedAt.toUtc(),
      wellness: (snapshot.wellness + choice.wellnessDelta).clamp(0, 100),
      relationships: relationships,
      player: snapshot.player.copyWith(
        managerTrust: event.category == CareerEventCategory.manager
            ? (snapshot.player.managerTrust + choice.trustDelta).clamp(1, 100)
            : snapshot.player.managerTrust,
        reputation:
            (snapshot.player.reputation + choice.reputationDelta).clamp(0, 100),
        money: (snapshot.player.money + choice.moneyDelta).clamp(0, 1 << 52),
      ),
      resolvedEventIds: [...snapshot.resolvedEventIds, token],
      sponsorIds: startsSponsor
          ? {...snapshot.sponsorIds, event.id}.toList(growable: false)
          : snapshot.sponsorIds,
      sponsorContracts: startsSponsor
          ? [
              ...snapshot.sponsorContracts,
              SponsorContract(
                id: event.id,
                weeksRemaining: 12,
                weeklyPayout: (choice.moneyDelta / 4).round().clamp(100, 1000),
                obligation: 'maintain-reputation-35',
              ),
            ]
          : snapshot.sponsorContracts,
    );
  }

  List<CareerEventDefinition> eligibleEvents(
    CareerSnapshot snapshot,
    ContentCatalog catalog,
  ) {
    final categoryLastWeek = <CareerEventCategory, int>{};
    final eventCategories = {
      for (final event in catalog.careerEvents) event.id: event.category,
    };
    final currentWeek = (snapshot.season - 1) * 18 + snapshot.week;
    for (final token in snapshot.resolvedEventIds) {
      final parts = token.split(':');
      if (parts.length != 3) continue;
      final category = eventCategories[parts[2]];
      final season = int.tryParse(parts[0]);
      final week = int.tryParse(parts[1]);
      if (category == null || season == null || week == null) continue;
      final absoluteWeek = (season - 1) * 18 + week;
      if (absoluteWeek > (categoryLastWeek[category] ?? -1)) {
        categoryLastWeek[category] = absoluteWeek;
      }
    }
    bool available(CareerEventDefinition event) {
      if (snapshot.resolvedEventIds.contains(
        '${snapshot.season}:${snapshot.week}:${event.id}',
      )) {
        return false;
      }
      final lastWeek = categoryLastWeek[event.category];
      if (lastWeek != null && currentWeek - lastWeek < 4) return false;
      return switch (event.category) {
        CareerEventCategory.sponsor =>
          snapshot.player.reputation >= 35 && snapshot.sponsorContracts.isEmpty,
        CareerEventCategory.press => snapshot.player.reputation >= 20,
        CareerEventCategory.community => snapshot.player.reputation >= 15,
        CareerEventCategory.contract => snapshot.week >= 10,
        CareerEventCategory.wellness => snapshot.player.fitness <= 78,
        CareerEventCategory.agent =>
          snapshot.activeAgentId != 'agent-independent',
        _ => true,
      };
    }

    return List.unmodifiable(catalog.careerEvents.where(available));
  }

  CareerSnapshot purchaseLifestyleItem({
    required CareerSnapshot snapshot,
    required LifestyleItemDefinition item,
    required DateTime updatedAt,
  }) {
    if (snapshot.ownedItemIds.contains(item.id)) {
      throw StateError('Item is already owned.');
    }
    if (snapshot.player.money < item.price) {
      throw StateError('The player cannot afford this item.');
    }
    return snapshot.copyWith(
      revision: snapshot.revision + 1,
      updatedAt: updatedAt.toUtc(),
      ownedItemIds: [...snapshot.ownedItemIds, item.id],
      equippedItemIds: {
        ...snapshot.equippedItemIds,
        item.category.name: item.id,
      },
      wellness: (snapshot.wellness + item.wellnessEffect).clamp(0, 100),
      player: snapshot.player.copyWith(
        money: snapshot.player.money - item.price,
        reputation:
            (snapshot.player.reputation + item.reputationEffect).clamp(0, 100),
      ),
    );
  }

  CareerSnapshot equipLifestyleItem({
    required CareerSnapshot snapshot,
    required LifestyleItemDefinition item,
    required DateTime updatedAt,
  }) {
    if (!snapshot.ownedItemIds.contains(item.id)) {
      throw StateError('Only owned items can be equipped.');
    }
    if (snapshot.equippedItemIds[item.category.name] == item.id) {
      return snapshot;
    }
    return snapshot.copyWith(
      revision: snapshot.revision + 1,
      updatedAt: updatedAt.toUtc(),
      equippedItemIds: {
        ...snapshot.equippedItemIds,
        item.category.name: item.id,
      },
    );
  }

  CareerSnapshot chooseAgent({
    required CareerSnapshot snapshot,
    required String agentId,
    required DateTime updatedAt,
  }) {
    if (!launchAgents.any((agent) => agent.id == agentId)) {
      throw ArgumentError.value(
          agentId, 'agentId', 'Invalid agent identifier.');
    }
    if (snapshot.activeAgentId == agentId) return snapshot;
    final agent = agentFor(agentId);
    return snapshot.copyWith(
      revision: snapshot.revision + 1,
      updatedAt: updatedAt.toUtc(),
      activeAgentId: agentId,
      relationships: snapshot.relationships.copyWith(
        agent: 50 + agent.relationshipBonus,
      ),
    );
  }

  bool isNationalTeamEligible(CareerSnapshot snapshot) =>
      snapshot.player.reputation >= 60 && snapshot.player.overall >= 68;

  bool hasNationalTeamInvitation(CareerSnapshot snapshot) {
    if (snapshot.phase != CareerPhase.inSeason ||
        !isNationalTeamEligible(snapshot) ||
        snapshot.nationalTeam.decisionSeason == snapshot.season) {
      return false;
    }
    final tournament = snapshot.world.competitions['major-national-tournament'];
    if (tournament == null || tournament.isComplete) return false;
    return tournament.fixtures.any(
      (fixture) =>
          !fixture.isPlayed &&
          fixture.matchweek >= snapshot.week &&
          (fixture.homeId == snapshot.player.nationalTeamId ||
              fixture.awayId == snapshot.player.nationalTeamId),
    );
  }

  CareerSnapshot decideNationalTeamCallUp({
    required CareerSnapshot snapshot,
    required bool accept,
    required DateTime updatedAt,
  }) {
    if (!hasNationalTeamInvitation(snapshot)) {
      throw StateError('There is no active national-team call-up to decide.');
    }
    return snapshot.copyWith(
      revision: snapshot.revision + 1,
      updatedAt: updatedAt.toUtc(),
      nationalTeam: snapshot.nationalTeam.copyWith(
        decision: accept
            ? NationalTeamDecision.accepted
            : NationalTeamDecision.declined,
        decisionSeason: snapshot.season,
      ),
    );
  }

  List<String> _playerTrophies(
    CareerSnapshot snapshot,
    WorldDefinition world,
    CareerWorldState honors,
  ) {
    final trophies = <String>[];
    final table = snapshot.world.table(
      snapshot.world.leagueIdForClub(snapshot.clubId),
    );
    if (table.first.clubId == snapshot.clubId) trophies.add('league-title');
    for (final entry in honors.domesticCupWinners.entries) {
      if (entry.value == snapshot.clubId) trophies.add(entry.key);
    }
    if (honors.internationalClubWinner == snapshot.clubId) {
      trophies.add(world.internationalClubCompetition.id);
    }
    if (honors.nationalTournamentWinner == snapshot.player.nationalTeamId &&
        snapshot.nationalTeam.acceptedFor(snapshot.season)) {
      trophies.add('major-national-tournament');
    }
    return List.unmodifiable(trophies);
  }

  int _interest(CareerSnapshot snapshot, ClubDefinition club) {
    final levelFit = 70 - (club.quality - snapshot.player.overall).abs() * 3;
    final relationshipReach =
        snapshot.rulesVersion == CareerSnapshot.currentRulesVersion
            ? snapshot.relationships.agent ~/ 10 +
                snapshot.relationships.community ~/ 20
            : 0;
    return levelFit +
        snapshot.player.reputation ~/ 3 +
        _tacticalFit(snapshot, club) ~/ 5 +
        relationshipReach +
        agentFor(snapshot.activeAgentId).marketReachBonus;
  }

  int _tacticalFit(CareerSnapshot snapshot, ClubDefinition club) => (55 +
          ((club.attack + club.defense + snapshot.player.archetype.index * 7) %
              31))
      .clamp(1, 100);

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
