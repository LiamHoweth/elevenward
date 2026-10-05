import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../league_presentation.dart';
import '../l10n_context.dart';
import '../player_portraits.dart';
import '../theme.dart';
import '../ui_copy.dart';

final class CreateCareerScreen extends StatefulWidget {
  const CreateCareerScreen({
    super.key,
    required this.controller,
    required this.slotIndex,
  });

  final AppController controller;
  final int slotIndex;

  @override
  State<CreateCareerScreen> createState() => _CreateCareerScreenState();
}

final class _CreateCareerScreenState extends State<CreateCareerScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nationSearch = TextEditingController();
  final _clubSearch = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final WorldDefinition _world;
  PositionFamily? _position;
  Archetype? _archetype;
  String? _nationalTeamId;
  String? _clubId;
  FootballRegion? _clubRegion;
  String? _leagueCountryId;
  DivisionLevel? _division;
  Difficulty _difficulty = Difficulty.professional;
  String _portraitId = 'player_01';
  bool _saving = false;
  bool _editingFromReview = false;
  VoidCallback? _cancelReviewEdit;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _world =
        widget.controller.availableContent?.catalog.world ??
        widget.controller.activeContent?.catalog.world ??
        buildLaunchWorld();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nationSearch.dispose();
    _clubSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final isReview = _step == 3;
    return PopScope(
      canPop: !_saving && _step == 0 && !_editingFromReview,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.createPlayer),
          leading: _step > 0 || _editingFromReview || Navigator.canPop(context)
              ? IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: _saving ? null : _back,
                  icon: const BackButtonIcon(),
                )
              : null,
        ),
        body: Form(
          key: _form,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                child: _ProgressHeader(step: _step),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: motionDuration(
                    context,
                    const Duration(milliseconds: 180),
                  ),
                  child: ListView(
                    key: Key('career-creator-step-$_step'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    children: _stepContent(context, locale),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: Row(
                    children: [
                      if (_step > 0 || _editingFromReview) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _back,
                            child: Text(
                              uiCopy(
                                locale,
                                _editingFromReview ? 'creatorCancel' : 'back',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          key: Key(
                            isReview
                                ? 'career-create-save'
                                : 'career-create-next',
                          ),
                          onPressed: _saving
                              ? null
                              : isReview
                              ? _save
                              : _next,
                          child: _saving
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isReview
                                      ? context.l10n.startCareer.toUpperCase()
                                      : uiCopy(
                                          locale,
                                          _editingFromReview
                                              ? 'creatorReturnReview'
                                              : 'continue',
                                        ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _stepContent(BuildContext context, String locale) =>
      switch (_step) {
        0 => _identityStep(context, locale),
        1 => _nationalityStep(context, locale),
        2 => _clubStep(context, locale),
        _ => _reviewStep(context, locale),
      };

  List<Widget> _identityStep(BuildContext context, String locale) => [
    _Label(uiCopy(locale, 'identityStyle')),
    const SizedBox(height: 14),
    AutofillGroup(
      child: Column(
        children: [
          TextFormField(
            key: const Key('career-first-name'),
            controller: _firstName,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            decoration: InputDecoration(labelText: uiCopy(locale, 'firstName')),
            onChanged: (_) => setState(() {}),
            validator: (value) => (value?.trim().isNotEmpty ?? false)
                ? null
                : uiCopy(contentLocale(context), 'firstNameRequired'),
          ),
          const SizedBox(height: 4),
          TextFormField(
            key: const Key('career-last-name'),
            controller: _lastName,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.familyName],
            decoration: InputDecoration(labelText: uiCopy(locale, 'lastName')),
            onChanged: (_) => setState(() {}),
            validator: (value) => (value?.trim().isNotEmpty ?? false)
                ? null
                : uiCopy(contentLocale(context), 'lastNameRequired'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    _portraitSelection(context, locale),
    const SizedBox(height: 20),
    _roleSelection(context, locale),
  ];

  Widget _portraitSelection(BuildContext context, String locale) {
    final playerName = '${_firstName.text.trim()} ${_lastName.text.trim()}'
        .trim();
    final role = [
      if (_position != null) localizedPosition(locale, _position!.name),
      if (_archetype != null) localizedArchetype(locale, _archetype!),
    ].join(' · ');
    return BroadcastPanel(
      child: Column(
        children: [
          _PortraitImage(
            key: const Key('career-selected-portrait'),
            id: _portraitId,
            size: 120,
          ),
          const SizedBox(height: 12),
          Text(
            playerName.isEmpty
                ? uiCopy(locale, 'creatorPlayerPreview')
                : playerName,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            role.isEmpty ? uiCopy(locale, 'creatorChooseRole') : role,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            uiCopy(locale, 'playerPortrait'),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            uiCopy(locale, 'playerPortraitBody'),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('career-choose-portrait'),
              onPressed: _openPortraitPicker,
              child: Text(uiCopy(locale, 'choosePortrait')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleSelection(BuildContext context, String locale) {
    final position = _position;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(uiCopy(locale, 'creatorPosition')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PositionFamily.values.map((value) {
            return ChoiceChip(
              key: Key('career-position-${value.name}'),
              label: Text(localizedPosition(locale, value.name)),
              selected: position == value,
              onSelected: (_) => setState(() {
                if (_position != value) {
                  _position = value;
                  _archetype = null;
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        _Label(uiCopy(locale, 'creatorArchetype')),
        const SizedBox(height: 8),
        if (position == null)
          Text(
            uiCopy(locale, 'creatorChoosePositionFirst'),
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...Archetype.values
              .where((value) => value.positionFamily == position)
              .map((value) => _archetypeCard(context, locale, value)),
      ],
    );
  }

  Widget _archetypeCard(
    BuildContext context,
    String locale,
    Archetype archetype,
  ) {
    final selected = _archetype == archetype;
    final attributes = PlayerAttributes.forArchetype(archetype);
    final strongest = PlayerAttribute.values.toList()
      ..sort((left, right) {
        final difference = attributes[right].compareTo(attributes[left]);
        return difference != 0 ? difference : left.index.compareTo(right.index);
      });
    final strengths = strongest
        .take(3)
        .map(
          (attribute) =>
              '${localizedPlayerAttribute(locale, attribute)} ${attributes[attribute]}',
        )
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        excludeSemantics: true,
        label:
            '${localizedArchetype(locale, archetype)}. ${localizedArchetypeDescription(locale, archetype)}. $strengths',
        onTap: () => setState(() => _archetype = archetype),
        child: Material(
          color: ElevenwardColors.panelLight,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: Key('career-archetype-${archetype.name}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _archetype = archetype),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? ElevenwardColors.grass
                      : ElevenwardColors.line,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? ElevenwardColors.grass
                            : ElevenwardColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          localizedArchetype(locale, archetype),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    localizedArchetypeDescription(locale, archetype),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strengths,
                    style: TextStyle(
                      color: ElevenwardColors.grass,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPortraitPicker() async {
    final locale = contentLocale(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(
                  uiCopy(locale, 'choosePortrait'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 560 ? 5 : 3;
                    return GridView.builder(
                      key: const Key('career-portrait-grid'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: playerPortraitIds.length,
                      itemBuilder: (context, index) {
                        final id = playerPortraitIds[index];
                        final isSelected = id == _portraitId;
                        return Semantics(
                          button: true,
                          selected: isSelected,
                          label:
                              '${uiCopy(locale, 'playerPortrait')} ${index + 1} ${uiCopy(locale, 'of')} ${playerPortraitIds.length}',
                          child: InkWell(
                            key: Key('career-portrait-$id'),
                            onTap: () => Navigator.of(context).pop(id),
                            borderRadius: BorderRadius.circular(14),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: ElevenwardColors.panelLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? ElevenwardColors.grass
                                      : ElevenwardColors.line,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.asset(
                                      playerPortraitAsset(id)!,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      excludeFromSemantics: true,
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: 6,
                                        bottom: 6,
                                        child: Icon(
                                          Icons.check_circle,
                                          color: ElevenwardColors.grass,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _portraitId = selected);
    }
  }

  List<Widget> _nationalityStep(BuildContext context, String locale) {
    const popularIds = [
      'england',
      'spain',
      'brazil',
      'argentina',
      'france',
      'germany',
    ];
    final term = _nationSearch.text.trim().toLowerCase();
    bool matches(NationalTeamDefinition team) {
      final country = _world.country(team.countryId);
      return term.isEmpty ||
          country.nameFor(locale).toLowerCase().contains(term) ||
          country.names.values.any(
            (name) => name.toLowerCase().contains(term),
          ) ||
          _regionName(locale, team.region).toLowerCase().contains(term);
    }

    return [
      _Label(uiCopy(locale, 'creatorNationalStep')),
      const SizedBox(height: 8),
      Text(
        uiCopy(locale, 'nationalityCreatorBody'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 14),
      if (_nationalTeamId case final selectedTeamId?) ...[
        BroadcastPanel(
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: ElevenwardColors.grass),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(uiCopy(locale, 'creatorSelectedNationalTeam')),
                    Text(
                      _world
                          .country(
                            _world.nationalTeam(selectedTeamId).countryId,
                          )
                          .nameFor(locale),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      TextField(
        key: const Key('nationality-search'),
        controller: _nationSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: context.l10n.nationalTeam,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _nationSearch.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('nationality-search-clear'),
                  tooltip: uiCopy(locale, 'clearFilter'),
                  onPressed: () => setState(_nationSearch.clear),
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
      const SizedBox(height: 16),
      if (term.isEmpty) ...[
        _Label(uiCopy(locale, 'popular')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: popularIds.map((id) {
            final team = _world.nationalTeam(id);
            return ChoiceChip(
              key: Key('popular-nationality-$id'),
              label: Text(_world.country(team.countryId).nameFor(locale)),
              selected: _nationalTeamId == id,
              onSelected: (_) => setState(() => _nationalTeamId = id),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
      ],
      if (!_world.nationalTeams.any(matches))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            _creatorCopy(locale, 'noNationalityResults'),
            key: const Key('nationality-search-empty'),
            textAlign: TextAlign.center,
          ),
        ),
      RadioGroup<String>(
        groupValue: _nationalTeamId,
        onChanged: (value) => setState(() => _nationalTeamId = value),
        child: Column(
          children: FootballRegion.values.map((region) {
            final teams =
                _world.nationalTeams
                    .where((team) => team.region == region && matches(team))
                    .toList()
                  ..sort(
                    (left, right) => _world
                        .country(left.countryId)
                        .nameFor(locale)
                        .compareTo(
                          _world.country(right.countryId).nameFor(locale),
                        ),
                  );
            if (teams.isEmpty) return const SizedBox.shrink();
            return ExpansionTile(
              key: PageStorageKey('nationality-${region.name}-$term'),
              initiallyExpanded: term.isNotEmpty,
              tilePadding: EdgeInsets.zero,
              title: Text(_regionName(locale, region)),
              children: teams
                  .map(
                    (team) => RadioListTile<String>(
                      key: Key('nationality-${team.id}'),
                      contentPadding: EdgeInsets.zero,
                      value: team.id,
                      title: Text(
                        _world.country(team.countryId).nameFor(locale),
                      ),
                      subtitle: Text(team.confederation.name.toUpperCase()),
                    ),
                  )
                  .toList(),
            );
          }).toList(),
        ),
      ),
    ];
  }

  List<Widget> _clubStep(BuildContext context, String locale) {
    final leagueCountries =
        _world.countries.where((country) => country.hasLeague).toList()..sort(
          (left, right) =>
              (left.leagueRank ?? 26).compareTo(right.leagueRank ?? 26),
        );
    final countriesInRegion = leagueCountries
        .where((country) => country.region == _clubRegion)
        .toList(growable: false);
    final term = _clubSearch.text.trim().toLowerCase();
    final displayedClubs = _world.clubs.where((club) {
      final country = _world.country(club.countryId);
      final league = _world.leagueForClub(club.id);
      if (term.isNotEmpty) {
        return club.name.toLowerCase().contains(term) ||
            country.nameFor(locale).toLowerCase().contains(term) ||
            country.names.values.any(
              (name) => name.toLowerCase().contains(term),
            ) ||
            leagueMatchesSearch(league, term);
      }
      return club.countryId == _leagueCountryId && club.division == _division;
    }).toList()..sort((left, right) => left.name.compareTo(right.name));

    return [
      _Label(uiCopy(locale, 'creatorClubStep')),
      const SizedBox(height: 8),
      TextField(
        key: const Key('club-search'),
        controller: _clubSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: uiCopy(locale, 'creatorSearchClubs'),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _clubSearch.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('club-search-clear'),
                  tooltip: uiCopy(locale, 'clearFilter'),
                  onPressed: () => setState(_clubSearch.clear),
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        uiCopy(locale, 'clubCreatorBody'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 14),
      if (_clubId case final selectedClubId?) ...[
        BroadcastPanel(
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: ElevenwardColors.grass),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(uiCopy(locale, 'creatorSelectedClub')),
                    Text(
                      _world.club(selectedClubId).name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      leagueDisplayName(_world.leagueForClub(selectedClubId)),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      _Label(uiCopy(locale, 'topSixLeagues')),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: leagueCountries.take(6).map((country) {
          final topLeague = _world.leagues.firstWhere(
            (league) =>
                league.countryId == country.id &&
                league.division == DivisionLevel.first,
          );
          return ActionChip(
            key: Key('league-shortcut-${country.id}'),
            label: Text(leagueDisplayName(topLeague)),
            onPressed: () => setState(() {
              _clubId = null;
              _clubRegion = country.region;
              _leagueCountryId = country.id;
              _division = DivisionLevel.first;
              _clubSearch.clear();
            }),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),
      ExpansionTile(
        key: const PageStorageKey('career-browse-leagues'),
        title: Text(uiCopy(locale, 'creatorBrowseLeagues')),
        tilePadding: EdgeInsets.zero,
        children: [
          DropdownButtonFormField<FootballRegion>(
            key: ValueKey('region-${_clubRegion?.name}'),
            initialValue: _clubRegion,
            isExpanded: true,
            decoration: InputDecoration(labelText: uiCopy(locale, 'region')),
            items: FootballRegion.values
                .where(
                  (region) => leagueCountries.any(
                    (country) => country.region == region,
                  ),
                )
                .map(
                  (region) => DropdownMenuItem(
                    value: region,
                    child: Text(_regionName(locale, region)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _clubId = null;
              _clubRegion = value;
              _leagueCountryId = null;
              _division = null;
              _clubSearch.clear();
            }),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('system-${_clubRegion?.name}-$_leagueCountryId'),
            initialValue: _leagueCountryId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: uiCopy(locale, 'leagueSystem'),
            ),
            items: countriesInRegion.map((country) {
              final rank = country.leagueRank == null
                  ? uiCopy(locale, 'bonusSystem')
                  : 'IFFHS #${country.leagueRank}';
              return DropdownMenuItem(
                value: country.id,
                child: Text(
                  '${country.nameFor(locale)} · $rank',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() {
              _clubId = null;
              _leagueCountryId = value;
              _division = null;
              _clubSearch.clear();
            }),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<DivisionLevel>(
            key: ValueKey('division-$_leagueCountryId-${_division?.name}'),
            initialValue: _division,
            isExpanded: true,
            decoration: InputDecoration(labelText: uiCopy(locale, 'division')),
            items: DivisionLevel.values
                .map(
                  (division) => DropdownMenuItem(
                    value: division,
                    child: Text(
                      _leagueCountryId == null
                          ? division == DivisionLevel.first
                                ? uiCopy(locale, 'firstDivision')
                                : uiCopy(locale, 'secondDivision')
                          : leagueDisplayName(
                              _world.leagues.firstWhere(
                                (league) =>
                                    league.countryId == _leagueCountryId &&
                                    league.division == division,
                              ),
                            ),
                    ),
                  ),
                )
                .toList(),
            onChanged: _leagueCountryId == null
                ? null
                : (value) => setState(() {
                    _clubId = null;
                    _division = value;
                    _clubSearch.clear();
                  }),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (displayedClubs.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            term.isEmpty
                ? uiCopy(locale, 'chooseClubPath')
                : uiCopy(locale, 'noClubSearchResults'),
            textAlign: TextAlign.center,
          ),
        )
      else
        RadioGroup<String>(
          groupValue: _clubId,
          onChanged: (value) {
            if (value != null) _selectClub(_world.club(value));
          },
          child: Column(
            children: displayedClubs
                .map(
                  (club) => RadioListTile<String>(
                    key: Key('starting-club-${club.id}'),
                    contentPadding: EdgeInsets.zero,
                    value: club.id,
                    title: Text(club.name),
                    subtitle: Text(
                      '${_world.country(club.countryId).nameFor(locale)} · ${leagueDisplayName(_world.leagueForClub(club.id))}',
                    ),
                  ),
                )
                .toList(),
          ),
        ),
    ];
  }

  List<Widget> _reviewStep(BuildContext context, String locale) {
    final team = _world.nationalTeam(_nationalTeamId!);
    final club = _world.club(_clubId!);
    final edit = uiCopy(locale, 'creatorEdit');
    return [
      _Label(uiCopy(locale, 'reviewCareer')),
      const SizedBox(height: 14),
      BroadcastPanel(
        child: Column(
          children: [
            _PortraitImage(id: _portraitId, size: 120),
            TextButton.icon(
              key: const Key('career-edit-portrait'),
              onPressed: () => _editStep(0),
              icon: const Icon(Icons.edit_outlined),
              label: Text('$edit ${uiCopy(locale, 'playerPortrait')}'),
            ),
            _ReviewRow(
              label: context.l10n.playerName,
              value: '${_firstName.text.trim()} ${_lastName.text.trim()}',
              onEdit: () => _editStep(0),
              editTooltip: '$edit ${context.l10n.playerName}',
            ),
            _ReviewRow(
              label: uiCopy(locale, 'creatorPosition'),
              value: localizedPosition(locale, _position!.name),
              onEdit: () => _editStep(0),
              editTooltip: '$edit ${uiCopy(locale, 'creatorPosition')}',
            ),
            _ReviewRow(
              label: uiCopy(locale, 'creatorArchetype'),
              value: localizedArchetype(locale, _archetype!),
              onEdit: () => _editStep(0),
              editTooltip: '$edit ${uiCopy(locale, 'creatorArchetype')}',
            ),
            _ReviewRow(
              label: context.l10n.nationalTeam,
              value: _world.country(team.countryId).nameFor(locale),
              onEdit: () => _editStep(1),
              editTooltip: '$edit ${context.l10n.nationalTeam}',
            ),
            _ReviewRow(
              label: context.l10n.startingClub,
              value: club.name,
              onEdit: () => _editStep(2),
              editTooltip: '$edit ${context.l10n.startingClub}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _Label(context.l10n.difficulty),
      const SizedBox(height: 8),
      RadioGroup<Difficulty>(
        groupValue: _difficulty,
        onChanged: (value) => setState(() => _difficulty = value!),
        child: Column(
          children: Difficulty.values
              .map(
                (difficulty) => RadioListTile<Difficulty>(
                  contentPadding: EdgeInsets.zero,
                  value: difficulty,
                  title: Text(switch (difficulty) {
                    Difficulty.story => context.l10n.story,
                    Difficulty.professional => context.l10n.professional,
                    Difficulty.worldClass => context.l10n.worldClass,
                  }),
                  subtitle: Text(
                    uiCopy(locale, switch (difficulty) {
                      Difficulty.story => 'creatorDifficultyStory',
                      Difficulty.professional =>
                        'creatorDifficultyProfessional',
                      Difficulty.worldClass => 'creatorDifficultyWorldClass',
                    }),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ];
  }

  void _next() {
    if (_step == 0) {
      if (!_form.currentState!.validate()) return;
      if (_position == null || _archetype == null) {
        _selectionRequired(
          uiCopy(contentLocale(context), 'creatorChooseRoleRequired'),
        );
        return;
      }
    }
    if (_step == 1 && _nationalTeamId == null) {
      _selectionRequired(
        uiCopy(contentLocale(context), 'chooseNationalTeamRequired'),
      );
      return;
    }
    if (_step == 2 && _clubId == null) {
      _selectionRequired(uiCopy(contentLocale(context), 'chooseClubRequired'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      if (_editingFromReview) {
        _editingFromReview = false;
        _cancelReviewEdit = null;
        _step = 3;
      } else {
        _step += 1;
      }
    });
  }

  void _selectClub(ClubDefinition club) {
    setState(() {
      _clubId = club.id;
      _clubRegion = _world.country(club.countryId).region;
      _leagueCountryId = club.countryId;
      _division = club.division;
      _clubSearch.clear();
    });
  }

  void _editStep(int step) {
    final firstName = _firstName.text;
    final lastName = _lastName.text;
    final portraitId = _portraitId;
    final position = _position;
    final archetype = _archetype;
    final nationalTeamId = _nationalTeamId;
    final nationSearch = _nationSearch.text;
    final clubId = _clubId;
    final clubRegion = _clubRegion;
    final leagueCountryId = _leagueCountryId;
    final division = _division;
    final clubSearch = _clubSearch.text;
    _cancelReviewEdit = () {
      _firstName.text = firstName;
      _lastName.text = lastName;
      _portraitId = portraitId;
      _position = position;
      _archetype = archetype;
      _nationalTeamId = nationalTeamId;
      _nationSearch.text = nationSearch;
      _clubId = clubId;
      _clubRegion = clubRegion;
      _leagueCountryId = leagueCountryId;
      _division = division;
      _clubSearch.text = clubSearch;
    };
    setState(() {
      _editingFromReview = true;
      _step = step;
    });
  }

  void _cancelEdit() {
    setState(() {
      _cancelReviewEdit?.call();
      _cancelReviewEdit = null;
      _editingFromReview = false;
      _step = 3;
    });
  }

  void _back() {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (_editingFromReview) {
      _cancelEdit();
    } else if (_step > 0) {
      setState(() => _step -= 1);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _selectionRequired(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 90),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate() ||
        _firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        _position == null ||
        _archetype == null ||
        _nationalTeamId == null ||
        _clubId == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    final previousGeneration = widget.controller.activeCareerGeneration;
    setState(() => _saving = true);
    try {
      await widget.controller.createCareer(
        slotIndex: widget.slotIndex,
        firstName: _firstName.text,
        lastName: _lastName.text,
        archetype: _archetype!,
        nationalTeamId: _nationalTeamId!,
        club: _world.club(_clubId!),
        difficulty: _difficulty,
        portraitId: _portraitId,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (widget.controller.activeCareerGeneration == previousGeneration ||
          widget.controller.activeSlotIndex != widget.slotIndex) {
        _selectionRequired(
          widget.controller.lastMessage ?? context.l10n.errorTryAgain,
        );
        return;
      }
      Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      _selectionRequired(context.l10n.errorTryAgain);
    }
  }
}

String _creatorCopy(String locale, String key) {
  const values = {
    'noNationalityResults': {
      'en': 'No national teams match that search.',
      'es': 'Ninguna selección coincide con la búsqueda.',
      'pt-BR': 'Nenhuma seleção corresponde à pesquisa.',
      'fr': 'Aucune équipe nationale ne correspond à cette recherche.',
    },
  };
  return values[key]?[locale] ?? values[key]?['en'] ?? key;
}

final class _PortraitImage extends StatelessWidget {
  const _PortraitImage({super.key, required this.id, required this.size});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox.square(
      dimension: size,
      child: Image.asset(
        playerPortraitAsset(id)!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        semanticLabel:
            '${uiCopy(contentLocale(context), 'playerPortrait')} ${int.parse(id.substring(7))}',
      ),
    ),
  );
}

String _regionName(String locale, FootballRegion region) {
  const names = <FootballRegion, Map<String, String>>{
    FootballRegion.europe: {
      'en': 'Europe',
      'es': 'Europa',
      'pt-BR': 'Europa',
      'fr': 'Europe',
    },
    FootballRegion.southAmerica: {
      'en': 'South America',
      'es': 'Sudamérica',
      'pt-BR': 'América do Sul',
      'fr': 'Amérique du Sud',
    },
    FootballRegion.northAmerica: {
      'en': 'North/Central America',
      'es': 'Norte y Centroamérica',
      'pt-BR': 'América do Norte e Central',
      'fr': 'Amérique du Nord et centrale',
    },
    FootballRegion.asia: {
      'en': 'Asia',
      'es': 'Asia',
      'pt-BR': 'Ásia',
      'fr': 'Asie',
    },
    FootballRegion.africa: {
      'en': 'Africa',
      'es': 'África',
      'pt-BR': 'África',
      'fr': 'Afrique',
    },
    FootballRegion.oceania: {
      'en': 'Oceania',
      'es': 'Oceanía',
      'pt-BR': 'Oceania',
      'fr': 'Océanie',
    },
  };
  return names[region]![locale] ?? names[region]!['en']!;
}

final class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            '${uiCopy(locale, 'step')} ${step + 1} ${uiCopy(locale, 'of')} 4',
            key: const Key('career-creator-progress'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            children: List.generate(
              4,
              (index) => Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsetsDirectional.only(end: index == 3 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index <= step
                        ? ElevenwardColors.grass
                        : ElevenwardColors.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.onEdit,
    this.editTooltip,
  });
  final String label;
  final String value;
  final VoidCallback? onEdit;
  final String? editTooltip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (onEdit != null)
          IconButton(
            onPressed: onEdit,
            tooltip: editTooltip,
            icon: const Icon(Icons.edit_outlined),
          ),
      ],
    ),
  );
}

final class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: ElevenwardColors.grass,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
    ),
  );
}
