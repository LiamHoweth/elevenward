import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n_context.dart';
import '../league_presentation.dart';
import '../theme.dart';
import '../ui_copy.dart';

String transferComparisonTitle(String locale) => _copy(locale, 'compare');

/// Read-only comparison of the saved contract and a generated market offer.
/// League membership comes from career state, so promoted clubs are shown in
/// their actual division rather than their originally authored division.
({
  ClubDefinition? currentClub,
  ClubDefinition? offeredClub,
  LeagueDefinition? currentLeague,
  LeagueDefinition? offeredLeague,
  int? currentFit,
  int? offeredFit,
})
transferComparison({
  required CareerSnapshot career,
  required ContractOffer offer,
  required WorldDefinition world,
  CareerWorldState? marketState,
}) {
  ClubDefinition? findClub(String id) {
    for (final club in world.clubs) {
      if (club.id == id) return club;
    }
    return null;
  }

  LeagueDefinition? findLeague(CareerWorldState? state, String clubId) {
    if (state == null) return null;
    for (final league in world.leagues) {
      if (state.leagueParticipants[league.id]?.contains(clubId) ?? false) {
        return league;
      }
    }
    return null;
  }

  final currentClub = findClub(career.contract.clubId);
  final offeredClub = findClub(offer.clubId);
  final hasCompleteWorld = world.leagues.every(
    (league) =>
        career.world.leagueParticipants.containsKey(league.id) &&
        career.world.leagueRecords.containsKey(league.id),
  );
  final nextSeason =
      marketState ??
      (career.phase == CareerPhase.offseason && hasCompleteWorld
          ? const WorldSimulator().beginNextSeason(
              career.world,
              career.seed,
              definition: world,
            )
          : null);
  return (
    currentClub: currentClub,
    offeredClub: offeredClub,
    currentLeague: findLeague(career.world, career.contract.clubId),
    offeredLeague: findLeague(nextSeason, offer.clubId),
    currentFit: currentClub == null
        ? null
        : calculateTacticalFit(career, currentClub),
    // Generated and negotiated offers retain the engine's canonical fit.
    offeredFit: offeredClub == null ? null : offer.tacticalFit,
  );
}

final class TransferComparisonPanel extends StatelessWidget {
  const TransferComparisonPanel({
    super.key,
    required this.career,
    required this.offer,
    required this.world,
    this.marketState,
  });

  final CareerSnapshot career;
  final ContractOffer offer;
  final WorldDefinition world;
  final CareerWorldState? marketState;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final comparison = transferComparison(
      career: career,
      offer: offer,
      world: world,
      marketState: marketState,
    );
    final number = NumberFormat.decimalPattern(locale.replaceAll('-', '_'));
    String currency(int value) => '£${number.format(value)}';
    String wage(int value) =>
        '${currency(value)} / ${uiCopy(locale, 'week').toLowerCase()}';
    String term(int value, String timingKey) =>
        '${number.format(value)} ${_copy(locale, value == 1 ? 'season' : 'seasons')} '
        '· ${_copy(locale, timingKey)}';
    String league(LeagueDefinition? value, String timingKey) => value == null
        ? _copy(locale, 'unavailable')
        : '${leagueDisplayName(value)} · ${_copy(locale, timingKey)}';
    String fit(int? value) =>
        value == null ? _copy(locale, 'unavailable') : '$value%';
    final wageChange = offer.weeklyWage - career.contract.weeklyWage;
    final metrics =
        <({String id, String label, String current, String offered})>[
          (
            id: 'wage',
            label: uiCopy(locale, 'weeklyWage'),
            current: wage(career.contract.weeklyWage),
            offered: wage(offer.weeklyWage),
          ),
          (
            id: 'bonus',
            label: uiCopy(locale, 'appearanceBonus'),
            current: currency(career.contract.appearanceBonus),
            offered: currency(offer.appearanceBonus),
          ),
          (
            id: 'term',
            label: _copy(locale, 'contractTerm'),
            current: term(career.contract.seasonsRemaining, 'remaining'),
            offered: term(offer.seasons, 'newTerm'),
          ),
          (
            id: 'role',
            label: uiCopy(locale, 'promisedRole'),
            current: localizedPromisedRole(
              locale,
              career.contract.promisedRole,
            ),
            offered: localizedPromisedRole(locale, offer.promisedRole),
          ),
          (
            id: 'league',
            label: _copy(locale, 'league'),
            current: league(comparison.currentLeague, 'thisSeason'),
            offered: league(comparison.offeredLeague, 'nextSeason'),
          ),
          (
            id: 'fit',
            label: _copy(locale, 'tacticalFit'),
            current: fit(comparison.currentFit),
            offered: fit(comparison.offeredFit),
          ),
        ];
    return BroadcastPanel(
      key: ValueKey('transfer-comparison-${offer.clubId}'),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 420 ||
              MediaQuery.textScalerOf(context).scale(14) > 19;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                transferComparisonTitle(locale),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ElevenwardColors.cream,
                ),
              ),
              const SizedBox(height: 12),
              for (final metric in metrics) ...[
                _ComparisonMetric(
                  key: ValueKey('transfer-comparison-${metric.id}'),
                  label: metric.label,
                  current: metric.current,
                  offered: metric.offered,
                  currentLabel: _copy(locale, 'current'),
                  offeredLabel: _copy(locale, 'offer'),
                  stacked: stacked,
                ),
                if (metric.id != 'fit')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                '${_copy(locale, 'wageChange')}: '
                '${wageChange > 0
                    ? '+'
                    : wageChange < 0
                    ? '−'
                    : ''}'
                '${wage(wageChange.abs())}',
                style: TextStyle(
                  color: wageChange > 0
                      ? ElevenwardColors.grass
                      : wageChange < 0
                      ? ElevenwardColors.coral
                      : ElevenwardColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    super.key,
    required this.label,
    required this.current,
    required this.offered,
    required this.currentLabel,
    required this.offeredLabel,
    required this.stacked,
  });

  final String label;
  final String current;
  final String offered;
  final String currentLabel;
  final String offeredLabel;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    Widget value(String heading, String text, {bool highlighted = false}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: TextStyle(color: ElevenwardColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              text,
              style: TextStyle(
                color: ElevenwardColors.cream,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );

    return Semantics(
      label: '$label. $currentLabel: $current. $offeredLabel: $offered.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ElevenwardColors.cream,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          if (stacked) ...[
            value(currentLabel, current),
            const SizedBox(height: 8),
            value(offeredLabel, offered, highlighted: true),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: value(currentLabel, current)),
                const SizedBox(width: 16),
                Expanded(
                  child: value(offeredLabel, offered, highlighted: true),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _copy(String locale, String key) =>
    _translations[key]?[locale] ?? _translations[key]!['en']!;

const _translations = <String, Map<String, String>>{
  'compare': {
    'en': 'Compare with your current contract',
    'es': 'Compara con tu contrato actual',
    'pt-BR': 'Compare com seu contrato atual',
    'fr': 'Comparer avec votre contrat actuel',
  },
  'current': {
    'en': 'Current contract',
    'es': 'Contrato actual',
    'pt-BR': 'Contrato atual',
    'fr': 'Contrat actuel',
  },
  'offer': {'en': 'Offer', 'es': 'Oferta', 'pt-BR': 'Oferta', 'fr': 'Offre'},
  'league': {
    'en': 'League',
    'es': 'Liga',
    'pt-BR': 'Liga',
    'fr': 'Championnat',
  },
  'contractTerm': {
    'en': 'Contract length',
    'es': 'Duración del contrato',
    'pt-BR': 'Duração do contrato',
    'fr': 'Durée du contrat',
  },
  'season': {
    'en': 'season',
    'es': 'temporada',
    'pt-BR': 'temporada',
    'fr': 'saison',
  },
  'seasons': {
    'en': 'seasons',
    'es': 'temporadas',
    'pt-BR': 'temporadas',
    'fr': 'saisons',
  },
  'remaining': {
    'en': 'remaining',
    'es': 'restantes',
    'pt-BR': 'restantes',
    'fr': 'restantes',
  },
  'newTerm': {
    'en': 'new contract',
    'es': 'nuevo contrato',
    'pt-BR': 'novo contrato',
    'fr': 'nouveau contrat',
  },
  'thisSeason': {
    'en': 'this season',
    'es': 'esta temporada',
    'pt-BR': 'nesta temporada',
    'fr': 'cette saison',
  },
  'nextSeason': {
    'en': 'next season',
    'es': 'próxima temporada',
    'pt-BR': 'próxima temporada',
    'fr': 'saison prochaine',
  },
  'tacticalFit': {
    'en': 'Tactical fit',
    'es': 'Afinidad táctica',
    'pt-BR': 'Compatibilidade tática',
    'fr': 'Compatibilité tactique',
  },
  'wageChange': {
    'en': 'Weekly wage change',
    'es': 'Cambio de salario semanal',
    'pt-BR': 'Mudança no salário semanal',
    'fr': 'Évolution du salaire hebdomadaire',
  },
  'unavailable': {
    'en': 'Unavailable',
    'es': 'No disponible',
    'pt-BR': 'Indisponível',
    'fr': 'Indisponible',
  },
};
