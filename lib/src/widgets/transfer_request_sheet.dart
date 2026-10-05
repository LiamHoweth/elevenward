import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../l10n_context.dart';
import '../league_presentation.dart';
import '../theme.dart';
import '../ui_copy.dart';

final class TransferRequestDraft {
  const TransferRequestDraft({
    required this.targetLeagueId,
    this.preferredClubId,
  });

  final String targetLeagueId;
  final String? preferredClubId;
}

Future<TransferRequestDraft?> showTransferRequestFlow({
  required BuildContext context,
  required CareerSnapshot career,
  required WorldDefinition world,
}) => showModalBottomSheet<TransferRequestDraft>(
  context: context,
  isScrollControlled: true,
  showDragHandle: false,
  useSafeArea: true,
  builder: (_) => _TransferRequestSheet(career: career, world: world),
);

final class _TransferRequestSheet extends StatefulWidget {
  const _TransferRequestSheet({required this.career, required this.world});

  final CareerSnapshot career;
  final WorldDefinition world;

  @override
  State<_TransferRequestSheet> createState() => _TransferRequestSheetState();
}

final class _TransferRequestSheetState extends State<_TransferRequestSheet> {
  final _search = TextEditingController();
  late final CareerWorldState _marketState;
  String? _targetLeagueId;
  String? _preferredClubId;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _marketState = widget.career.phase == CareerPhase.offseason
        ? const WorldSimulator().beginNextSeason(
            widget.career.world,
            widget.career.seed,
            definition: widget.world,
          )
        : widget.career.world;
    final request = widget.career.transferRequest;
    if (request != null &&
        _marketState.leagueParticipants.containsKey(request.targetLeagueId)) {
      _targetLeagueId = request.targetLeagueId;
      final members = _marketState.leagueParticipants[request.targetLeagueId]!;
      if (members.contains(request.preferredClubId)) {
        _preferredClubId = request.preferredClubId;
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height - keyboardInset) * .9,
        child: Column(
          children: [
            if (keyboardInset == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const Spacer(),
                    Text('${_step + 1}/2'),
                  ],
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: _step == 0
                  ? _leagueStep(context, locale)
                  : _clubStep(context, locale),
            ),
            const Divider(height: 1),
            if (keyboardInset == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 340 ||
                        MediaQuery.textScalerOf(context).scale(14) > 19;
                    final back = OutlinedButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _step = 0;
                          _search.clear();
                        });
                      },
                      child: Text(
                        MaterialLocalizations.of(context).backButtonTooltip,
                      ),
                    );
                    final submit = FilledButton(
                      key: Key(
                        _step == 0
                            ? 'transfer-request-continue'
                            : 'transfer-request-submit',
                      ),
                      onPressed: _targetLeagueId == null
                          ? null
                          : _step == 0
                          ? () {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _step = 1;
                                _search.clear();
                              });
                            }
                          : () => _confirmAndSubmit(locale),
                      child: Text(
                        _step == 0
                            ? uiCopy(locale, 'continue').toUpperCase()
                            : uiCopy(
                                locale,
                                'fileTransferRequest',
                              ).toUpperCase(),
                      ),
                    );
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_step == 1) ...[back, const SizedBox(height: 8)],
                          submit,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        if (_step == 1) ...[
                          Expanded(child: back),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: submit),
                      ],
                    );
                  },
                ),
              ),
            if (keyboardInset > 0)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: _copy(locale, 'hideKeyboard'),
                  onPressed: () => FocusScope.of(context).unfocus(),
                  icon: const Icon(Icons.keyboard_hide_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepHeading(BuildContext context, String locale) => Text(
    _step == 0
        ? uiCopy(locale, 'chooseTargetLeague')
        : uiCopy(locale, 'choosePreferredClub'),
    key: const Key('transfer-request-step-heading'),
    style: Theme.of(context).textTheme.titleLarge,
  );

  Widget _leagueStep(BuildContext context, String locale) {
    final term = _search.text.trim().toLowerCase();
    final leagues =
        widget.world.leagues.where((league) {
          if (!_marketState.leagueParticipants.containsKey(league.id)) {
            return false;
          }
          if (term.isEmpty) return true;
          final country = widget.world.country(league.countryId);
          return leagueMatchesSearch(league, term) ||
              country.names.values.any(
                (name) => name.toLowerCase().contains(term),
              );
        }).toList()..sort((left, right) {
          final rank = (left.systemRank ?? 99).compareTo(
            right.systemRank ?? 99,
          );
          if (rank != 0) return rank;
          return left.division.index.compareTo(right.division.index);
        });
    return ListView(
      key: const Key('transfer-request-league-step'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _stepHeading(context, locale),
        const SizedBox(height: 12),
        TextField(
          key: const Key('transfer-league-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            labelText: uiCopy(locale, 'searchLeagues'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _clearSearch(locale),
          ),
        ),
        const SizedBox(height: 12),
        if (_targetLeagueId != null) ...[
          Text(
            '${uiCopy(locale, 'targetLeague')}: '
            '${leagueDisplayName(widget.world.leagues.firstWhere((league) => league.id == _targetLeagueId))}',
            key: const Key('transfer-request-selected-league'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
        ],
        if (leagues.isEmpty)
          Text(
            _copy(locale, 'noLeagues'),
            key: const Key('transfer-request-no-leagues'),
          ),
        RadioGroup<String>(
          groupValue: _targetLeagueId,
          onChanged: (value) => setState(() {
            _targetLeagueId = value;
            _preferredClubId = null;
          }),
          child: Column(
            children: leagues
                .map(
                  (league) => RadioListTile<String>(
                    key: Key('transfer-league-${league.id}'),
                    contentPadding: EdgeInsets.zero,
                    value: league.id,
                    title: Text(leagueDisplayName(league)),
                    subtitle: Text(
                      widget.world.country(league.countryId).nameFor(locale),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _clubStep(BuildContext context, String locale) {
    final league = widget.world.leagues.firstWhere(
      (item) => item.id == _targetLeagueId,
    );
    final term = _search.text.trim().toLowerCase();
    final clubs =
        _marketState.leagueParticipants[league.id]!
            .where((id) => id != widget.career.clubId)
            .map(widget.world.club)
            .where((club) => club.name.toLowerCase().contains(term))
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    final alreadyApplied =
        widget.career.transferRequestTrustPenaltySeason == widget.career.season;
    return ListView(
      key: const Key('transfer-request-club-step'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _stepHeading(context, locale),
        const SizedBox(height: 12),
        BroadcastPanel(
          accent: ElevenwardColors.grass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uiCopy(locale, 'targetLeague').toUpperCase(),
                style: TextStyle(
                  color: ElevenwardColors.grass,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                leagueDisplayName(league),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${uiCopy(locale, 'preferredClub')}: '
                '${_preferredClubId == null ? uiCopy(locale, 'anyEligibleClub') : widget.world.club(_preferredClubId!).name}',
                key: const Key('transfer-request-selected-club'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(_copy(locale, 'preferenceGuidance')),
              const SizedBox(height: 8),
              Text(
                alreadyApplied
                    ? uiCopy(locale, 'transferTrustAlreadyApplied')
                    : uiCopy(locale, 'transferTrustWarning'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('transfer-club-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            labelText: uiCopy(locale, 'searchClubs'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _clearSearch(locale),
          ),
        ),
        const SizedBox(height: 10),
        RadioGroup<String>(
          groupValue: _preferredClubId ?? '',
          onChanged: (value) => setState(
            () => _preferredClubId = value == null || value.isEmpty
                ? null
                : value,
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                key: const Key('transfer-club-any'),
                contentPadding: EdgeInsets.zero,
                value: '',
                title: Text(uiCopy(locale, 'anyEligibleClub')),
              ),
              if (clubs.isEmpty)
                Text(
                  _copy(locale, 'noClubs'),
                  key: const Key('transfer-request-no-clubs'),
                ),
              ...clubs.map(
                (club) => RadioListTile<String>(
                  key: Key('transfer-club-${club.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: club.id,
                  title: Text(club.name),
                  subtitle: Text('${club.quality} OVR'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndSubmit(String locale) async {
    FocusScope.of(context).unfocus();
    final league = widget.world.leagues.firstWhere(
      (item) => item.id == _targetLeagueId,
    );
    final preferredClub = _preferredClubId == null
        ? null
        : widget.world.club(_preferredClubId!);
    final alreadyApplied =
        widget.career.transferRequestTrustPenaltySeason == widget.career.season;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(uiCopy(locale, 'confirmTransferRequest')),
        content: Text(
          '${uiCopy(locale, 'targetLeague')}: ${leagueDisplayName(league)}\n'
          '${uiCopy(locale, 'preferredClub')}: ${preferredClub?.name ?? uiCopy(locale, 'anyEligibleClub')}\n\n'
          '${uiCopy(locale, alreadyApplied ? 'transferTrustAlreadyApplied' : 'transferTrustWarning')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            key: const Key('transfer-request-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(uiCopy(locale, 'fileTransferRequest').toUpperCase()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.pop(
      context,
      TransferRequestDraft(
        targetLeagueId: _targetLeagueId!,
        preferredClubId: _preferredClubId,
      ),
    );
  }

  Widget? _clearSearch(String locale) => _search.text.isEmpty
      ? null
      : IconButton(
          tooltip: _copy(locale, 'clearSearch'),
          onPressed: () => setState(_search.clear),
          icon: const Icon(Icons.close_rounded),
        );
}

String _copy(String locale, String key) =>
    _translations[key]?[locale] ?? _translations[key]!['en']!;

const _translations = <String, Map<String, String>>{
  'preferenceGuidance': {
    'en': 'Your preference guides your agent. A club must still be interested; a move is not guaranteed.',
    'es': 'Tu preferencia orienta a tu agente. El club debe estar interesado; el traspaso no está garantizado.',
    'pt-BR': 'Sua preferência orienta seu agente. O clube ainda precisa ter interesse; a transferência não é garantida.',
    'fr': 'Votre préférence guide votre agent. Le club doit être intéressé ; le transfert n’est pas garanti.',
  },
  'noLeagues': {
    'en': 'No leagues match your search.',
    'es': 'Ninguna liga coincide con tu búsqueda.',
    'pt-BR': 'Nenhuma liga corresponde à sua busca.',
    'fr': 'Aucun championnat ne correspond à votre recherche.',
  },
  'noClubs': {
    'en': 'No clubs match your search. Your current preference is kept.',
    'es': 'Ningún club coincide con tu búsqueda. Se conserva tu preferencia actual.',
    'pt-BR': 'Nenhum clube corresponde à sua busca. Sua preferência atual é mantida.',
    'fr': 'Aucun club ne correspond à votre recherche. Votre préférence actuelle est conservée.',
  },
  'clearSearch': {
    'en': 'Clear search',
    'es': 'Borrar búsqueda',
    'pt-BR': 'Limpar busca',
    'fr': 'Effacer la recherche',
  },
  'hideKeyboard': {
    'en': 'Hide keyboard',
    'es': 'Ocultar teclado',
    'pt-BR': 'Ocultar teclado',
    'fr': 'Masquer le clavier',
  },
};
