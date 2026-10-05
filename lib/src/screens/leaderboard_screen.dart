import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../services/api_models.dart';
import '../services/online_models.dart';
import '../online_copy.dart';
import '../theme.dart';
import '../ui_copy.dart';
import 'more_detail_screens.dart';

final class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

final class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late PositionFamily _position;
  late Difficulty _difficulty;
  late Future<LeaderboardPage> _entries;
  final Set<String> _hiddenProfileIds = {};
  String? _message;
  String? _accountId;
  static const _hiddenProfilesKey = 'leaderboard.hiddenProfiles.v1';

  @override
  void initState() {
    super.initState();
    final career = widget.controller.activeCareer;
    _position = career?.player.position ?? PositionFamily.striker;
    _difficulty = career?.difficulty ?? Difficulty.professional;
    _accountId = widget.controller.account?.id;
    _refresh();
    _loadHiddenProfiles();
    widget.controller.addListener(_accountChanged);
  }

  void _accountChanged() {
    final id = widget.controller.account?.id;
    if (mounted && id != _accountId) {
      setState(() {
        _accountId = id;
        _message = null;
        _refresh();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _loadHiddenProfiles() async {
    final stored = await widget.controller.store.getPreference(
      _hiddenProfilesKey,
    );
    if (!mounted || stored is! List) return;
    setState(() => _hiddenProfileIds.addAll(stored.whereType<String>()));
  }

  void _refresh() {
    if (widget.controller.account == null) {
      _entries = Future.value(
        const LeaderboardPage(entries: [], nearbyEntries: [], totalEntries: 0),
      );
      return;
    }
    _entries = widget.controller.sync.leaderboardPage(
      position: _position,
      difficulty: _difficulty,
      rulesVersion:
          widget.controller.activeCareer?.rulesVersion ??
          CareerSnapshot.currentRulesVersion,
      careerId: widget.controller.activeCareer?.careerId,
    );
  }

  Future<void> _openAccount() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountScreen(controller: widget.controller),
      ),
    );
    if (mounted) setState(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final account = widget.controller.account;
    return Scaffold(
      appBar: AppBar(title: Text(uiCopy(locale, 'leaderboards'))),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_refresh);
          try {
            await _entries;
          } on Object {
            // The FutureBuilder owns the visible retry/offline state.
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              '${uiCopy(locale, 'onlineLegacy')} · ${localizedPosition(locale, _position.name)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              uiCopy(locale, 'leaderboardNoPrizes'),
              style: TextStyle(color: ElevenwardColors.muted),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.visibility_outlined),
                    title: Text(uiCopy(locale, 'shareRetiredCareer')),
                    subtitle: Text(uiCopy(locale, 'leaderboardPrivacy')),
                    value: widget.controller.leaderboardOptIn,
                    onChanged: (value) async {
                      await widget.controller.changeLeaderboardOptIn(value);
                      if (mounted) setState(_refresh);
                    },
                  ),
                ],
              ),
            ),
            if (account == null) ...[
              const SizedBox(height: 12),
              _MessageCard(
                icon: Icons.lock_outline,
                text: uiCopy(locale, 'leaderboardSignIn'),
              ),
              TextButton(
                onPressed: _openAccount,
                child: Text(uiCopy(locale, 'account')),
              ),
            ] else ...[
              if (account.usernameStatus == 'unset') ...[
                Text(uiCopy(locale, 'generatedAliasShown')),
                TextButton(
                  onPressed: _openAccount,
                  child: Text(uiCopy(locale, 'claimLeaderboardName')),
                ),
              ] else if (account.usernameStatus == 'suspended')
                Text(uiCopy(locale, 'usernameSuspended')),
              const SizedBox(height: 16),
              DropdownButtonFormField<PositionFamily>(
                initialValue: _position,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: PositionFamily.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(localizedPosition(locale, value.name)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _position = value;
                    _refresh();
                  });
                },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<Difficulty>(
                  segments: Difficulty.values
                      .map(
                        (value) => ButtonSegment(
                          value: value,
                          label: Text(_difficultyLabel(context, value)),
                        ),
                      )
                      .toList(),
                  selected: {_difficulty},
                  showSelectedIcon: false,
                  onSelectionChanged: (values) {
                    setState(() {
                      _difficulty = values.single;
                      _refresh();
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<LeaderboardPage>(
                future: _entries,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _MessageCard(
                      icon: Icons.cloud_off_outlined,
                      text: uiCopy(locale, 'leaderboardOffline'),
                    );
                  }
                  final page = snapshot.data;
                  final entries = (page?.entries ?? const <LeaderboardEntry>[])
                      .where(
                        (entry) =>
                            entry.profileId == null ||
                            !_hiddenProfileIds.contains(entry.profileId),
                      )
                      .toList(growable: false);
                  if (entries.isEmpty) {
                    return _MessageCard(
                      icon: Icons.emoji_events_outlined,
                      text: uiCopy(locale, 'noLeaderboardEntries'),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        onlineCopy(locale, 'myRank'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (page?.myEntry case final own?)
                        _EntryTile(entry: own, onReport: null)
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(onlineCopy(locale, 'rankPending')),
                        ),
                      if (page != null && page.nearbyEntries.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          onlineCopy(locale, 'nearby'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final entry in page.nearbyEntries.where(
                          (entry) =>
                              entry.profileId == null ||
                              !_hiddenProfileIds.contains(entry.profileId),
                        ))
                          _EntryTile(
                            entry: entry,
                            onReport:
                                entry.reportable &&
                                    !entry.isCurrentUser &&
                                    entry.profileId != null
                                ? () => _report(entry)
                                : null,
                          ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        onlineCopy(locale, 'topPlayers'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ...entries.map(
                        (entry) => _EntryTile(
                          entry: entry,
                          onReport:
                              entry.reportable &&
                                  !entry.isCurrentUser &&
                                  entry.profileId != null
                              ? () => _report(entry)
                              : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: TextStyle(color: ElevenwardColors.amber)),
            ],
          ],
        ),
      ),
    );
  }

  String _difficultyLabel(BuildContext context, Difficulty value) =>
      switch (value) {
        Difficulty.story => context.l10n.story,
        Difficulty.professional => context.l10n.professional,
        Difficulty.worldClass => context.l10n.worldClass,
      };

  Future<void> _report(LeaderboardEntry entry) async {
    final profileId = entry.profileId;
    if (profileId == null) return;
    final locale = contentLocale(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(uiCopy(locale, 'reportAndHidePrompt')),
        content: Text(entry.alias),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          for (final (label, value) in [
            ('offensiveUsername', 'offensive_username'),
            ('impersonation', 'impersonation'),
            ('harassment', 'harassment'),
            ('otherReason', 'other'),
          ])
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: Text(uiCopy(locale, label)),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _hiddenProfileIds.add(profileId));
    try {
      await widget.controller.store.setPreference(
        _hiddenProfilesKey,
        _hiddenProfileIds.toList(growable: false),
      );
      await widget.controller.sync.reportLeaderboardUsername(
        profileId: profileId,
        reason: reason,
      );
      if (mounted) {
        setState(() => _message = uiCopy(locale, 'profileHiddenReportSent'));
      }
    } on Object {
      if (mounted) {
        setState(() => _message = uiCopy(locale, 'profileHiddenReportFailed'));
      }
    }
  }
}

final class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, this.onReport});

  final LeaderboardEntry entry;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;
    final score = entry.legacyScore;
    final locale = contentLocale(context);
    return Semantics(
      label:
          '${uiCopy(locale, 'rank')} $rank, ${entry.alias}, '
          '$score ${uiCopy(locale, 'points')}',
      child: Card(
        color: entry.isCurrentUser ? ElevenwardColors.panelLight : null,
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: rank <= 3
                    ? ElevenwardColors.amber
                    : ElevenwardColors.panelLight,
                foregroundColor: rank <= 3
                    ? ElevenwardColors.onAction
                    : ElevenwardColors.cream,
                child: Text('$rank'),
              ),
              title: Text(
                '${entry.alias}${entry.isCurrentUser ? ' · ${uiCopy(locale, 'leaderboardYou')}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${entry.seasons} ${uiCopy(locale, 'seasons')} · '
                '${entry.trophies} ${uiCopy(locale, 'trophies')}',
              ),
              trailing: Text(
                '$score',
                style: TextStyle(
                  color: ElevenwardColors.grass,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (onReport != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onReport,
                  child: Text(uiCopy(locale, 'reportAndHide')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: ElevenwardColors.panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ElevenwardColors.line),
    ),
    child: Column(
      children: [
        Icon(icon, color: ElevenwardColors.muted),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}
