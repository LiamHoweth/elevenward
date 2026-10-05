import 'package:flutter/material.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../online_copy.dart';
import '../services/online_models.dart';
import '../ui_copy.dart';
import 'more_detail_screens.dart';

final class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

final class _FriendsScreenState extends State<FriendsScreen> {
  Future<FriendsState>? _state;
  final _code = TextEditingController();
  String? _accountId;
  String? _inviteCode;
  DateTime? _expiresAt;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _accountId = widget.controller.account?.id;
    _reload();
    widget.controller.addListener(_accountChanged);
  }

  void _accountChanged() {
    final id = widget.controller.account?.id;
    if (id != _accountId && mounted) {
      setState(() {
        _accountId = id;
        _inviteCode = null;
        _reload();
      });
    }
  }

  void _reload() {
    _state = _accountId == null ? null : widget.controller.sync.friends();
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    final id = _accountId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted && _accountId == id) setState(_reload);
    } on Object {
      if (mounted) setState(() => _error = 'failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(
    String actionKey,
    Future<void> Function() action,
  ) async {
    final locale = contentLocale(context);
    final accountId = _accountId;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(onlineCopy(locale, actionKey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(onlineCopy(locale, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(onlineCopy(locale, 'confirm')),
          ),
        ],
      ),
    );
    if (result == true && mounted && accountId == _accountId) await _action(action);
  }

  String _ownComparison(String locale, FriendCareer friendCareer) {
    final current = widget.controller.activeCareer;
    if (current == null ||
        current.player.position.name != friendCareer.position ||
        current.rulesVersion != friendCareer.rulesVersion) {
      return '';
    }
    final difficulty = switch (current.difficulty) {
      Difficulty.story => 'story',
      Difficulty.professional => 'balanced',
      Difficulty.worldClass => 'elite',
    };
    if (difficulty != friendCareer.difficulty) return '';
    return '\n${onlineCopy(locale, 'yourCareer')}: '
        '${calculateLegacyVerdict(current).score} ${uiCopy(locale, 'legacy')} · '
        '${current.seasonHistory.fold<int>(0, (sum, season) => sum + season.trophies.length)} ${uiCopy(locale, 'trophies')} · '
        '${current.seasonHistory.length} ${uiCopy(locale, 'seasons')}';
  }

  @override
  void dispose() {
    widget.controller.removeListener(_accountChanged);
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Scaffold(
      appBar: AppBar(title: Text(onlineCopy(locale, 'friends'))),
      body: _accountId == null
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(onlineCopy(locale, 'signInBody')),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AccountScreen(controller: widget.controller),
                    ),
                  ),
                  child: Text(onlineCopy(locale, 'signIn')),
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: () async {
                setState(_reload);
                try {
                  await _state;
                } on Object {
                  /* builder owns errors */
                }
              },
              child: FutureBuilder<FriendsState>(
                future: _state,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const ListBodyWithLoading();
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(onlineCopy(locale, 'failed')),
                        TextButton(
                          onPressed: () => setState(_reload),
                          child: Text(onlineCopy(locale, 'retry')),
                        ),
                      ],
                    );
                  }
                  final state = snapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(onlineCopy(locale, 'friendsBody')),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(onlineCopy(locale, 'friendConsent')),
                        value: state.comparisonSharingEnabled,
                        onChanged: _busy
                            ? null
                            : (value) => _action(
                                () => widget.controller.sync.setFriendSharing(
                                  value,
                                ),
                              ),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _action(() async {
                                final id = _accountId;
                                final response = await widget.controller.sync
                                    .createFriendCode();
                                if (mounted && _accountId == id) {
                                  setState(() {
                                    _inviteCode =
                                        response['inviteCode'] as String;
                                    _expiresAt = DateTime.parse(
                                      response['expiresAt'] as String,
                                    ).toLocal();
                                  });
                                }
                              }),
                        child: Text(onlineCopy(locale, 'invite')),
                      ),
                      if (_inviteCode != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                SelectableText(
                                  _inviteCode!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                if (_expiresAt != null)
                                  Text(
                                    '${onlineCopy(locale, 'ends')}: ${MaterialLocalizations.of(context).formatShortDate(_expiresAt!)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_expiresAt!))}',
                                  ),
                                TextButton(
                                  onPressed: () => Clipboard.setData(
                                    ClipboardData(text: _inviteCode!),
                                  ),
                                  child: Text(onlineCopy(locale, 'copy')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      TextField(
                        controller: _code,
                        enabled: !_busy,
                        maxLength: 8,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: onlineCopy(locale, 'inviteCode'),
                        ),
                      ),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _action(() async {
                                await widget.controller.sync.requestFriend(
                                  _code.text.trim().toUpperCase(),
                                );
                                _code.clear();
                              }),
                        child: Text(onlineCopy(locale, 'requestFriend')),
                      ),
                      if (_error != null)
                        Semantics(
                          liveRegion: true,
                          child: Text(onlineCopy(locale, _error!)),
                        ),
                      if (state.incoming.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          onlineCopy(locale, 'incoming'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final request in state.incoming)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(request.alias),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _action(
                                                () => widget.controller.sync
                                                    .respondFriend(
                                                      request.requestId,
                                                      true,
                                                    ),
                                              ),
                                        child: Text(
                                          onlineCopy(locale, 'accept'),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _action(
                                                () => widget.controller.sync
                                                    .respondFriend(
                                                      request.requestId,
                                                      false,
                                                    ),
                                              ),
                                        child: Text(
                                          onlineCopy(locale, 'decline'),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _confirm(
                                                'block',
                                                () => widget.controller.sync
                                                    .blockFriend(
                                                      request.profileId,
                                                    ),
                                              ),
                                        child: Text(
                                          onlineCopy(locale, 'block'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      if (state.outgoing.isNotEmpty) ...[
                        Text(
                          onlineCopy(locale, 'outgoing'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final request in state.outgoing)
                          ListTile(title: Text(request.alias)),
                      ],
                      const SizedBox(height: 20),
                      if (state.friends.isEmpty)
                        Text(onlineCopy(locale, 'noFriends')),
                      for (final friend in state.friends)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        friend.alias,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      enabled: !_busy,
                                      onSelected: (key) => _confirm(
                                        key,
                                        () => key == 'block'
                                            ? widget.controller.sync
                                                  .blockFriend(friend.profileId)
                                            : widget.controller.sync
                                                  .removeFriend(
                                                    friend.profileId,
                                                  ),
                                      ),
                                      itemBuilder: (_) => ['remove', 'block']
                                          .map(
                                            (key) => PopupMenuItem(
                                              value: key,
                                              child: Text(
                                                onlineCopy(locale, key),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                                if (!friend.comparisonAvailable)
                                  Text(onlineCopy(locale, 'comparisonPrivate')),
                                for (final career in friend.careers)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      '${localizedPosition(locale, career.position)} · ${_difficultyLabel(context, career.difficulty)}\n${career.legacyScore} ${uiCopy(locale, 'legacy')} · ${career.trophies} ${uiCopy(locale, 'trophies')} · ${career.seasons} ${uiCopy(locale, 'seasons')}${_ownComparison(locale, career)}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (state.blocked.isNotEmpty) ...[
                        Text(
                          onlineCopy(locale, 'blocked'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final id in state.blocked)
                          ListTile(
                            title: Text(
                              '${onlineCopy(locale, 'blocked')} ${state.blocked.indexOf(id) + 1}',
                            ),
                            trailing: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action(
                                      () => widget.controller.sync
                                          .unblockFriend(id),
                                    ),
                              child: Text(onlineCopy(locale, 'unblock')),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
    );
  }
}

final class ListBodyWithLoading extends StatelessWidget {
  const ListBodyWithLoading({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: const [
      Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
    ],
  );
}

String _difficultyLabel(BuildContext context, String value) => switch (value) {
  'story' => context.l10n.story,
  'balanced' || 'professional' => context.l10n.professional,
  'elite' || 'worldClass' => context.l10n.worldClass,
  _ => value,
};
