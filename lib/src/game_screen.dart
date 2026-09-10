import 'dart:async';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n_context.dart';
import 'league_presentation.dart';
import 'storage/career_store.dart';
import 'theme.dart';
import 'ui_copy.dart';
import 'util/uuid.dart';
import 'widgets/transfer_request_sheet.dart';

enum _GamePhase {
  focus,
  spotlight,
  recap,
  careerEvent,
  internationalCallup,
  offseason,
  retired,
}

_GamePhase _gamePhaseFor(CareerPhase phase) => switch (phase) {
  CareerPhase.internationalCallup => _GamePhase.internationalCallup,
  CareerPhase.offseason => _GamePhase.offseason,
  CareerPhase.retired => _GamePhase.retired,
  _ => _GamePhase.focus,
};

const _simulator = WeeklySimulator();
const _worldSimulator = WorldSimulator();
const _careerEngine = CareerEngine();
final _contentCatalog = buildLaunchContent();

String _matchTeamName(
  CareerSnapshot career,
  OpponentContext opponent,
  WorldDefinition world,
) => opponent.competitionKind == CompetitionKind.nationalTournament
    ? world.nationalTeams
          .firstWhere((team) => team.id == career.player.nationalTeamId)
          .countryName
    : career.clubName;

const _fallbackOpponents = <OpponentContext>[
  OpponentContext(
    clubId: 'eng2-harbour',
    clubName: 'Harbour Rovers',
    quality: 64,
    tacticalFit: 72,
    isHome: true,
  ),
  OpponentContext(
    clubId: 'eng2-copperhill',
    clubName: 'Copperhill FC',
    quality: 60,
    tacticalFit: 65,
    isHome: false,
  ),
  OpponentContext(
    clubId: 'eng2-wrenford',
    clubName: 'Wrenford City',
    quality: 69,
    tacticalFit: 58,
    isHome: true,
  ),
  OpponentContext(
    clubId: 'eng2-orchard',
    clubName: 'Orchard Vale',
    quality: 57,
    tacticalFit: 76,
    isHome: false,
  ),
  OpponentContext(
    clubId: 'eng2-ironbridge',
    clubName: 'Ironbridge 04',
    quality: 71,
    tacticalFit: 61,
    isHome: true,
  ),
  OpponentContext(
    clubId: 'eng2-beacon',
    clubName: 'Beacon Town',
    quality: 63,
    tacticalFit: 69,
    isHome: false,
  ),
  OpponentContext(
    clubId: 'eng2-kingsmere',
    clubName: 'Kingsmere Athletic',
    quality: 67,
    tacticalFit: 64,
    isHome: true,
  ),
  OpponentContext(
    clubId: 'eng2-ashcombe',
    clubName: 'Ashcombe Union',
    quality: 59,
    tacticalFit: 73,
    isHome: false,
  ),
  OpponentContext(
    clubId: 'eng2-redwick',
    clubName: 'Redwick Borough',
    quality: 66,
    tacticalFit: 62,
    isHome: true,
  ),
];

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.careerStore,
    this.slotIndex = 0,
    this.initialCareer,
    this.initialFocus = PlayerAttribute.finishing,
    this.onCareerChanged,
    this.onReviewOpportunity,
    this.onFocusPreferenceChanged,
    this.contentCatalog,
    this.avatarId = 'initials',
    this.rewardModifiers = RewardModifiers.standard,
  });

  final CareerStore? careerStore;
  final int slotIndex;
  final CareerSnapshot? initialCareer;
  final PlayerAttribute initialFocus;
  final Future<void> Function(CareerSnapshot snapshot, String eventType)?
  onCareerChanged;
  final Future<void> Function(CareerSnapshot snapshot)? onReviewOpportunity;
  final Future<void> Function(PlayerAttribute focus)? onFocusPreferenceChanged;
  final ContentCatalog? contentCatalog;
  final String avatarId;
  final RewardModifiers rewardModifiers;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late CareerSnapshot _career;
  bool _loading = false;
  _GamePhase _phase = _GamePhase.focus;
  late PlayerAttribute _focus;
  bool _focusExpanded = false;
  TrainingIntensity _intensity = TrainingIntensity.balanced;
  SpotlightApproach? _approach;
  CareerEventDefinition? _careerEvent;
  WeeklyResult? _lastResult;
  bool _showWhy = false;
  bool _resolvingDecision = false;

  @override
  void initState() {
    super.initState();
    _career = widget.initialCareer ?? _newCareer();
    _focus = widget.initialFocus;
    _phase = _gamePhaseFor(_career.phase);
    if (widget.initialCareer == null && widget.careerStore != null) {
      _hydrateCareer();
    }
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialCareer;
    if (incoming != null && incoming.revision > _career.revision) {
      setState(() {
        _career = incoming;
        _focus = widget.initialFocus;
        _phase = _gamePhaseFor(incoming.phase);
        _approach = null;
        _careerEvent = null;
        _lastResult = null;
        _focusExpanded = false;
        _intensity = TrainingIntensity.balanced;
      });
    }
  }

  ContentCatalog get _catalog => widget.contentCatalog ?? _contentCatalog;
  WorldDefinition get _world => _catalog.world;

  CareerSnapshot _newCareer() {
    final careerId = generateUuidV4();
    return CareerSnapshot.newCareer(
      careerId: careerId,
      seed: uuidSeed(careerId),
      updatedAt: DateTime.now().toUtc(),
      contentVersion: _catalog.version,
      worldDefinition: _world,
      player: PlayerState.newCareer(
        id: generateUuidV4(),
        name: 'Mika Vale',
        archetype: Archetype.poacher,
      ),
    );
  }

  Future<void> _hydrateCareer() async {
    setState(() => _loading = true);
    try {
      final stored = await widget.careerStore!.loadSlot(widget.slotIndex);
      if (!mounted) return;
      if (stored == null) {
        await widget.careerStore!.saveSlot(widget.slotIndex, _career);
      } else {
        _career = stored;
        _focus = await widget.careerStore!.loadWeeklyFocus(stored.careerId);
        _phase = _gamePhaseFor(stored.phase);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  OpponentContext get _opponent {
    try {
      return _worldSimulator.opponentFor(_career, definition: _world);
    } on Object {
      return _fallbackOpponents[(_career.week - 1) % _fallbackOpponents.length];
    }
  }

  MatchSituationDefinition get _situation {
    final options = _catalog.matchSituations
        .where((item) => item.position == _career.player.position)
        .toList(growable: false);
    return options[(_career.seed ^ _career.revision).abs() % options.length];
  }

  Future<void> _changeFocus(PlayerAttribute value) async {
    setState(() {
      _focus = value;
      _focusExpanded = false;
    });
    try {
      final callback = widget.onFocusPreferenceChanged;
      if (callback != null) {
        await callback(value);
      } else {
        await widget.careerStore?.saveWeeklyFocus(_career.careerId, value);
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiCopy(contentLocale(context), 'focusSaveFailed')),
        ),
      );
    }
  }

  Future<void> _openSpotlight() async {
    final opponent = _opponent;
    final opened = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: uiCopy(contentLocale(context), 'preparingMatchup'),
      transitionDuration: motionDuration(
        context,
        const Duration(milliseconds: 180),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _PregameMatchupOverlay(
            career: _career,
            opponent: opponent,
            world: _world,
          ),
    );
    if (!mounted || opened != true) return;
    setState(() {
      _phase = _GamePhase.spotlight;
      _approach = null;
      _showWhy = false;
    });
  }

  Future<void> _commitDecision() async {
    final approach = _approach;
    if (approach == null || _resolvingDecision) return;
    setState(() => _resolvingDecision = true);
    final result = _simulator.advance(
      snapshot: _career,
      choice: WeeklyChoice(
        focus: _focus,
        intensity: _intensity,
        spotlightApproach: approach,
      ),
      opponent: _opponent,
      situationOption: _situation.options.firstWhere(
        (option) => option.approach == approach,
      ),
      updatedAt: DateTime.now().toUtc(),
      modifiers: widget.rewardModifiers,
      definition: _world,
    );
    final eligibleEvents = result.snapshot.phase == CareerPhase.inSeason
        ? _careerEngine.eligibleEvents(result.snapshot, _catalog)
        : const <CareerEventDefinition>[];
    final event = eligibleEvents.isEmpty
        ? null
        : eligibleEvents[(result.snapshot.seed ^ result.snapshot.revision)
                  .abs() %
              eligibleEvents.length];
    setState(() {
      _career = result.snapshot;
      _careerEvent = event;
      _lastResult = result;
      _phase = _GamePhase.recap;
      _approach = null;
      _showWhy = false;
    });
    if (result.spotlightSucceeded) {
      unawaited(HapticFeedback.mediumImpact());
    } else {
      unawaited(HapticFeedback.selectionClick());
    }
    try {
      await _persist(result.snapshot, 'week_completed');
    } finally {
      if (mounted) setState(() => _resolvingDecision = false);
    }
  }

  void _continueFromRecap() {
    setState(() {
      if (_careerEvent != null) {
        _phase = _GamePhase.careerEvent;
      } else {
        _advanceTo(_career);
      }
    });
    if (_phase == _GamePhase.offseason) {
      unawaited(_requestReviewAfterPause());
    }
  }

  Future<void> _requestReviewAfterPause() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || _phase != _GamePhase.offseason) return;
    await widget.onReviewOpportunity?.call(_career);
  }

  Future<void> _chooseEvent(EventChoiceDefinition choice) async {
    final event = _careerEvent;
    if (event == null || _resolvingDecision) return;
    setState(() => _resolvingDecision = true);
    final resolved = _careerEngine.applyEventChoice(
      snapshot: _career,
      event: event,
      choice: choice,
      updatedAt: DateTime.now().toUtc(),
      modifiers: widget.rewardModifiers,
    );
    setState(() {
      _career = resolved;
      _advanceTo(resolved);
    });
    unawaited(HapticFeedback.selectionClick());
    try {
      await _persist(resolved, 'career_event_resolved');
    } finally {
      if (mounted) setState(() => _resolvingDecision = false);
    }
  }

  void _advanceTo(CareerSnapshot next) {
    _career = next;
    _phase = _gamePhaseFor(next.phase);
    _intensity = TrainingIntensity.balanced;
    _approach = null;
    _careerEvent = null;
    _lastResult = null;
    _focusExpanded = false;
    _showWhy = false;
  }

  Future<void> _completeOffseason({
    ContractOffer? acceptedOffer,
    bool retire = false,
  }) async {
    final next = _careerEngine.completeOffseason(
      _career,
      acceptedOffer: acceptedOffer,
      retire: retire,
      updatedAt: DateTime.now().toUtc(),
      definition: _world,
    );
    setState(() {
      _career = next;
      _phase = next.retired ? _GamePhase.retired : _GamePhase.focus;
      _intensity = TrainingIntensity.balanced;
      _focusExpanded = false;
    });
    await _persist(
      next,
      next.retired ? 'career_retired' : 'offseason_completed',
    );
  }

  Future<void> _editTransferRequest() async {
    final draft = await showTransferRequestFlow(
      context: context,
      career: _career,
      world: _world,
    );
    if (draft == null || !mounted) return;
    final next = _careerEngine.fileTransferRequest(
      snapshot: _career,
      targetLeagueId: draft.targetLeagueId,
      preferredClubId: draft.preferredClubId,
      updatedAt: DateTime.now().toUtc(),
      definition: _world,
    );
    setState(() => _career = next);
    await _persist(next, 'transfer_requested');
  }

  Future<void> _decideNationalCallup(bool accept) async {
    if (_resolvingDecision) return;
    setState(() => _resolvingDecision = true);
    final next = _careerEngine.decideNationalTeamCallUp(
      snapshot: _career,
      accept: accept,
      updatedAt: DateTime.now().toUtc(),
      definition: _world,
    );
    setState(() {
      _career = next;
      _phase = _gamePhaseFor(next.phase);
      _resolvingDecision = false;
    });
    await _persist(
      next,
      accept ? 'national_callup_accepted' : 'national_callup_declined',
    );
  }

  Future<void> _persist(CareerSnapshot snapshot, String eventType) async {
    await widget.careerStore?.saveSlot(
      widget.slotIndex,
      snapshot,
      eventType: eventType,
    );
    await widget.onCareerChanged?.call(snapshot, eventType);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ElevenwardColors.grass),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _PitchBackground()),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  phase: _phase,
                  onBack: _phase == _GamePhase.spotlight
                      ? () => setState(() => _phase = _GamePhase.focus)
                      : null,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: motionDuration(
                      context,
                      const Duration(milliseconds: 280),
                    ),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: switch (_phase) {
                      _GamePhase.focus => _FocusView(
                        key: const ValueKey('focus'),
                        career: _career,
                        avatarId: widget.avatarId,
                        opponent: _opponent,
                        world: _world,
                        focus: _focus,
                        focusExpanded: _focusExpanded,
                        intensity: _intensity,
                        onFocusToggle: () =>
                            setState(() => _focusExpanded = !_focusExpanded),
                        onFocusChanged: _changeFocus,
                        onIntensityChanged: (value) =>
                            setState(() => _intensity = value),
                        onContinue: _openSpotlight,
                      ),
                      _GamePhase.spotlight => _SpotlightView(
                        key: const ValueKey('spotlight'),
                        career: _career,
                        opponent: _opponent,
                        world: _world,
                        focus: _focus,
                        intensity: _intensity,
                        approach: _approach,
                        situation: _situation,
                        showWhy: _showWhy,
                        modifiers: widget.rewardModifiers,
                        onApproachChanged: (value) => setState(() {
                          _approach = value;
                          _showWhy = false;
                        }),
                        onToggleWhy: () => setState(() => _showWhy = !_showWhy),
                        onCommit: _approach == null || _resolvingDecision
                            ? null
                            : _commitDecision,
                      ),
                      _GamePhase.recap => _MatchRecapView(
                        key: const ValueKey('match-recap'),
                        career: _career,
                        result: _lastResult!,
                        world: _world,
                        onContinue: _continueFromRecap,
                      ),
                      _GamePhase.careerEvent => _CareerEventView(
                        key: const ValueKey('career-event'),
                        event: _careerEvent!,
                        onChoose: _resolvingDecision ? null : _chooseEvent,
                      ),
                      _GamePhase.internationalCallup => _NationalCallupView(
                        key: const ValueKey('international-callup'),
                        career: _career,
                        world: _world,
                        requirements: _careerEngine.nationalTeamRequirements(
                          _career,
                          definition: _world,
                        ),
                        onAccept: _resolvingDecision
                            ? null
                            : () => _decideNationalCallup(true),
                        onDecline: _resolvingDecision
                            ? null
                            : () => _decideNationalCallup(false),
                      ),
                      _GamePhase.offseason => _OffseasonView(
                        key: const ValueKey('offseason'),
                        career: _career,
                        world: _world,
                        offers: _careerEngine.contractOffers(
                          _career,
                          definition: _world,
                        ),
                        renewal: _careerEngine.renewalOffer(
                          _career,
                          definition: _world,
                        ),
                        onStay:
                            _career.contract.seasonsRemaining > 1 ||
                                _careerEngine.renewalOffer(
                                      _career,
                                      definition: _world,
                                    ) !=
                                    null
                            ? _completeOffseason
                            : null,
                        onAccept: (offer) =>
                            _completeOffseason(acceptedOffer: offer),
                        onEditTransferRequest: _editTransferRequest,
                        onRetire: canChooseRetirement(_career)
                            ? () => _completeOffseason(retire: true)
                            : null,
                      ),
                      _GamePhase.retired => _LegacyView(
                        key: const ValueKey('retired'),
                        career: _career,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _NationalCallupView extends StatelessWidget {
  const _NationalCallupView({
    super.key,
    required this.career,
    required this.world,
    required this.requirements,
    required this.onAccept,
    required this.onDecline,
  });

  final CareerSnapshot career;
  final WorldDefinition world;
  final NationalCallupRequirements requirements;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final country = world.country(career.player.nationalTeamId);
    return ListView(
      key: const Key('world-nations-callup'),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
      children: [
        const Icon(
          Icons.flag_circle_rounded,
          size: 72,
          color: ElevenwardColors.amber,
        ),
        const SizedBox(height: 16),
        Text(
          'WORLD NATIONS CHAMPIONSHIP',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '${country.name} has qualified, and you have been selected for the national squad.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ElevenwardColors.muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        BroadcastPanel(
          accent: ElevenwardColors.grass,
          child: Column(
            children: [
              _ReviewCallupRow(
                label: 'Your overall',
                value: '${career.player.overall} / ${requirements.overall}',
              ),
              _ReviewCallupRow(
                label: 'Your reputation',
                value:
                    '${career.player.reputation} / ${requirements.reputation}',
              ),
              const _ReviewCallupRow(
                label: 'Format',
                value: '32 teams · 8 groups',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('accept-world-nations-callup'),
          onPressed: onAccept,
          icon: const Icon(Icons.flag_rounded),
          label: const Text('ACCEPT CALL-UP'),
        ),
        const SizedBox(height: 9),
        OutlinedButton(
          key: const Key('decline-world-nations-callup'),
          onPressed: onDecline,
          child: const Text('DECLINE AND SIMULATE'),
        ),
      ],
    );
  }
}

final class _ReviewCallupRow extends StatelessWidget {
  const _ReviewCallupRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.phase, required this.onBack});

  final _GamePhase phase;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 5),
      child: Row(
        children: [
          if (onBack != null) ...[
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                tooltip: uiCopy(contentLocale(context), 'backFocus'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: _PhaseTrack(phase: phase)),
        ],
      ),
    );
  }
}

class _PhaseTrack extends StatelessWidget {
  const _PhaseTrack({required this.phase});

  final _GamePhase phase;

  @override
  Widget build(BuildContext context) {
    final current = switch (phase) {
      _GamePhase.focus => 0,
      _GamePhase.spotlight => 1,
      _ => 2,
    };
    return Row(
      children: List.generate(3, (index) {
        final active = index <= current;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
            decoration: BoxDecoration(
              color: active ? ElevenwardColors.grass : ElevenwardColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

class _MatchRecapView extends StatelessWidget {
  const _MatchRecapView({
    super.key,
    required this.career,
    required this.result,
    required this.world,
    required this.onContinue,
  });

  final CareerSnapshot career;
  final WeeklyResult result;
  final WorldDefinition world;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final playerTeam = _matchTeamName(career, result.opponent, world);
    final home = result.opponent.isHome ? playerTeam : result.opponent.clubName;
    final away = result.opponent.isHome ? result.opponent.clubName : playerTeam;
    final hasBonus =
        result.developmentMultiplier > 1 || result.moneyMultiplier > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _Eyebrow(uiCopy(locale, 'matchRecap')),
        const SizedBox(height: 10),
        BroadcastPanel(
          accent: ElevenwardColors.grass,
          child: Column(
            children: [
              Text(
                result.headline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      home,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      '${result.homeScore}  —  ${result.awayScore}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      away,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _RecapMetric(
                    icon: Icons.star_rounded,
                    label: uiCopy(locale, 'rating'),
                    value: result.deltas.rating.toStringAsFixed(1),
                  ),
                  _RecapMetric(
                    icon: Icons.trending_up_rounded,
                    label: _attributeName(result.trainedAttribute, locale),
                    value: '+${result.developmentGain}',
                  ),
                  _RecapMetric(
                    icon: Icons.payments_outlined,
                    label: uiCopy(locale, 'income'),
                    value:
                        '${result.deltas.money >= 0 ? '+' : '−'}£${result.deltas.money.abs()}',
                  ),
                  _RecapMetric(
                    icon: Icons.favorite_outline_rounded,
                    label: uiCopy(locale, 'trust'),
                    value:
                        '${result.deltas.trust >= 0 ? '+' : ''}${result.deltas.trust}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          key: const Key('recap-continue-button'),
          onPressed: onContinue,
          child: Text(uiCopy(locale, 'continue').toUpperCase()),
        ),
        if (result.developmentRemainder > 0) ...[
          const SizedBox(height: 10),
          Text(
            '${uiCopy(locale, 'fractionalProgress')}: ${result.developmentRemainder.toStringAsFixed(1)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ElevenwardColors.muted),
          ),
        ],
        const SizedBox(height: 14),
        BroadcastPanel(
          accent: ElevenwardColors.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(uiCopy(locale, 'matchStats')),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${result.metrics.possession}% POS')),
                  Chip(label: Text('${result.metrics.shots} SHOTS')),
                  Chip(
                    label: Text('${result.metrics.shotsOnTarget} ON TARGET'),
                  ),
                  Chip(
                    label: Text(
                      '${result.metrics.expectedGoals.toStringAsFixed(1)} xG',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                uiCopy(locale, 'matchReport').toUpperCase(),
                style: const TextStyle(
                  color: ElevenwardColors.sky,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 7),
              Text(result.matchReport, style: const TextStyle(height: 1.48)),
            ],
          ),
        ),
        if (result.agentFee > 0 || result.agentReleased) ...[
          const SizedBox(height: 12),
          BroadcastPanel(
            accent: result.agentReleased
                ? ElevenwardColors.coral
                : ElevenwardColors.amber,
            child: Text(
              result.agentReleased
                  ? uiCopy(locale, 'agentReleased')
                  : '−£${result.agentFee} ${uiCopy(locale, 'monthlyRetainer')}',
            ),
          ),
        ],
        const SizedBox(height: 14),
        _SectionLabel(uiCopy(locale, 'topStories')),
        const SizedBox(height: 8),
        ...result.newsStories.map(
          (story) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BroadcastPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
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
          ),
        ),
        if (hasBonus) ...[
          const SizedBox(height: 14),
          BroadcastPanel(
            accent: ElevenwardColors.amber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(uiCopy(locale, 'appliedPassBonuses')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (result.developmentMultiplier > 1)
                      Chip(
                        avatar: const Icon(Icons.trending_up_rounded, size: 18),
                        label: Text('${result.developmentMultiplier}× DEV'),
                      ),
                    if (result.moneyMultiplier > 1)
                      Chip(
                        avatar: const Icon(Icons.payments_outlined, size: 18),
                        label: Text('${result.moneyMultiplier}× £'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RecapMetric extends StatelessWidget {
  const _RecapMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 116, minHeight: 76),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ElevenwardColors.deep,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ElevenwardColors.line),
    ),
    child: Column(
      children: [
        Icon(icon, size: 18, color: ElevenwardColors.grass),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ElevenwardColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _FocusView extends StatelessWidget {
  const _FocusView({
    super.key,
    required this.career,
    required this.avatarId,
    required this.opponent,
    required this.world,
    required this.focus,
    required this.focusExpanded,
    required this.intensity,
    required this.onFocusToggle,
    required this.onFocusChanged,
    required this.onIntensityChanged,
    required this.onContinue,
  });

  final CareerSnapshot career;
  final String avatarId;
  final OpponentContext opponent;
  final WorldDefinition world;
  final PlayerAttribute focus;
  final bool focusExpanded;
  final TrainingIntensity intensity;
  final VoidCallback onFocusToggle;
  final ValueChanged<PlayerAttribute> onFocusChanged;
  final ValueChanged<TrainingIntensity> onIntensityChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            children: [
              _PlayerCard(career: career, avatarId: avatarId),
              const SizedBox(height: 14),
              _NextMatchCard(career: career, opponent: opponent, world: world),
              const SizedBox(height: 22),
              _Eyebrow(
                context.l10n.chooseEdge.replaceAll('.', '').toUpperCase(),
              ),
              const SizedBox(height: 9),
              _FocusSelector(
                career: career,
                value: focus,
                expanded: focusExpanded,
                onToggle: onFocusToggle,
                onChanged: onFocusChanged,
              ),
              const SizedBox(height: 20),
              if (career.phase == CareerPhase.internationalTournament)
                BroadcastPanel(
                  accent: ElevenwardColors.amber,
                  child: Text(
                    uiCopy(contentLocale(context), 'nationalMatchdayPaused'),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 16,
                  runSpacing: 5,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _SectionLabel(context.l10n.trainingLoad.toUpperCase()),
                    Text(
                      _loadEffect(intensity, contentLocale(context)),
                      style: const TextStyle(
                        color: ElevenwardColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _IntensityControl(
                  value: intensity,
                  onChanged: onIntensityChanged,
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: FilledButton(
              key: const Key('weekly-continue-button'),
              onPressed: onContinue,
              child: Text('${context.l10n.continueLabel.toUpperCase()}  →'),
            ),
          ),
        ),
      ],
    );
  }

  String _loadEffect(TrainingIntensity value, String locale) => switch (value) {
    TrainingIntensity.light => '${uiCopy(locale, 'fitness')} +6',
    TrainingIntensity.balanced =>
      '${uiCopy(locale, 'attribute')} +1  ·  ${uiCopy(locale, 'fitness')} −2',
    TrainingIntensity.intensive =>
      '${uiCopy(locale, 'attribute')} +2  ·  ${uiCopy(locale, 'fitness')} −8',
  };
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.career, required this.avatarId});

  final CareerSnapshot career;
  final String avatarId;

  @override
  Widget build(BuildContext context) {
    final player = career.player;
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ElevenwardColors.grass, ElevenwardColors.sky],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  elevenwardAvatarIcon(avatarId),
                  size: 40,
                  color: ElevenwardColors.ink,
                ),
                Positioned(
                  right: 5,
                  bottom: 4,
                  child: Text(
                    '${player.overall}',
                    style: const TextStyle(
                      color: ElevenwardColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  '${career.clubName}  ·  #19',
                  style: const TextStyle(
                    color: ElevenwardColors.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TinyStat(
                      label: uiCopy(contentLocale(context), 'fitness'),
                      value: '${player.fitness}',
                    ),
                    _TinyStat(
                      label: uiCopy(contentLocale(context), 'form'),
                      value: '${player.form}',
                    ),
                    _TinyStat(
                      label: uiCopy(contentLocale(context), 'trust'),
                      value: '${player.managerTrust}',
                    ),
                    _TinyStat(
                      label: uiCopy(contentLocale(context), 'balance'),
                      value: '£${player.money}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusSelector extends StatelessWidget {
  const _FocusSelector({
    required this.career,
    required this.value,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });

  final CareerSnapshot career;
  final PlayerAttribute value;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<PlayerAttribute> onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final selectedName = _attributeName(value, locale);
    final selectedRating = career.player.attributes[value];
    return Column(
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label: '$selectedName, ${uiCopy(locale, 'rating')} $selectedRating',
          child: InkWell(
            key: const Key('focus-selector-button'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(17),
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: ElevenwardColors.grassDark,
                border: Border.all(color: ElevenwardColors.grass, width: 1.5),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  _FocusIcon(attribute: value, selected: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '$selectedRating',
                    style: const TextStyle(
                      color: ElevenwardColors.grass,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: motionDuration(
                      context,
                      const Duration(milliseconds: 180),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ElevenwardColors.grass,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 220),
            ),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Container(
                    key: const Key('focus-options'),
                    margin: const EdgeInsets.only(top: 7),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: ElevenwardColors.panel,
                      border: Border.all(color: ElevenwardColors.line),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: PlayerAttribute.values
                          .map(
                            (attribute) => _FocusOption(
                              attribute: attribute,
                              name: _attributeName(attribute, locale),
                              rating: career.player.attributes[attribute],
                              selected: attribute == value,
                              onTap: () => onChanged(attribute),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _FocusOption extends StatelessWidget {
  const _FocusOption({
    required this.attribute,
    required this.name,
    required this.rating,
    required this.selected,
    required this.onTap,
  });

  final PlayerAttribute attribute;
  final String name;
  final int rating;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, ${uiCopy(contentLocale(context), 'rating')} $rating',
      child: InkWell(
        key: Key('focus-option-${attribute.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? ElevenwardColors.grass.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              _FocusIcon(attribute: attribute, selected: selected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: selected
                        ? ElevenwardColors.cream
                        : ElevenwardColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$rating',
                style: TextStyle(
                  color: selected
                      ? ElevenwardColors.grass
                      : ElevenwardColors.cream,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 9),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? ElevenwardColors.grass
                    : ElevenwardColors.line,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusIcon extends StatelessWidget {
  const _FocusIcon({required this.attribute, required this.selected});

  final PlayerAttribute attribute;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: selected
            ? ElevenwardColors.grass.withValues(alpha: 0.16)
            : ElevenwardColors.panelLight,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        _attributeIcon(attribute),
        color: selected ? ElevenwardColors.grass : ElevenwardColors.muted,
        size: 20,
      ),
    );
  }
}

class _IntensityControl extends StatelessWidget {
  const _IntensityControl({required this.value, required this.onChanged});

  final TrainingIntensity value;
  final ValueChanged<TrainingIntensity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ElevenwardColors.panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ElevenwardColors.line),
      ),
      child: Row(
        children: TrainingIntensity.values.map((item) {
          final active = item == value;
          return Expanded(
            child: Semantics(
              key: Key('training-intensity-${item.name}'),
              button: true,
              selected: active,
              child: InkWell(
                onTap: () => onChanged(item),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: motionDuration(
                    context,
                    const Duration(milliseconds: 160),
                  ),
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: active ? ElevenwardColors.cream : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _title(item.name),
                    style: TextStyle(
                      color: active
                          ? ElevenwardColors.ink
                          : ElevenwardColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NextMatchCard extends StatelessWidget {
  const _NextMatchCard({
    required this.career,
    required this.opponent,
    required this.world,
  });

  final CareerSnapshot career;
  final OpponentContext opponent;
  final WorldDefinition world;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            color: ElevenwardColors.amber,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(context.l10n.nextMatch.toUpperCase()),
                const SizedBox(height: 4),
                Text(
                  opponent.isHome
                      ? '${_matchTeamName(career, opponent, world)} vs ${opponent.clubName}'
                      : '${opponent.clubName} vs ${_matchTeamName(career, opponent, world)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Text(
            opponent.isHome
                ? context.l10n.home.toUpperCase()
                : context.l10n.away.toUpperCase(),
            style: const TextStyle(
              color: ElevenwardColors.amber,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PregameMatchupOverlay extends StatefulWidget {
  const _PregameMatchupOverlay({
    required this.career,
    required this.opponent,
    required this.world,
  });

  static const delay = Duration(seconds: 2);

  final CareerSnapshot career;
  final OpponentContext opponent;
  final WorldDefinition world;

  @override
  State<_PregameMatchupOverlay> createState() => _PregameMatchupOverlayState();
}

class _PregameMatchupOverlayState extends State<_PregameMatchupOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final Animation<double> _homeEntrance = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.62, curve: Curves.easeOutBack),
  );
  late final Animation<double> _awayEntrance = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.14, 0.78, curve: Curves.easeOutBack),
  );
  late final Animation<double> _versusPulse = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1), weight: 40),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.10,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.10,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 35,
    ),
  ]).animate(_controller);

  Timer? _timer;
  bool _started = false;
  bool _dismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    _timer = Timer(_PregameMatchupOverlay.delay, _dismiss);
  }

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _timer?.cancel();
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final identities = _matchupIdentities(
      widget.career,
      widget.opponent,
      widget.world,
    );
    final home = identities.$1;
    final away = identities.$2;
    return Material(
      key: const Key('matchup-loading-overlay'),
      color: ElevenwardColors.deep,
      child: Semantics(
        button: true,
        label:
            '${uiCopy(locale, 'homeTeam')} ${home.name} ${uiCopy(locale, 'versus')} ${uiCopy(locale, 'awayTeam')} ${away.name}. ${uiCopy(locale, 'tapToContinue')}',
        child: InkWell(
          onTap: _dismiss,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/visual/matchday-tunnel.png',
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
              const ColoredBox(color: Color(0xB307110C)),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 28,
                    ),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 560),
                      padding: const EdgeInsets.fromLTRB(14, 24, 14, 21),
                      decoration: BoxDecoration(
                        color: ElevenwardColors.panel,
                        border: Border.all(color: ElevenwardColors.line),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 28,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Eyebrow(uiCopy(locale, 'upNext')),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _AnimatedMatchupTeam(
                                  animation: _homeEntrance,
                                  identity: home,
                                  role: uiCopy(locale, 'homeTeam'),
                                  keyPrefix: 'home',
                                ),
                              ),
                              const SizedBox(width: 7),
                              ScaleTransition(
                                scale: _versusPulse,
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: ElevenwardColors.panelLight,
                                    border: Border.all(
                                      color: ElevenwardColors.line,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    uiCopy(locale, 'versusShort'),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: _AnimatedMatchupTeam(
                                  animation: _awayEntrance,
                                  identity: away,
                                  role: uiCopy(locale, 'awayTeam'),
                                  keyPrefix: 'away',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 21),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: ElevenwardColors.grass,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Flexible(
                                child: Text(
                                  uiCopy(locale, 'preparingMatchup'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: ElevenwardColors.muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            uiCopy(locale, 'tapToContinue'),
                            style: const TextStyle(
                              color: ElevenwardColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedMatchupTeam extends StatelessWidget {
  const _AnimatedMatchupTeam({
    required this.animation,
    required this.identity,
    required this.role,
    required this.keyPrefix,
  });

  final Animation<double> animation;
  final _MatchupIdentity identity;
  final String role;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.88, end: 1.0).animate(animation),
        child: Column(
          children: [
            Text(
              role,
              style: const TextStyle(
                color: ElevenwardColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 9),
            Container(
              key: Key('matchup-$keyPrefix-badge'),
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [identity.primary, identity.secondary],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ElevenwardColors.cream.withValues(alpha: 0.22),
                  width: 2,
                ),
              ),
              child: Text(
                identity.shortName,
                style: TextStyle(
                  color: _badgeTextColor(identity.primary),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              identity.name,
              key: Key('matchup-$keyPrefix-name'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _MatchupIdentity {
  const _MatchupIdentity({
    required this.name,
    required this.shortName,
    required this.primary,
    required this.secondary,
  });

  final String name;
  final String shortName;
  final Color primary;
  final Color secondary;
}

(_MatchupIdentity, _MatchupIdentity) _matchupIdentities(
  CareerSnapshot career,
  OpponentContext opponent,
  WorldDefinition world,
) {
  final player = _matchupIdentity(
    opponent.competitionKind == CompetitionKind.nationalTournament
        ? career.player.nationalTeamId
        : career.clubId,
    _matchTeamName(career, opponent, world),
    world,
    playerFallback: true,
  );
  final rival = _matchupIdentity(
    opponent.clubId,
    opponent.clubName,
    world,
    playerFallback: false,
  );
  return opponent.isHome ? (player, rival) : (rival, player);
}

_MatchupIdentity _matchupIdentity(
  String id,
  String fallbackName,
  WorldDefinition world, {
  required bool playerFallback,
}) {
  for (final club in world.clubs) {
    if (club.id == id) {
      return _MatchupIdentity(
        name: club.name,
        shortName: club.shortName,
        primary: Color(club.primaryColor),
        secondary: Color(club.secondaryColor),
      );
    }
  }
  for (final team in world.nationalTeams) {
    if (team.id == id) {
      return _MatchupIdentity(
        name: team.countryName,
        shortName: _teamInitials(team.countryName),
        primary: playerFallback
            ? ElevenwardColors.grass
            : ElevenwardColors.amber,
        secondary: playerFallback
            ? ElevenwardColors.sky
            : ElevenwardColors.coral,
      );
    }
  }
  return _MatchupIdentity(
    name: fallbackName,
    shortName: _teamInitials(fallbackName),
    primary: playerFallback ? ElevenwardColors.grass : ElevenwardColors.amber,
    secondary: playerFallback ? ElevenwardColors.sky : ElevenwardColors.coral,
  );
}

String _teamInitials(String name) {
  final words = name
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return 'FC';
  if (words.length == 1) {
    return words.first
        .substring(0, words.first.length.clamp(1, 2))
        .toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

Color _badgeTextColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? ElevenwardColors.cream
    : ElevenwardColors.ink;

class _SpotlightView extends StatelessWidget {
  const _SpotlightView({
    super.key,
    required this.career,
    required this.opponent,
    required this.world,
    required this.focus,
    required this.intensity,
    required this.approach,
    required this.situation,
    required this.showWhy,
    required this.modifiers,
    required this.onApproachChanged,
    required this.onToggleWhy,
    required this.onCommit,
  });

  final CareerSnapshot career;
  final OpponentContext opponent;
  final WorldDefinition world;
  final PlayerAttribute focus;
  final TrainingIntensity intensity;
  final SpotlightApproach? approach;
  final MatchSituationDefinition situation;
  final bool showWhy;
  final RewardModifiers modifiers;
  final ValueChanged<SpotlightApproach> onApproachChanged;
  final VoidCallback onToggleWhy;
  final VoidCallback? onCommit;

  SpotlightPreview _preview(SpotlightApproach choice) =>
      _simulator.previewSpotlight(
        snapshot: career,
        focus: focus,
        intensity: intensity,
        approach: choice,
        opponent: opponent,
        situationOption: situation.options.firstWhere(
          (option) => option.approach == choice,
        ),
        modifiers: modifiers,
      );

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final selection = _simulator.previewSelection(
      snapshot: career,
      opponent: opponent,
      focus: focus,
      intensity: intensity,
      modifiers: modifiers,
    );
    final selectedPreview = approach == null ? null : _preview(approach!);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _MatchHeader(career: career, opponent: opponent, world: world),
        const SizedBox(height: 12),
        _SelectionCard(selection: selection),
        const SizedBox(height: 26),
        _Eyebrow(
          '${situation.minuteFrom + (situation.minuteTo - situation.minuteFrom) ~/ 2}′  ·  ${uiCopy(locale, 'scoreLevel')}',
        ),
        const SizedBox(height: 7),
        Text(
          situation.prompt.forLocale(locale),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _situationContext(locale),
          style: TextStyle(color: ElevenwardColors.muted, height: 1.45),
        ),
        if (career.revision == 0) ...[
          const SizedBox(height: 14),
          const _CoachTip(),
        ],
        const SizedBox(height: 17),
        _ActionCard(
          key: const Key('spotlight-option-safe'),
          title: situation.options[0].title.forLocale(locale),
          subtitle: _approachSubtitle(SpotlightApproach.safe, locale),
          risk: uiCopy(locale, 'lowRisk'),
          icon: Icons.turn_slight_right_rounded,
          preview: _preview(SpotlightApproach.safe),
          selected: approach == SpotlightApproach.safe,
          onTap: () => onApproachChanged(SpotlightApproach.safe),
        ),
        const SizedBox(height: 10),
        _ActionCard(
          key: const Key('spotlight-option-balanced'),
          title: situation.options[1].title.forLocale(locale),
          subtitle: _approachSubtitle(SpotlightApproach.balanced, locale),
          risk: uiCopy(locale, 'balanced'),
          icon: Icons.motion_photos_on_rounded,
          preview: _preview(SpotlightApproach.balanced),
          selected: approach == SpotlightApproach.balanced,
          onTap: () => onApproachChanged(SpotlightApproach.balanced),
        ),
        const SizedBox(height: 10),
        _ActionCard(
          key: const Key('spotlight-option-bold'),
          title: situation.options[2].title.forLocale(locale),
          subtitle: _approachSubtitle(SpotlightApproach.bold, locale),
          risk: uiCopy(locale, 'highRisk'),
          icon: Icons.flash_on_rounded,
          preview: _preview(SpotlightApproach.bold),
          selected: approach == SpotlightApproach.bold,
          onTap: () => onApproachChanged(SpotlightApproach.bold),
        ),
        if (selectedPreview != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onToggleWhy,
            icon: Icon(
              showWhy ? Icons.expand_less_rounded : Icons.info_outline_rounded,
            ),
            label: Text(uiCopy(locale, showWhy ? 'hideNumbers' : 'whyOdds')),
            style: TextButton.styleFrom(
              foregroundColor: ElevenwardColors.grass,
            ),
          ),
          AnimatedCrossFade(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 180),
            ),
            crossFadeState: showWhy
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _WhyPanel(preview: selectedPreview),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('commit-button'),
          onPressed: onCommit,
          child: Text(uiCopy(locale, 'commitDecision')),
        ),
        const SizedBox(height: 8),
        Text(
          uiCopy(locale, 'changeUntilCommit'),
          textAlign: TextAlign.center,
          style: TextStyle(color: ElevenwardColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  String _situationContext(String locale) {
    const values = {
      'en': [
        'Read the pressure, your support, and the space before choosing the risk.',
      ],
      'es': [
        'Lee la presión, los apoyos y el espacio antes de elegir el riesgo.',
      ],
      'pt-BR': [
        'Leia a pressão, os apoios e o espaço antes de escolher o risco.',
      ],
      'fr': [
        'Lisez la pression, les soutiens et l’espace avant de choisir le risque.',
      ],
    };
    return values[locale]!.first;
  }

  String _approachSubtitle(SpotlightApproach approach, String locale) {
    const values = {
      'en': [
        'Protect the team',
        'Trust your technique',
        'Chase the defining play',
      ],
      'es': [
        'Proteger al equipo',
        'Confiar en tu técnica',
        'Buscar la jugada decisiva',
      ],
      'pt-BR': [
        'Proteger o time',
        'Confiar na técnica',
        'Buscar a jogada decisiva',
      ],
      'fr': [
        'Protéger l’équipe',
        'Faire confiance à sa technique',
        'Chercher le geste décisif',
      ],
    };
    return values[locale]![approach.index];
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({
    required this.career,
    required this.opponent,
    required this.world,
  });

  final CareerSnapshot career;
  final OpponentContext opponent;
  final WorldDefinition world;

  @override
  Widget build(BuildContext context) {
    final teamName = _matchTeamName(career, opponent, world);
    final home = opponent.isHome ? teamName : opponent.clubName;
    final away = opponent.isHome ? opponent.clubName : teamName;
    final competitionName =
        opponent.competitionKind == CompetitionKind.nationalTournament
        ? 'World Nations Championship'
        : world.leagues
              .firstWhere(
                (league) =>
                    career.world.leagueParticipants[league.id]?.contains(
                      career.clubId,
                    ) ??
                    false,
              )
              .name;
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      child: Row(
        children: [
          Expanded(
            child: _ClubBadge(name: home, isPlayer: opponent.isHome),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _SectionLabel(competitionName.toUpperCase()),
                const SizedBox(height: 5),
                const Text(
                  'VS',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
                ),
              ],
            ),
          ),
          Expanded(
            child: _ClubBadge(name: away, isPlayer: !opponent.isHome),
          ),
        ],
      ),
    );
  }
}

class _ClubBadge extends StatelessWidget {
  const _ClubBadge({required this.name, required this.isPlayer});

  final String name;
  final bool isPlayer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: isPlayer ? ElevenwardColors.grass : ElevenwardColors.amber,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlayer ? Icons.north_east_rounded : Icons.shield_outlined,
            color: ElevenwardColors.ink,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({required this.selection});

  final SelectionExplanation selection;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final label = switch (selection.status) {
      SelectionStatus.starter => uiCopy(locale, 'starter'),
      SelectionStatus.bench => uiCopy(locale, 'bench'),
      SelectionStatus.omitted => uiCopy(locale, 'omitted'),
    };
    final body = switch (selection.status) {
      SelectionStatus.starter => uiCopy(locale, 'starterBody'),
      SelectionStatus.bench => uiCopy(locale, 'benchBody'),
      SelectionStatus.omitted => uiCopy(locale, 'omittedBody'),
    };
    final color = selection.status == SelectionStatus.omitted
        ? ElevenwardColors.coral
        : ElevenwardColors.grass;
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.assignment_turned_in_outlined, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(color: ElevenwardColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${selection.score.round()}%',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _CoachTip extends StatelessWidget {
  const _CoachTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ElevenwardColors.sky.withValues(alpha: 0.10),
        border: Border.all(color: ElevenwardColors.sky.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.record_voice_over_outlined,
            color: ElevenwardColors.sky,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              uiCopy(contentLocale(context), 'coachTip'),
              style: const TextStyle(
                color: ElevenwardColors.sky,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.risk,
    required this.icon,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String risk;
  final IconData icon;
  final SpotlightPreview preview;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final attributes = preview.primaryAttributes
        .map((item) => _attributeName(item, locale))
        .join(' + ');
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$title. $risk. ${uiCopy(locale, 'projectedSuccess')}: ${preview.chanceLow}–${preview.chanceHigh}%. ${uiCopy(locale, 'usesAttributes')}: $attributes.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: motionDuration(context, const Duration(milliseconds: 180)),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? ElevenwardColors.grassDark
                : ElevenwardColors.panel,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? ElevenwardColors.grass : ElevenwardColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: ElevenwardColors.panelLight,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? ElevenwardColors.grass
                      : ElevenwardColors.cream,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          risk,
                          style: const TextStyle(
                            color: ElevenwardColors.amber,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ElevenwardColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      attributes.toUpperCase(),
                      style: const TextStyle(
                        color: ElevenwardColors.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Text(
                    '${preview.chanceLow}–${preview.chanceHigh}%',
                    style: TextStyle(
                      color: selected
                          ? ElevenwardColors.grass
                          : ElevenwardColors.cream,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    uiCopy(locale, 'success'),
                    style: const TextStyle(
                      color: ElevenwardColors.muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhyPanel extends StatelessWidget {
  const _WhyPanel({required this.preview});

  final SpotlightPreview preview;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: preview.factors
            .map((factor) => _FactorRow(factor: factor))
            .toList(),
      ),
    );
  }
}

class _CareerEventView extends StatelessWidget {
  const _CareerEventView({
    super.key,
    required this.event,
    required this.onChoose,
  });

  final CareerEventDefinition event;
  final ValueChanged<EventChoiceDefinition>? onChoose;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return ListView(
      key: const Key('career-event-prompt'),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 34),
      children: [
        Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: ElevenwardColors.amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: ElevenwardColors.amber.withValues(alpha: 0.45),
              ),
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              color: ElevenwardColors.amber,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _Eyebrow(uiCopy(locale, 'awayPitch')),
        const SizedBox(height: 8),
        Text(
          event.title.forLocale(locale),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 9),
        Text(
          event.body.forLocale(locale),
          style: const TextStyle(
            color: ElevenwardColors.muted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        ...event.choices.map(
          (choice) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: OutlinedButton(
              key: Key('career-event-choice-${choice.id}'),
              onPressed: onChoose == null ? null : () => onChoose!(choice),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: ElevenwardColors.line),
              ),
              child: Text(choice.label.forLocale(locale)),
            ),
          ),
        ),
      ],
    );
  }
}

class _OffseasonView extends StatelessWidget {
  const _OffseasonView({
    super.key,
    required this.career,
    required this.world,
    required this.offers,
    required this.renewal,
    required this.onStay,
    required this.onAccept,
    required this.onEditTransferRequest,
    required this.onRetire,
  });

  final CareerSnapshot career;
  final WorldDefinition world;
  final List<ContractOffer> offers;
  final ContractOffer? renewal;
  final VoidCallback? onStay;
  final ValueChanged<ContractOffer> onAccept;
  final VoidCallback onEditTransferRequest;
  final VoidCallback? onRetire;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final market = const CareerEngine().transferMarketReport(
      career,
      definition: world,
    );
    final rejected = market.where((entry) => !entry.accepted).take(3);
    final marketState = const WorldSimulator().beginNextSeason(
      career.world,
      career.seed,
      definition: world,
    );
    final request = career.transferRequest;
    final targetIds = request == null
        ? const <String>{}
        : marketState.leagueParticipants[request.targetLeagueId]?.toSet() ??
              const <String>{};
    final hasTargetOffer = offers.any(
      (offer) => targetIds.contains(offer.clubId),
    );
    final targetFeedback = _strongestTargetRejection(
      locale: locale,
      targetIds: targetIds,
      market: market,
      world: world,
    );
    final targetLeague = request == null
        ? null
        : world.leagues
              .where((league) => league.id == request.targetLeagueId)
              .firstOrNull;
    final preferredClub = request?.preferredClubId == null
        ? null
        : world.clubs
              .where((club) => club.id == request!.preferredClubId)
              .firstOrNull;
    final leagueId = career.world.leagueIdForClub(career.clubId);
    final table = career.world.table(leagueId);
    final placement =
        table.indexWhere((row) => row.clubId == career.clubId) + 1;
    final nationalHistory = career.world.nationalTournamentHistory
        .where((entry) => entry.season == career.season)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
      children: [
        const Icon(
          Icons.flag_circle_rounded,
          color: ElevenwardColors.grass,
          size: 54,
        ),
        const SizedBox(height: 14),
        Text(
          context.l10n.seasonComplete,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '${career.clubName} · #$placement · ${career.points} ${uiCopy(locale, 'points')}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        _Panel(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _RoundStat(
                value: '${career.seasonPerformance.appearances}',
                label: uiCopy(contentLocale(context), 'apps'),
              ),
              _RoundStat(
                value: '${career.seasonPerformance.goals}',
                label: uiCopy(contentLocale(context), 'goals'),
              ),
              _RoundStat(
                value: '${career.seasonPerformance.assists}',
                label: uiCopy(contentLocale(context), 'assists'),
              ),
              _RoundStat(
                value: career.seasonPerformance.averageRating.toStringAsFixed(
                  1,
                ),
                label: uiCopy(contentLocale(context), 'rating'),
              ),
            ],
          ),
        ),
        if (nationalHistory != null) ...[
          const SizedBox(height: 14),
          BroadcastPanel(
            accent: ElevenwardColors.amber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('WORLD NATIONS CHAMPIONSHIP'),
                const SizedBox(height: 8),
                Text(
                  '${world.nationalTeam(nationalHistory.winnerId).countryName} won the championship.',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_nationalFinishLabel(nationalHistory.playerFinish)} · ${nationalHistory.playerAppearances} appearances',
                  style: const TextStyle(color: ElevenwardColors.muted),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (request != null) ...[
          BroadcastPanel(
            accent: ElevenwardColors.amber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.outbound_outlined,
                      color: ElevenwardColors.amber,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        uiCopy(locale, 'transferRequestActive'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${uiCopy(locale, 'targetLeague')}: ${targetLeague == null ? request.targetLeagueId : leagueDisplayName(targetLeague)}',
                ),
                Text(
                  '${uiCopy(locale, 'preferredClub')}: ${request.preferredClubId == null ? uiCopy(locale, 'anyEligibleClub') : preferredClub?.name ?? request.preferredClubId}',
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('offseason-edit-transfer-request'),
                  onPressed: onEditTransferRequest,
                  child: Text(uiCopy(locale, 'editTransferRequest')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        _Eyebrow(context.l10n.contractOffers.toUpperCase()),
        const SizedBox(height: 9),
        if (career.contract.seasonsRemaining <= 1) ...[
          _Panel(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  renewal == null
                      ? uiCopy(locale, 'contractExpired')
                      : uiCopy(locale, 'renewalOffered'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  renewal == null
                      ? uiCopy(locale, 'freeAgencyRequired')
                      : '£${renewal!.weeklyWage}/${uiCopy(locale, 'week').toLowerCase()} · '
                            '${renewal!.seasons} ${uiCopy(locale, 'season').toLowerCase()} · '
                            '${localizedPromisedRole(locale, renewal!.promisedRole)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        ...offers.map((offer) {
          final club = world.clubs.firstWhere(
            (item) => item.id == offer.clubId,
          );
          final destinationLeagueId = marketState.leagueIdForClub(club.id);
          final destinationLeague = world.leagues.firstWhere(
            (league) => league.id == destinationLeagueId,
          );
          final isTarget = targetIds.contains(club.id);
          final isPreferred = request?.preferredClubId == club.id && isTarget;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Panel(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: ElevenwardColors.amber,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          club.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '${offer.tacticalFit}% ${uiCopy(locale, 'fit')}',
                        style: const TextStyle(
                          color: ElevenwardColors.grass,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${world.country(destinationLeague.countryId).nameFor(locale)} · ${leagueDisplayName(destinationLeague)}',
                    style: const TextStyle(
                      color: ElevenwardColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (isTarget || isPreferred) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isTarget)
                          Chip(
                            avatar: const Icon(Icons.flag_outlined, size: 15),
                            label: Text(uiCopy(locale, 'targetLeagueOffer')),
                          ),
                        if (isPreferred)
                          Chip(
                            avatar: const Icon(Icons.star_outline, size: 15),
                            label: Text(uiCopy(locale, 'preferredClubOffer')),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(localizedTransferReason(locale, offer.interestReason)),
                  const SizedBox(height: 8),
                  Text(
                    '£${offer.weeklyWage}/${uiCopy(locale, 'week').toLowerCase()} · '
                    '${offer.seasons} ${uiCopy(locale, 'season').toLowerCase()} · '
                    '${localizedPromisedRole(locale, offer.promisedRole)}',
                    style: const TextStyle(
                      color: ElevenwardColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onAccept(offer),
                          child: Text(context.l10n.acceptOffer.toUpperCase()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              _negotiate(context, career, offer, onAccept),
                          child: Text(uiCopy(locale, 'negotiate')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (offers.isEmpty) ...[
          Text(uiCopy(locale, 'noOffers')),
          const SizedBox(height: 12),
        ],
        if (request != null && !hasTargetOffer) ...[
          BroadcastPanel(
            accent: ElevenwardColors.coral,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uiCopy(locale, 'noTargetOffer'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (targetFeedback != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    '${uiCopy(locale, 'strongestTargetResponse')}: ${targetFeedback.text}',
                  ),
                ],
                if (request.preferredClubId != null &&
                    request.preferredClubId != targetFeedback?.clubId) ...[
                  const SizedBox(height: 7),
                  Text(
                    _preferredTransferFeedback(
                      locale: locale,
                      request: request,
                      targetIds: targetIds,
                      market: market,
                      world: world,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (rejected.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Eyebrow(uiCopy(locale, 'transferFeedback').toUpperCase()),
          const SizedBox(height: 9),
          ...rejected.map((entry) {
            final club = world.clubs.firstWhere(
              (item) => item.id == entry.clubId,
            );
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(club.name),
              subtitle: Text(localizedTransferReason(locale, entry.reason)),
              trailing: Text(
                '${entry.interest}%\n${uiCopy(locale, 'interest')}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 10),
              ),
            );
          }),
        ],
        const SizedBox(height: 5),
        FilledButton(
          onPressed: onStay,
          child: Text(
            (renewal != null
                    ? uiCopy(locale, 'acceptRenewal')
                    : context.l10n.stayAtClub)
                .toUpperCase(),
          ),
        ),
        if (onRetire != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetire,
            icon: const Icon(Icons.history_rounded),
            label: Text(context.l10n.retireNow),
          ),
        ],
      ],
    );
  }

  Future<void> _negotiate(
    BuildContext context,
    CareerSnapshot career,
    ContractOffer offer,
    ValueChanged<ContractOffer> onAccept,
  ) async {
    final locale = contentLocale(context);
    final priority = await showModalBottomSheet<NegotiationPriority>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: NegotiationPriority.values
              .map(
                (value) => ListTile(
                  leading: Icon(switch (value) {
                    NegotiationPriority.wage => Icons.payments_outlined,
                    NegotiationPriority.role => Icons.groups_outlined,
                    NegotiationPriority.term => Icons.calendar_month_outlined,
                  }),
                  title: Text(uiCopy(locale, 'negotiate${value.name}')),
                  onTap: () => Navigator.pop(context, value),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (priority == null || !context.mounted) return;
    final negotiated = const CareerEngine().negotiateOffer(
      snapshot: career,
      offer: offer,
      priority: priority,
    );
    final accepted =
        negotiated.weeklyWage != offer.weeklyWage ||
        negotiated.seasons != offer.seasons ||
        negotiated.promisedRole != offer.promisedRole;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          uiCopy(
            locale,
            accepted ? 'negotiationAccepted' : 'negotiationDeclined',
          ),
        ),
        content: Text(
          localizedTransferReason(locale, negotiated.interestReason),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.acceptOffer),
          ),
        ],
      ),
    );
    if (confirm == true) onAccept(negotiated);
  }
}

String _preferredTransferFeedback({
  required String locale,
  required TransferRequest request,
  required Set<String> targetIds,
  required List<TransferInterest> market,
  required WorldDefinition world,
}) {
  final clubId = request.preferredClubId!;
  final clubName =
      world.clubs
          .where((club) => club.id == clubId)
          .map((club) => club.name)
          .firstOrNull ??
      clubId;
  if (!targetIds.contains(clubId)) {
    return '$clubName — ${uiCopy(locale, 'preferredClubMovedLeague')}';
  }
  final interest = market.where((entry) => entry.clubId == clubId).firstOrNull;
  if (interest == null) return clubName;
  return '$clubName — ${localizedTransferReason(locale, interest.reason)}';
}

({String clubId, String text})? _strongestTargetRejection({
  required String locale,
  required Set<String> targetIds,
  required List<TransferInterest> market,
  required WorldDefinition world,
}) {
  final rejection = market
      .where((entry) => targetIds.contains(entry.clubId) && !entry.accepted)
      .firstOrNull;
  if (rejection == null) return null;
  final clubName = world.clubs
      .where((club) => club.id == rejection.clubId)
      .map((club) => club.name)
      .firstOrNull;
  return (
    clubId: rejection.clubId,
    text:
        '${clubName ?? rejection.clubId} — ${localizedTransferReason(locale, rejection.reason)}',
  );
}

String _nationalFinishLabel(String finish) => switch (finish) {
  'champion' => 'Champions',
  'runnerUp' => 'Runners-up',
  'semifinal' => 'Semifinal',
  'quarterfinal' => 'Quarterfinal',
  'roundOf16' => 'Round of 16',
  'groupStage' => 'Group stage',
  'missedSquad' => 'Qualified · squad threshold not met',
  'declinedCallup' => 'Qualified · call-up declined',
  'didNotQualify' => 'Did not qualify',
  _ => finish,
};

class _LegacyView extends StatelessWidget {
  const _LegacyView({super.key, required this.career});

  final CareerSnapshot career;

  @override
  Widget build(BuildContext context) {
    final verdict = calculateLegacyVerdict(career);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
      children: [
        const Icon(
          Icons.workspace_premium_rounded,
          color: ElevenwardColors.amber,
          size: 70,
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.careerComplete,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          localizedLegacyHeadline(contentLocale(context), verdict.tier),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ElevenwardColors.grass,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 24),
        _Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _SectionLabel(uiCopy(contentLocale(context), 'legacyScore')),
              const SizedBox(height: 6),
              Text(
                '${verdict.score}',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 6),
              Text(
                localizedLegacyTier(contentLocale(context), verdict.tier),
                style: const TextStyle(
                  color: ElevenwardColors.amber,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Divider(height: 28),
              ...[
                '${career.player.appearances} ${uiCopy(contentLocale(context), 'appearances')}',
                '${career.player.goals} ${uiCopy(contentLocale(context), 'goals')} · ${career.player.assists} ${uiCopy(contentLocale(context), 'assists')}',
                '${career.seasonHistory.fold<int>(0, (sum, season) => sum + season.trophies.length)} ${uiCopy(contentLocale(context), 'trophies')}',
                '${career.player.reputation}/100 ${uiCopy(contentLocale(context), 'reputationLong')}',
              ].map(
                (reason) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: ElevenwardColors.grass,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(reason)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${career.seasonHistory.length} ${uiCopy(contentLocale(context), 'seasons')} · ${career.player.appearances} ${uiCopy(contentLocale(context), 'appearances')} · ${career.player.goals} ${uiCopy(contentLocale(context), 'goals')} · ${career.player.assists} ${uiCopy(contentLocale(context), 'assists')}',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});

  final OutcomeFactor factor;

  @override
  Widget build(BuildContext context) {
    final positive = factor.impact >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            positive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: positive ? ElevenwardColors.grass : ElevenwardColors.coral,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedFactor(contentLocale(context), factor.label),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  factor.detail,
                  style: const TextStyle(
                    color: ElevenwardColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 37,
            child: Text(
              '${positive ? '+' : ''}${factor.impact.toStringAsFixed(1)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: positive
                    ? ElevenwardColors.grass
                    : ElevenwardColors.coral,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundStat extends StatelessWidget {
  const _RoundStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: ElevenwardColors.panelLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(
              color: ElevenwardColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ElevenwardColors.panel.withValues(alpha: 0.94),
        border: Border.all(color: ElevenwardColors.line),
        borderRadius: BorderRadius.circular(19),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ElevenwardColors.panelLight,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text.rich(
        TextSpan(
          text: '$label  ',
          style: const TextStyle(
            color: ElevenwardColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(color: ElevenwardColors.cream),
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: ElevenwardColors.grass,
        fontWeight: FontWeight.w900,
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: ElevenwardColors.muted,
        fontWeight: FontWeight.w900,
        fontSize: 10,
        letterSpacing: 0.9,
      ),
    );
  }
}

class _PitchBackground extends StatelessWidget {
  const _PitchBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PitchPainter(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.7, -0.8),
            radius: 1.2,
            colors: [Color(0xFF173421), ElevenwardColors.ink],
          ),
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ElevenwardColors.grass.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.20),
      105,
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.62,
        0,
        size.width * 0.46,
        size.height * 0.34,
      ),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.72),
      Offset(size.width, size.height * 0.72),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _title(String value) => '${value[0].toUpperCase()}${value.substring(1)}';

IconData _attributeIcon(PlayerAttribute attribute) => switch (attribute) {
  PlayerAttribute.pace => Icons.speed_rounded,
  PlayerAttribute.technique => Icons.blur_circular_rounded,
  PlayerAttribute.passing => Icons.call_split_rounded,
  PlayerAttribute.finishing => Icons.gps_fixed_rounded,
  PlayerAttribute.defending => Icons.security_rounded,
  PlayerAttribute.strength => Icons.fitness_center_rounded,
  PlayerAttribute.stamina => Icons.bolt_rounded,
  PlayerAttribute.composure => Icons.psychology_alt_outlined,
};

String _attributeName(PlayerAttribute attribute, String locale) {
  const names = <String, List<String>>{
    'en': [
      'Pace',
      'Technique',
      'Passing',
      'Finishing',
      'Defending',
      'Strength',
      'Stamina',
      'Composure',
    ],
    'es': [
      'Ritmo',
      'Técnica',
      'Pase',
      'Definición',
      'Defensa',
      'Fuerza',
      'Resistencia',
      'Compostura',
    ],
    'pt-BR': [
      'Velocidade',
      'Técnica',
      'Passe',
      'Finalização',
      'Defesa',
      'Força',
      'Resistência',
      'Compostura',
    ],
    'fr': [
      'Vitesse',
      'Technique',
      'Passe',
      'Finition',
      'Défense',
      'Force',
      'Endurance',
      'Sang-froid',
    ],
  };
  return names[locale]![attribute.index];
}
