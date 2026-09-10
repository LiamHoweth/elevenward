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
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    _step == 0
                        ? uiCopy(locale, 'chooseTargetLeague')
                        : uiCopy(locale, 'choosePreferredClub'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                if (_step == 1) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _step = 0;
                        _search.clear();
                      }),
                      child: Text(
                        MaterialLocalizations.of(context).backButtonTooltip,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    key: Key(
                      _step == 0
                          ? 'transfer-request-continue'
                          : 'transfer-request-submit',
                    ),
                    onPressed: _targetLeagueId == null
                        ? null
                        : _step == 0
                        ? () => setState(() {
                            _step = 1;
                            _search.clear();
                          })
                        : () => _confirmAndSubmit(locale),
                    child: Text(
                      _step == 0
                          ? uiCopy(locale, 'continue').toUpperCase()
                          : uiCopy(locale, 'fileTransferRequest').toUpperCase(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        TextField(
          key: const Key('transfer-league-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: uiCopy(locale, 'searchLeagues'),
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
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
        BroadcastPanel(
          accent: ElevenwardColors.grass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uiCopy(locale, 'targetLeague').toUpperCase(),
                style: const TextStyle(
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
          decoration: InputDecoration(
            labelText: uiCopy(locale, 'searchClubs'),
            prefixIcon: const Icon(Icons.search_rounded),
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
}
