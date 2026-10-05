import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../feature_copy.dart';
import '../online_copy.dart';
import '../services/online_models.dart';
import '../ui_copy.dart';
import 'more_detail_screens.dart';

final class WeeklyChallengeScreen extends StatefulWidget {
  const WeeklyChallengeScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<WeeklyChallengeScreen> createState() => _WeeklyChallengeScreenState();
}

String _challengeCopy(String locale, String key) =>
    _challengeTranslations[key]?[locale] ??
    _challengeTranslations[key]?['en'] ??
    key;

const _challengeTranslations = <String, Map<String, String>>{
  'howItWorks': {
    'en': 'How this challenge works',
    'es': 'Cómo funciona el desafío',
    'pt-BR': 'Como o desafio funciona',
    'fr': 'Comment fonctionne ce défi',
  },
  'localScore': {
    'en': 'Provisional score',
    'es': 'Puntuación provisional',
    'pt-BR': 'Pontuação provisória',
    'fr': 'Score provisoire',
  },
  'verification': {
    'en': 'Calculated from your saved matches. The server verifies your score when you submit.',
    'es': 'Calculada a partir de tus partidos guardados. El servidor verifica la puntuación cuando la envías.',
    'pt-BR': 'Calculada a partir das partidas salvas. O servidor verifica a pontuação quando você envia.',
    'fr': 'Calculé à partir de vos matchs enregistrés. Le serveur vérifie votre score lors de l’envoi.',
  },
  'lastMatch': {
    'en': 'Last match',
    'es': 'Último partido',
    'pt-BR': 'Última partida',
    'fr': 'Dernier match',
  },
  'matchPlan': {
    'en': 'Next match plan',
    'es': 'Plan para el próximo partido',
    'pt-BR': 'Plano para a próxima partida',
    'fr': 'Plan du prochain match',
  },
  'readyToSubmit': {
    'en': 'All eight matches are saved. Submit before the challenge closes to enter the standings.',
    'es': 'Los ocho partidos están guardados. Envía los resultados antes de que termine el desafío para entrar en la clasificación.',
    'pt-BR': 'As oito partidas estão salvas. Envie antes do fim do desafio para entrar no ranking.',
    'fr': 'Les huit matchs sont enregistrés. Envoyez vos résultats avant la fin du défi pour rejoindre le classement.',
  },
};

final class _WeeklyChallengeScreenState extends State<WeeklyChallengeScreen> {
  Future<ChallengeState>? _state;
  String? _accountId;
  ChallengeAttempt? _attempt;
  List<WeeklyChoice> _choices = [];
  PlayerAttribute _focus = PlayerAttribute.finishing;
  TrainingIntensity _load = TrainingIntensity.balanced;
  SpotlightApproach _approach = SpotlightApproach.balanced;
  bool _busy = false;
  int _loadGeneration = 0;
  int _choiceGeneration = 0;
  String? _messageKey;

  @override
  void initState() {
    super.initState();
    _accountId = widget.controller.account?.id;
    _reload();
    widget.controller.addListener(_accountChanged);
  }

  void _accountChanged() {
    final id = widget.controller.account?.id;
    if (mounted && id != _accountId) {
      setState(() {
        _accountId = id;
        _attempt = null;
        _choices = [];
        _restorePlan(const []);
        _messageKey = null;
        _reload();
      });
    }
  }

  String _key(String accountId, String attemptId) =>
      'challenge.$accountId.$attemptId';

  void _restorePlan(List<WeeklyChoice> choices) {
    final last = choices.lastOrNull;
    _focus = last?.focus ?? PlayerAttribute.finishing;
    _load = last?.intensity ?? TrainingIntensity.balanced;
    _approach = last?.spotlightApproach ?? SpotlightApproach.balanced;
  }

  void _restoreAttempt(ChallengeAttempt? attempt, List<WeeklyChoice> choices) {
    // Refreshing standings must not discard a plan the player is still editing.
    if (_attempt?.id != attempt?.id) _restorePlan(choices);
    _attempt = attempt;
    _choices = choices;
  }

  void _reload() {
    _loadGeneration += 1;
    _state = _accountId == null ? null : _loadState(_accountId!);
  }

  Future<ChallengeState> _loadState(String accountId) async {
    final load = _loadGeneration;
    final choice = _choiceGeneration;
    final state = await widget.controller.sync.currentChallenge();
    final attempt = state.attempt;
    final stored = attempt == null
        ? null
        : await widget.controller.store.getPreference(
            _key(accountId, attempt.id),
          );
    final choices =
        stored is Map &&
            stored['rulesVersion'] == state.challenge.rulesVersion &&
            stored['contentVersion'] == state.challenge.contentVersion
        ? (stored['actions'] as List? ?? [])
              .map((raw) => WeeklyChoice.fromJson(onlineObject(raw)))
              .toList()
        : <WeeklyChoice>[];
    if (choices.length > WeeklyChallenge.matchCount) {
      throw const FormatException('Invalid saved challenge.');
    }
    if (mounted &&
        _accountId == accountId &&
        load == _loadGeneration &&
        choice == _choiceGeneration) {
      _restoreAttempt(attempt, choices);
    }
    return state;
  }

  WeeklyChallengeReplay _replay(
    ChallengeAttempt attempt,
    List<WeeklyChoice> choices,
  ) => const WeeklyChallenge().replay(
    seed: attempt.seed,
    careerId: attempt.careerId,
    updatedAt: attempt.enrolledAt,
    choices: choices,
  );

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _choiceGeneration += 1;
      _messageKey = null;
    });
    try {
      await action();
    } on Object {
      if (mounted) setState(() => _messageKey = 'failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(ApiChallenge challenge) => _action(() async {
    final accountId = _accountId;
    final attempt = await widget.controller.sync.enrollChallenge(challenge.id);
    if (!mounted || accountId == null || accountId != _accountId) return;
    final stored = await widget.controller.store.getPreference(
      _key(accountId, attempt.id),
    );
    final choices =
        stored is Map &&
            stored['rulesVersion'] == challenge.rulesVersion &&
            stored['contentVersion'] == challenge.contentVersion
        ? (stored['actions'] as List? ?? [])
              .map((raw) => WeeklyChoice.fromJson(onlineObject(raw)))
              .toList()
        : <WeeklyChoice>[];
    if (choices.length > WeeklyChallenge.matchCount) {
      throw const FormatException('Invalid saved challenge.');
    }
    if (mounted && accountId == _accountId) {
      setState(() {
        _restoreAttempt(attempt, choices);
      });
    }
  });

  Future<void> _play(ApiChallenge challenge) => _action(() async {
    final attempt = _attempt;
    final accountId = _accountId;
    if (attempt == null ||
        accountId == null ||
        _choices.length >= challenge.matchCount) {
      return;
    }
    final next = [
      ..._choices,
      WeeklyChoice(
        focus: _focus,
        intensity: _load,
        spotlightApproach: _approach,
      ),
    ];
    _replay(attempt, next); // Validate before durable commitment.
    await widget.controller.store.setPreference(_key(accountId, attempt.id), {
      'rulesVersion': challenge.rulesVersion,
      'contentVersion': challenge.contentVersion,
      'actions': next.map((choice) => choice.toJson()).toList(),
    });
    if (mounted && accountId == _accountId) {
      setState(() {
        _choices = next;
        _messageKey = 'challengeSaved';
      });
    }
  });

  Future<void> _submit(ApiChallenge challenge) => _action(() async {
    final attempt = _attempt;
    final accountId = _accountId;
    if (attempt == null || !_replay(attempt, _choices).complete) return;
    await widget.controller.sync.submitChallenge(
      challenge.id,
      attempt.id,
      _choices.map((choice) => choice.toJson()).toList(),
    );
    if (mounted && accountId == _accountId) {
      setState(() {
        _messageKey = 'challengeSubmitted';
        _reload();
      });
    }
  });

  @override
  void dispose() {
    widget.controller.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Scaffold(
      key: const Key('weekly-challenge-screen'),
      appBar: AppBar(title: Text(onlineCopy(locale, 'challenge'))),
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
                if (_busy) return;
                setState(_reload);
                try {
                  await _state;
                } on Object {
                  /* builder owns error */
                }
              },
              child: FutureBuilder<ChallengeState>(
                future: _state,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    );
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
                  final challenge = state.challenge;
                  final compatible =
                      challenge.rulesVersion == WeeklyChallenge.rulesVersion &&
                      challenge.contentVersion ==
                          WeeklyChallenge.contentVersion &&
                      challenge.matchCount == WeeklyChallenge.matchCount;
                  final closed = !DateTime.now().toUtc().isBefore(
                    challenge.endsAt,
                  );
                  final attempt = _attempt;
                  final submitted = attempt?.status == 'submitted';
                  final replay = compatible && attempt != null
                      ? _replay(attempt, _choices)
                      : null;
                  final end = challenge.endsAt.toLocal();
                  final last = replay?.results.lastOrNull;
                  final opponent = replay == null || replay.complete
                      ? null
                      : const WorldSimulator().opponentFor(replay.snapshot);
                  final training = replay == null || replay.complete
                      ? null
                      : const WeeklySimulator().previewTraining(
                          snapshot: replay.snapshot,
                          focus: _focus,
                          intensity: _load,
                        );

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        onlineCopy(locale, 'challengeTitle'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      if (attempt == null) ...[
                        Text(onlineCopy(locale, 'challengeBody')),
                        const SizedBox(height: 12),
                        Text(onlineCopy(locale, 'challengeRules')),
                      ] else
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(_challengeCopy(locale, 'howItWorks')),
                          children: [
                            Text(onlineCopy(locale, 'challengeBody')),
                            const SizedBox(height: 12),
                            Text(onlineCopy(locale, 'challengeRules')),
                            const SizedBox(height: 12),
                          ],
                        ),
                      Text(
                        '${onlineCopy(locale, 'ends')}: ${MaterialLocalizations.of(context).formatShortDate(end)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(end))}',
                      ),
                      if (!compatible)
                        Text(onlineCopy(locale, 'challengeIncompatible')),
                      if (closed) Text(onlineCopy(locale, 'challengeExpired')),
                      if (_messageKey != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(onlineCopy(locale, _messageKey!)),
                          ),
                        ),
                      if (attempt == null && compatible && !closed)
                        FilledButton(
                          key: const Key('challenge-start'),
                          onPressed: _busy ? null : () => _start(challenge),
                          child: Text(onlineCopy(locale, 'startChallenge')),
                        ),
                      if (submitted)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '${onlineCopy(locale, 'challengeSubmitted')}\n${onlineCopy(locale, 'score')}: ${attempt?.score ?? 0}',
                            ),
                          ),
                        ),
                      if (replay != null && !submitted) ...[
                        const SizedBox(height: 20),
                        Text(
                          '${onlineCopy(locale, 'matches')}: ${replay.matchesPlayed} / ${challenge.matchCount}',
                        ),
                        LinearProgressIndicator(
                          value: replay.matchesPlayed / challenge.matchCount,
                          semanticsLabel:
                              '${onlineCopy(locale, 'matches')}: ${replay.matchesPlayed} / ${challenge.matchCount}',
                        ),
                        const SizedBox(height: 12),
                        Card(
                          key: const Key('challenge-local-score'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_challengeCopy(locale, 'localScore')}: ${replay.score}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${replay.snapshot.points} ${uiCopy(locale, 'points')} · '
                                  '${replay.snapshot.player.goals} ${uiCopy(locale, 'goals')} · '
                                  '${replay.snapshot.player.assists} ${uiCopy(locale, 'assists')}',
                                ),
                                const SizedBox(height: 8),
                                Text(_challengeCopy(locale, 'verification')),
                              ],
                            ),
                          ),
                        ),
                        if (last != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _challengeCopy(locale, 'lastMatch'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${last.opponent.isHome ? last.snapshot.clubName : last.opponent.clubName} '
                                    '${last.homeScore} – ${last.awayScore} '
                                    '${last.opponent.isHome ? last.opponent.clubName : last.snapshot.clubName}',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    last.selection.status !=
                                            SelectionStatus.omitted
                                        ? '${uiCopy(locale, 'matchRating')}: ${last.deltas.rating.toStringAsFixed(1)}'
                                        : featureCopy(locale, 'didNotAppear'),
                                  ),
                                  Text(
                                    '${last.deltas.goals} ${uiCopy(locale, 'goals')} · ${last.deltas.assists} ${uiCopy(locale, 'assists')}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!replay.complete && !closed) ...[
                          const SizedBox(height: 16),
                          Text(
                            '${_challengeCopy(locale, 'matchPlan')} · ${replay.matchesPlayed + 1} / ${challenge.matchCount}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          if (opponent != null)
                            Text(
                              '${replay.snapshot.clubName} · ${opponent.clubName}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          if (training != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                '${uiCopy(locale, 'trainingPreview')}: '
                                '${localizedPlayerAttribute(locale, _focus)} ${training.attributeBefore} → ${training.attributeAfter}\n'
                                '${uiCopy(locale, 'fitness')} ${training.fitnessBefore} → ${training.fitnessAfter}',
                              ),
                            ),
                          DropdownButtonFormField<PlayerAttribute>(
                            key: ValueKey('challenge-focus-${attempt!.id}'),
                            initialValue: _focus,
                            itemHeight: null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: onlineCopy(locale, 'focus'),
                            ),
                            items: PlayerAttribute.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      localizedPlayerAttribute(locale, value),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _focus = value!),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<TrainingIntensity>(
                            key: ValueKey('challenge-load-${attempt.id}'),
                            initialValue: _load,
                            itemHeight: null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: onlineCopy(locale, 'load'),
                            ),
                            items: TrainingIntensity.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(switch (value) {
                                      TrainingIntensity.light => onlineCopy(
                                        locale,
                                        'trainingLight',
                                      ),
                                      TrainingIntensity.balanced => uiCopy(
                                        locale,
                                        'balanced',
                                      ),
                                      TrainingIntensity.intensive => onlineCopy(
                                        locale,
                                        'trainingIntensive',
                                      ),
                                    }),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _load = value!),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<SpotlightApproach>(
                            key: ValueKey('challenge-approach-${attempt.id}'),
                            initialValue: _approach,
                            itemHeight: null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: onlineCopy(locale, 'approach'),
                            ),
                            items: SpotlightApproach.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(switch (value) {
                                      SpotlightApproach.safe => uiCopy(
                                        locale,
                                        'lowRisk',
                                      ),
                                      SpotlightApproach.balanced => uiCopy(
                                        locale,
                                        'balanced',
                                      ),
                                      SpotlightApproach.bold => uiCopy(
                                        locale,
                                        'highRisk',
                                      ),
                                    }),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _approach = value!),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            key: const Key('challenge-next'),
                            onPressed: _busy ? null : () => _play(challenge),
                            child: Text(onlineCopy(locale, 'playMatch')),
                          ),
                        ],
                        if (replay.complete && !closed) ...[
                          const SizedBox(height: 16),
                          Text(_challengeCopy(locale, 'readyToSubmit')),
                          const SizedBox(height: 12),
                          FilledButton(
                            key: const Key('challenge-submit'),
                            onPressed: _busy ? null : () => _submit(challenge),
                            child: Text(onlineCopy(locale, 'submitChallenge')),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      Text(
                        onlineCopy(locale, 'topPlayers'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (state.entries.isEmpty)
                        Text(onlineCopy(locale, 'noEntries')),
                      for (final entry in state.entries)
                        ListTile(
                          leading: Text('${entry.rank}'),
                          title: Text(entry.alias),
                          trailing: Text('${entry.score}'),
                          selected: entry.isCurrentUser,
                        ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
