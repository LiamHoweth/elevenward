import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n_context.dart';
import 'storage/career_store.dart';
import 'theme.dart';
import 'ui_copy.dart';
import 'util/uuid.dart';

enum _GamePhase { focus, spotlight, receipt, offseason, retired }

const _simulator = WeeklySimulator();
const _worldSimulator = WorldSimulator();
const _careerEngine = CareerEngine();
final _contentCatalog = buildLaunchContent();

String _matchTeamName(CareerSnapshot career, OpponentContext opponent) =>
    opponent.competitionKind == CompetitionKind.nationalTournament
    ? buildLaunchWorld().nationalTeams
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
    this.onCareerChanged,
    this.contentCatalog,
    this.avatarId = 'initials',
  });

  final CareerStore? careerStore;
  final int slotIndex;
  final CareerSnapshot? initialCareer;
  final Future<void> Function(CareerSnapshot snapshot, String eventType)?
  onCareerChanged;
  final ContentCatalog? contentCatalog;
  final String avatarId;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late CareerSnapshot _career;
  bool _loading = false;
  _GamePhase _phase = _GamePhase.focus;
  PlayerAttribute _focus = PlayerAttribute.finishing;
  TrainingIntensity _intensity = TrainingIntensity.balanced;
  SpotlightApproach? _approach;
  WeeklyResult? _result;
  CareerSnapshot? _resolvedCareer;
  CareerEventDefinition? _careerEvent;
  EventChoiceDefinition? _selectedEventChoice;
  bool _showWhy = false;

  @override
  void initState() {
    super.initState();
    _career = widget.initialCareer ?? _newCareer();
    _phase = switch (_career.phase) {
      CareerPhase.offseason => _GamePhase.offseason,
      CareerPhase.retired => _GamePhase.retired,
      _ => _GamePhase.focus,
    };
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
        _phase = switch (incoming.phase) {
          CareerPhase.offseason => _GamePhase.offseason,
          CareerPhase.retired => _GamePhase.retired,
          _ => _GamePhase.focus,
        };
        _approach = null;
        _result = null;
        _resolvedCareer = null;
        _careerEvent = null;
        _selectedEventChoice = null;
      });
    }
  }

  ContentCatalog get _catalog => widget.contentCatalog ?? _contentCatalog;

  CareerSnapshot _newCareer() {
    final careerId = generateUuidV4();
    return CareerSnapshot.newCareer(
      careerId: careerId,
      seed: uuidSeed(careerId),
      updatedAt: DateTime.now().toUtc(),
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
        _phase = switch (stored.phase) {
          CareerPhase.offseason => _GamePhase.offseason,
          CareerPhase.retired => _GamePhase.retired,
          _ => _GamePhase.focus,
        };
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  OpponentContext get _opponent {
    try {
      return _worldSimulator.opponentFor(_career);
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

  void _openSpotlight() {
    setState(() {
      _phase = _GamePhase.spotlight;
      _approach = null;
      _showWhy = false;
    });
  }

  Future<void> _commitDecision() async {
    final approach = _approach;
    if (approach == null) return;
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
    );
    setState(() {
      _result = result;
      final eligibleEvents = _careerEngine.eligibleEvents(
        result.snapshot,
        _catalog,
      );
      _careerEvent = eligibleEvents.isEmpty
          ? null
          : eligibleEvents[(result.snapshot.seed ^ result.snapshot.revision)
                    .abs() %
                eligibleEvents.length];
      _resolvedCareer = null;
      _selectedEventChoice = null;
      _phase = _GamePhase.receipt;
    });
    if (result.spotlightSucceeded) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.selectionClick();
    }
    await _persist(result.snapshot, 'week_completed');
  }

  void _nextWeek() {
    final next = _resolvedCareer ?? _result!.snapshot;
    setState(() {
      _career = next;
      _phase = next.phase == CareerPhase.offseason
          ? _GamePhase.offseason
          : _GamePhase.focus;
      _approach = null;
      _result = null;
      _careerEvent = null;
      _resolvedCareer = null;
      _selectedEventChoice = null;
      _showWhy = false;
    });
  }

  Future<void> _chooseEvent(EventChoiceDefinition choice) async {
    final event = _careerEvent;
    final result = _result;
    if (event == null || result == null || _resolvedCareer != null) return;
    final resolved = _careerEngine.applyEventChoice(
      snapshot: result.snapshot,
      event: event,
      choice: choice,
      updatedAt: DateTime.now().toUtc(),
    );
    setState(() {
      _resolvedCareer = resolved;
      _selectedEventChoice = choice;
    });
    await HapticFeedback.selectionClick();
    await _persist(resolved, 'career_event_resolved');
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
    );
    setState(() {
      _career = next;
      _phase = next.retired ? _GamePhase.retired : _GamePhase.focus;
    });
    await _persist(
      next,
      next.retired ? 'career_retired' : 'offseason_completed',
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
                  season: _career.season,
                  week: _career.week,
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
                        focus: _focus,
                        intensity: _intensity,
                        onFocusChanged: (value) =>
                            setState(() => _focus = value),
                        onIntensityChanged: (value) =>
                            setState(() => _intensity = value),
                        onContinue: _openSpotlight,
                      ),
                      _GamePhase.spotlight => _SpotlightView(
                        key: const ValueKey('spotlight'),
                        career: _career,
                        opponent: _opponent,
                        focus: _focus,
                        intensity: _intensity,
                        approach: _approach,
                        situation: _situation,
                        showWhy: _showWhy,
                        onApproachChanged: (value) => setState(() {
                          _approach = value;
                          _showWhy = false;
                        }),
                        onToggleWhy: () => setState(() => _showWhy = !_showWhy),
                        onCommit: _approach == null ? null : _commitDecision,
                      ),
                      _GamePhase.receipt => _ReceiptView(
                        key: const ValueKey('receipt'),
                        careerBefore: _career,
                        result: _result!,
                        event: _careerEvent,
                        selectedChoice: _selectedEventChoice,
                        onChooseEvent: _chooseEvent,
                        onContinue: _nextWeek,
                      ),
                      _GamePhase.offseason => _OffseasonView(
                        key: const ValueKey('offseason'),
                        career: _career,
                        offers: _careerEngine.contractOffers(_career),
                        renewal: _careerEngine.renewalOffer(_career),
                        onStay:
                            _career.contract.seasonsRemaining > 1 ||
                                _careerEngine.renewalOffer(_career) != null
                            ? _completeOffseason
                            : null,
                        onAccept: (offer) =>
                            _completeOffseason(acceptedOffer: offer),
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.phase,
    required this.season,
    required this.week,
    required this.onBack,
  });

  final _GamePhase phase;
  final int season;
  final int week;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Column(
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: uiCopy(contentLocale(context), 'backFocus'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              else
                const _Mark(),
              if (onBack != null) const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'ELEVENWARD',
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: ElevenwardColors.cream,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${context.l10n.seasonWeek(season, week).toUpperCase()}/18',
                    style: const TextStyle(
                      color: ElevenwardColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PhaseTrack(phase: phase),
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: ElevenwardColors.grass,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.north_east_rounded,
        color: ElevenwardColors.ink,
        size: 20,
      ),
    );
  }
}

class _PhaseTrack extends StatelessWidget {
  const _PhaseTrack({required this.phase});

  final _GamePhase phase;

  @override
  Widget build(BuildContext context) {
    final current = phase.index;
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

class _FocusView extends StatelessWidget {
  const _FocusView({
    super.key,
    required this.career,
    required this.avatarId,
    required this.opponent,
    required this.focus,
    required this.intensity,
    required this.onFocusChanged,
    required this.onIntensityChanged,
    required this.onContinue,
  });

  final CareerSnapshot career;
  final String avatarId;
  final OpponentContext opponent;
  final PlayerAttribute focus;
  final TrainingIntensity intensity;
  final ValueChanged<PlayerAttribute> onFocusChanged;
  final ValueChanged<TrainingIntensity> onIntensityChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _PlayerCard(career: career, avatarId: avatarId),
        const SizedBox(height: 28),
        _Eyebrow(uiCopy(contentLocale(context), 'workBeforeNoise')),
        const SizedBox(height: 7),
        Text(
          context.l10n.chooseEdge,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.weeklyFocusBody,
          style: TextStyle(color: ElevenwardColors.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        ...PlayerAttribute.values.expand(
          (attribute) => [
            _TrainingChoice(
              icon: _attributeIcon(attribute),
              title: _attributeName(attribute, contentLocale(context)),
              subtitle: _attributeDescription(
                attribute,
                career.player.position,
                contentLocale(context),
              ),
              value: career.player.attributes[attribute],
              selected: focus == attribute,
              onTap: () => onFocusChanged(attribute),
            ),
            if (attribute != PlayerAttribute.values.last)
              const SizedBox(height: 10),
          ],
        ),
        const SizedBox(height: 22),
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
        _IntensityControl(value: intensity, onChanged: onIntensityChanged),
        const SizedBox(height: 22),
        _NextMatchCard(career: career, opponent: opponent),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('set-focus-button'),
          onPressed: onContinue,
          child: Text('${context.l10n.setFocus.toUpperCase()}  →'),
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

class _TrainingChoice extends StatelessWidget {
  const _TrainingChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, rating $value. $subtitle',
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
            border: Border.all(
              color: selected ? ElevenwardColors.grass : ElevenwardColors.line,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: selected
                      ? ElevenwardColors.grass.withValues(alpha: 0.16)
                      : ElevenwardColors.panelLight,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? ElevenwardColors.grass
                      : ElevenwardColors.muted,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ElevenwardColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  color: selected
                      ? ElevenwardColors.grass
                      : ElevenwardColors.cream,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? ElevenwardColors.grass
                    : ElevenwardColors.line,
                size: 21,
              ),
            ],
          ),
        ),
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
  const _NextMatchCard({required this.career, required this.opponent});

  final CareerSnapshot career;
  final OpponentContext opponent;

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
                      ? '${_matchTeamName(career, opponent)} vs ${opponent.clubName}'
                      : '${opponent.clubName} vs ${_matchTeamName(career, opponent)}',
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

class _SpotlightView extends StatelessWidget {
  const _SpotlightView({
    super.key,
    required this.career,
    required this.opponent,
    required this.focus,
    required this.intensity,
    required this.approach,
    required this.situation,
    required this.showWhy,
    required this.onApproachChanged,
    required this.onToggleWhy,
    required this.onCommit,
  });

  final CareerSnapshot career;
  final OpponentContext opponent;
  final PlayerAttribute focus;
  final TrainingIntensity intensity;
  final SpotlightApproach? approach;
  final MatchSituationDefinition situation;
  final bool showWhy;
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
      );

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final selection = _simulator.previewSelection(
      snapshot: career,
      opponent: opponent,
      focus: focus,
      intensity: intensity,
    );
    final selectedPreview = approach == null ? null : _preview(approach!);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        _MatchHeader(career: career, opponent: opponent),
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
  const _MatchHeader({required this.career, required this.opponent});

  final CareerSnapshot career;
  final OpponentContext opponent;

  @override
  Widget build(BuildContext context) {
    final teamName = _matchTeamName(career, opponent);
    final home = opponent.isHome ? teamName : opponent.clubName;
    final away = opponent.isHome ? opponent.clubName : teamName;
    final world = buildLaunchWorld();
    final leagueName = world.leagues
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
                _SectionLabel(leagueName.toUpperCase()),
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
          '$title. $risk. Projected success ${preview.chanceLow} to ${preview.chanceHigh} percent. Uses $attributes.',
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

class _ReceiptView extends StatelessWidget {
  const _ReceiptView({
    super.key,
    required this.careerBefore,
    required this.result,
    required this.event,
    required this.selectedChoice,
    required this.onChooseEvent,
    required this.onContinue,
  });

  final CareerSnapshot careerBefore;
  final WeeklyResult result;
  final CareerEventDefinition? event;
  final EventChoiceDefinition? selectedChoice;
  final ValueChanged<EventChoiceDefinition> onChooseEvent;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final event = this.event;
    final teamName =
        result.opponent.competitionKind == CompetitionKind.nationalTournament
        ? buildLaunchWorld().nationalTeams
              .firstWhere(
                (team) => team.id == careerBefore.player.nationalTeamId,
              )
              .countryName
        : careerBefore.clubName;
    final home = result.opponent.isHome ? teamName : result.opponent.clubName;
    final away = result.opponent.isHome ? result.opponent.clubName : teamName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: result.spotlightSucceeded
                  ? ElevenwardColors.grass.withValues(alpha: 0.14)
                  : ElevenwardColors.coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              uiCopy(
                locale,
                result.spotlightSucceeded ? 'momentWon' : 'momentMissed',
              ),
              style: TextStyle(
                color: result.spotlightSucceeded
                    ? ElevenwardColors.grass
                    : ElevenwardColors.coral,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.9,
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                home,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${result.homeScore} — ${result.awayScore}',
                style: Theme.of(context).textTheme.displayLarge,
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
        const SizedBox(height: 9),
        if (result.fixtureDecision != FixtureDecision.regulation) ...[
          Text(
            uiCopy(
              locale,
              result.fixtureDecision == FixtureDecision.extraTime
                  ? 'afterExtraTime'
                  : 'afterPenalties',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ElevenwardColors.amber,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Text(
          _localizedMatchHeadline(
            locale,
            careerBefore.player.name,
            result.spotlightSucceeded,
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: ElevenwardColors.muted),
        ),
        const SizedBox(height: 23),
        _Panel(
          padding: const EdgeInsets.all(17),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(uiCopy(locale, 'matchRating')),
                        const SizedBox(height: 5),
                        Text(
                          '${result.deltas.rating}',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ],
                    ),
                  ),
                  _RoundStat(
                    value: '${result.deltas.goals}',
                    label: uiCopy(locale, 'goals'),
                  ),
                  const SizedBox(width: 10),
                  _RoundStat(
                    value: '${result.deltas.assists}',
                    label: uiCopy(locale, 'assists'),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              const Divider(height: 1),
              const SizedBox(height: 15),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _DeltaChip(
                    label: uiCopy(locale, 'trust'),
                    value: result.deltas.trust,
                  ),
                  _DeltaChip(
                    label: uiCopy(locale, 'form'),
                    value: result.deltas.form,
                  ),
                  _DeltaChip(
                    label: uiCopy(locale, 'fitness'),
                    value: result.deltas.fitness,
                  ),
                  _DeltaChip(
                    label: uiCopy(locale, 'reputation'),
                    value: result.deltas.reputation,
                  ),
                  _DeltaChip(
                    label: uiCopy(locale, 'pay'),
                    value: result.deltas.money,
                    money: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (result.sponsorPayout > 0 || result.endedSponsorIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.handshake_outlined,
                  color: ElevenwardColors.amber,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${uiCopy(locale, 'sponsorEarnings')}: £${result.sponsorPayout}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (result.endedSponsorIds.isNotEmpty)
                        Text(
                          uiCopy(locale, 'sponsorEnded'),
                          style: const TextStyle(
                            color: ElevenwardColors.muted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 21),
        _Eyebrow(uiCopy(locale, 'whyHappened')),
        const SizedBox(height: 9),
        _Panel(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              ...result.factors
                  .take(4)
                  .map((factor) => _FactorRow(factor: factor)),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.casino_outlined,
                    color: ElevenwardColors.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      uiCopy(locale, 'seededRoll'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${result.roll}  /  < ${result.preview.chance}',
                    style: const TextStyle(
                      color: ElevenwardColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (event != null) ...[
          _Eyebrow(uiCopy(locale, 'awayPitch')),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ElevenwardColors.amber.withValues(alpha: 0.10),
              border: Border.all(
                color: ElevenwardColors.amber.withValues(alpha: 0.40),
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.people_alt_outlined,
                  color: ElevenwardColors.amber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title.forLocale(locale),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        event.body.forLocale(locale),
                        style: const TextStyle(
                          color: ElevenwardColors.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...event.choices.map(
            (choice) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                button: true,
                selected: selectedChoice?.id == choice.id,
                child: OutlinedButton(
                  onPressed: selectedChoice == null
                      ? () => onChooseEvent(choice)
                      : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(
                      color: selectedChoice?.id == choice.id
                          ? ElevenwardColors.grass
                          : ElevenwardColors.line,
                    ),
                  ),
                  child: Text(choice.label.forLocale(locale)),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('next-week-button'),
          onPressed: event != null && selectedChoice == null
              ? null
              : onContinue,
          child: Text(
            result.snapshot.phase == CareerPhase.offseason
                ? '${uiCopy(locale, 'continueOffseason')}  →'
                : '${context.l10n.continueLabel.toUpperCase()} · ${context.l10n.seasonWeek(result.snapshot.season, result.snapshot.week).toUpperCase()}  →',
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
    required this.offers,
    required this.renewal,
    required this.onStay,
    required this.onAccept,
    required this.onRetire,
  });

  final CareerSnapshot career;
  final List<ContractOffer> offers;
  final ContractOffer? renewal;
  final VoidCallback? onStay;
  final ValueChanged<ContractOffer> onAccept;
  final VoidCallback? onRetire;

  @override
  Widget build(BuildContext context) {
    final world = buildLaunchWorld();
    final locale = contentLocale(context);
    final market = const CareerEngine().transferMarketReport(career);
    final rejected = market.where((entry) => !entry.accepted).take(3);
    final leagueId = career.world.leagueIdForClub(career.clubId);
    final table = career.world.table(leagueId);
    final placement =
        table.indexWhere((row) => row.clubId == career.clubId) + 1;
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
        const SizedBox(height: 24),
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

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.label,
    required this.value,
    this.money = false,
  });

  final String label;
  final int value;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ElevenwardColors.panelLight,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$label  ${positive ? '+' : ''}${money ? '£' : ''}$value',
        style: TextStyle(
          color: positive ? ElevenwardColors.cream : ElevenwardColors.coral,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
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

String _attributeDescription(
  PlayerAttribute attribute,
  PositionFamily position,
  String locale,
) {
  const descriptions = <String, List<String>>{
    'en': [
      'Acceleration and recovery runs',
      'Control when space disappears',
      'Weight and vision of distribution',
      'Quality in decisive scoring actions',
      'Reading, positioning, and challenges',
      'Power through physical contact',
      'Repeat intensity late in matches',
      'Clear decisions under pressure',
    ],
    'es': [
      'Aceleración y carreras de recuperación',
      'Control cuando desaparece el espacio',
      'Precisión y visión en la distribución',
      'Calidad en acciones decisivas de gol',
      'Lectura, posición y entradas',
      'Potencia en el contacto físico',
      'Intensidad al final del partido',
      'Decisiones claras bajo presión',
    ],
    'pt-BR': [
      'Aceleração e corridas de recuperação',
      'Controle quando o espaço desaparece',
      'Peso e visão na distribuição',
      'Qualidade nas ações decisivas de gol',
      'Leitura, posicionamento e desarmes',
      'Potência no contato físico',
      'Intensidade no fim da partida',
      'Decisões claras sob pressão',
    ],
    'fr': [
      'Accélération et courses de repli',
      'Contrôle quand l’espace disparaît',
      'Dosage et vision dans la distribution',
      'Qualité dans les gestes décisifs',
      'Lecture, placement et duels',
      'Puissance dans le contact',
      'Intensité répétée en fin de match',
      'Décisions lucides sous pression',
    ],
  };
  final base = descriptions[locale]![attribute.index];
  return '$base · ${localizedPosition(locale, position.name)}';
}

String _localizedMatchHeadline(
  String locale,
  String playerName,
  bool succeeded,
) {
  final values = succeeded
      ? {
          'en': '$playerName made the moment count under the lights.',
          'es': '$playerName aprovechó el momento bajo los focos.',
          'pt-BR': '$playerName aproveitou o momento sob os refletores.',
          'fr': '$playerName a saisi son moment sous les projecteurs.',
        }
      : {
          'en': '$playerName could not force the moment under the lights.',
          'es': '$playerName no pudo forzar el momento bajo los focos.',
          'pt-BR':
              '$playerName não conseguiu forçar o momento sob os refletores.',
          'fr': '$playerName n’a pas pu forcer le moment sous les projecteurs.',
        };
  return values[locale] ?? values['en']!;
}
