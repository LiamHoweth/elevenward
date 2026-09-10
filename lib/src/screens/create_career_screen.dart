import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../league_presentation.dart';
import '../l10n_context.dart';
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
  Archetype _archetype = Archetype.poacher;
  String? _nationalTeamId;
  String? _clubId;
  FootballRegion? _clubRegion;
  String? _leagueCountryId;
  DivisionLevel? _division;
  Difficulty _difficulty = Difficulty.professional;
  bool _saving = false;
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
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.createPlayer)),
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
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _step -= 1),
                          child: Text(uiCopy(locale, 'back')),
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
                                    : uiCopy(locale, 'continue'),
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
            validator: (value) => (value?.trim().isNotEmpty ?? false)
                ? null
                : uiCopy(contentLocale(context), 'lastNameRequired'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<Archetype>(
      initialValue: _archetype,
      isExpanded: true,
      decoration: InputDecoration(labelText: context.l10n.positionAndStyle),
      items: Archetype.values
          .map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(
                '${localizedPosition(locale, value.positionFamily.name)} · ${localizedArchetype(locale, value)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _archetype = value!),
    ),
  ];

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
      _Label(context.l10n.nationalTeam),
      const SizedBox(height: 8),
      Text(
        uiCopy(locale, 'nationalityCreatorBody'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 14),
      TextField(
        key: const Key('nationality-search'),
        controller: _nationSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: context.l10n.nationalTeam,
          prefixIcon: const Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 16),
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
              key: PageStorageKey('nationality-${region.name}'),
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
      _Label(context.l10n.startingClub),
      const SizedBox(height: 8),
      Text(
        uiCopy(locale, 'clubCreatorBody'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 14),
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
              _clubRegion = country.region;
              _leagueCountryId = country.id;
              _division = DivisionLevel.first;
              _clubSearch.clear();
            }),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),
      TextField(
        key: const Key('club-search'),
        controller: _clubSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: context.l10n.startingClub,
          prefixIcon: const Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<FootballRegion>(
        key: ValueKey('region-${_clubRegion?.name}'),
        initialValue: _clubRegion,
        isExpanded: true,
        decoration: InputDecoration(labelText: uiCopy(locale, 'region')),
        items: FootballRegion.values
            .where(
              (region) =>
                  leagueCountries.any((country) => country.region == region),
            )
            .map(
              (region) => DropdownMenuItem(
                value: region,
                child: Text(_regionName(locale, region)),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() {
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
        decoration: InputDecoration(labelText: uiCopy(locale, 'leagueSystem')),
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
                _division = value;
                _clubSearch.clear();
              }),
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
          onChanged: (value) => setState(() => _clubId = value),
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
    return [
      _Label(uiCopy(locale, 'reviewCareer')),
      const SizedBox(height: 14),
      BroadcastPanel(
        child: Column(
          children: [
            _ReviewRow(
              label: context.l10n.playerName,
              value: '${_firstName.text.trim()} ${_lastName.text.trim()}',
            ),
            _ReviewRow(
              label: context.l10n.positionAndStyle,
              value: localizedArchetype(locale, _archetype),
            ),
            _ReviewRow(
              label: context.l10n.nationalTeam,
              value: _world.country(team.countryId).nameFor(locale),
            ),
            _ReviewRow(label: context.l10n.startingClub, value: club.name),
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
                ),
              )
              .toList(),
        ),
      ),
    ];
  }

  void _next() {
    if (_step == 0 && !_form.currentState!.validate()) return;
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
    setState(() => _step += 1);
  }

  void _selectionRequired(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() ||
        _nationalTeamId == null ||
        _clubId == null) {
      return;
    }
    setState(() => _saving = true);
    await widget.controller.createCareer(
      slotIndex: widget.slotIndex,
      firstName: _firstName.text,
      lastName: _lastName.text,
      archetype: _archetype,
      nationalTeamId: _nationalTeamId!,
      club: _world.club(_clubId!),
      difficulty: _difficulty,
    );
    if (mounted) Navigator.of(context).pop();
  }
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
  Widget build(BuildContext context) => Row(
    children: List.generate(4, (index) {
      final active = index <= step;
      final locale = contentLocale(context);
      return Expanded(
        child: Semantics(
          label:
              '${uiCopy(locale, 'step')} ${index + 1} ${uiCopy(locale, 'of')} 4',
          selected: index == step,
          child: Container(
            height: 5,
            margin: EdgeInsetsDirectional.only(end: index == 3 ? 0 : 6),
            decoration: BoxDecoration(
              color: active ? ElevenwardColors.grass : ElevenwardColors.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
    }),
  );
}

final class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;

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
    style: const TextStyle(
      color: ElevenwardColors.grass,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
    ),
  );
}
