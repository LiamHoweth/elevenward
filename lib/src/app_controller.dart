import 'dart:async';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import 'services/analytics_service.dart';
import 'services/api_models.dart';
import 'services/auth_service.dart';
import 'services/content_service.dart';
import 'services/entitlement_service.dart';
import 'services/review_prompt_service.dart';
import 'services/sync_service.dart';
import 'storage/career_store.dart';
import 'feature_copy.dart';
import 'ui_copy.dart';
import 'online_copy.dart';
import 'training_preset.dart';
import 'util/uuid.dart';

enum AppStage { booting, languageSelection, onboarding, careerSlots, playing }

enum SyncUiStatus { idle, running, complete, failed }

enum BackupState { deviceOnly, pending, backedUp, conflict, failed }

enum PurchaseUiOutcome { purchased, cancelled, failed, restored }

final class AppController extends ChangeNotifier {
  AppController({
    required this.store,
    required this.auth,
    required this.entitlements,
    required this.sync,
    required this.analytics,
    required this.content,
    this.reviewPrompts,
  });

  final CareerStore store;
  final AuthService auth;
  final EntitlementService entitlements;
  final SyncService sync;
  final AnalyticsService analytics;
  final ContentService content;
  final ReviewPromptService? reviewPrompts;

  AppStage stage = AppStage.booting;
  List<SavedCareerSlot> slots = const [];
  int? activeSlotIndex;
  CareerSnapshot? activeCareer;
  int activeCareerGeneration = 0;
  int archiveGeneration = 0;
  bool archiveBackupPending = false;
  bool _disposed = false;
  Future<void>? _archiveRefresh;
  int _archiveOperationGeneration = 0;
  Future<void> _archiveMutation = Future<void>.value();
  int _sessionGeneration = 0;
  String? _syncAccountId;
  int? _syncSessionGeneration;
  int _sharingPreferenceGeneration = 0;
  Future<void> _sharingMutation = Future<void>.value();
  ElevenwardAccount? account;
  EntitlementState entitlementState = const EntitlementState();
  ActiveContent? availableContent;
  ActiveContent? activeContent;
  Locale? locale;
  bool analyticsGranted = false;
  bool leaderboardOptIn = true;
  String themeId = 'graphite';
  ThemeMode displayMode = ThemeMode.dark;
  String avatarId = 'initials';
  String archiveLayoutId = 'timeline';
  String shareCardStyleId = 'classic';
  PlayerAttribute activeWeeklyFocus = PlayerAttribute.finishing;
  String? lastPlayedCareerId;
  bool quickTransitions = false;
  bool showCoachingTips = true;
  bool showCareerTarget = true;
  Set<String> dismissedCoachTips = {};
  TrainingPreset? _trainingPreset;
  Set<String> _favoriteClubIds = const {};
  Set<String> _favoriteLeagueIds = const {};
  Future<void> _polishPreferenceMutation = Future<void>.value();

  TrainingPreset? get trainingPreset => _trainingPreset;
  Set<String> get favoriteClubIds => _favoriteClubIds;
  Set<String> get favoriteLeagueIds => _favoriteLeagueIds;

  SavedCareerSlot? get resumeSlot {
    final playable = slots
        .where((slot) => slot.snapshot != null && !slot.isTombstone)
        .toList();
    final remembered = playable
        .where((slot) => slot.snapshot!.careerId == lastPlayedCareerId)
        .firstOrNull;
    if (remembered != null) return remembered;
    playable.sort(
      (a, b) => b.snapshot!.updatedAt.compareTo(a.snapshot!.updatedAt),
    );
    return playable.firstOrNull;
  }

  bool busy = false;
  GamePassId? processingPass;
  PurchaseUiOutcome? lastPurchaseOutcome;
  String? lastMessage;
  SyncUiStatus syncStatus = SyncUiStatus.idle;
  SyncProgressUpdate? syncProgress;
  SyncReport? lastSyncReport;
  DateTime? lastBackupAt;
  final Map<String, DateTime> _careerBackups = {};
  bool _onboardingCompleted = false;
  bool _forcePublicationRefresh = false;
  bool _sharingPreferencePending = false;
  bool _sharingMigrationComplete = false;
  String? _pendingSharingAccountId;
  Timer? _onlineSyncTimer;
  Future<void>? _syncInFlight;
  int _localSyncVersion = 0;
  Future<void> _careerMutation = Future<void>.value();
  Future<void>? _destructiveSlotMutation;

  Future<T> _serializeCareer<T>(Future<T> Function() action) {
    final next = _careerMutation.then((_) => action());
    _careerMutation = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<T> _mutateSlot<T>(Future<T> Function() action) {
    final previous = _destructiveSlotMutation;
    final existingSync = _syncInFlight;
    // Register the barrier synchronously. Wait outside the career queue because
    // an existing sync needs that queue to finish updating the active career.
    final next = Future<void>.value().then((_) async {
      if (previous != null) await previous;
      if (existingSync != null) {
        await existingSync.catchError((Object _) {});
      }
      return _serializeCareer(action);
    });
    final barrier = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _destructiveSlotMutation = barrier;
    unawaited(
      barrier.then((_) {
        if (identical(_destructiveSlotMutation, barrier)) {
          _destructiveSlotMutation = null;
        }
      }),
    );
    return next;
  }

  Future<bool> _slotHasPendingConflict(int slotIndex) async {
    final conflicts = await store.listConflicts();
    if (!conflicts.any((conflict) => conflict.slotIndex == slotIndex)) {
      return false;
    }
    lastMessage = featureCopy(_copyLocale, 'resolveConflictFirst');
    notifyListeners();
    return true;
  }

  Future<T> _serializeArchives<T>(Future<T> Function() action) {
    final next = _archiveMutation.then((_) => action());
    _archiveMutation = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<void> _serializeSharing(Future<void> Function() action) {
    final next = _sharingMutation.then((_) => action());
    _sharingMutation = next.catchError((Object _) {});
    return next;
  }

  Future<void> initialize() async {
    try {
      final localeValue = await store.getPreference('locale');
      if (localeValue is String && localeValue.isNotEmpty) {
        final parts = localeValue.split('-');
        locale = Locale(parts.first, parts.length > 1 ? parts[1] : null);
      }
      final savedTheme = await _stringPreference('cosmetic.theme', 'graphite');
      themeId = savedTheme == 'pitch' ? 'graphite' : savedTheme;
      displayMode = switch (await store.getPreference('ui.displayMode')) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
      avatarId = await _stringPreference('cosmetic.avatar', 'initials');
      archiveLayoutId = await _stringPreference(
        'cosmetic.archiveLayout',
        'timeline',
      );
      shareCardStyleId = await _stringPreference(
        'cosmetic.shareCard',
        'classic',
      );
      final rememberedCareer = await store.getPreference(
        'ui.lastPlayedCareerId',
      );
      lastPlayedCareerId = rememberedCareer is String ? rememberedCareer : null;
      quickTransitions =
          await store.getPreference('ui.quickTransitions') == true;
      showCoachingTips =
          await store.getPreference('ui.showCoachingTips') != false;
      showCareerTarget =
          await store.getPreference('ui.showCareerTarget') != false;
      final dismissed = await store.getPreference('ui.dismissedCoachTips');
      dismissedCoachTips = dismissed is List
          ? dismissed.whereType<String>().toSet()
          : {};
      availableContent = await content.load();
      activeContent = availableContent;
      try {
        entitlementState = await entitlements.initialize();
      } on Object {
        entitlementState = entitlements.state;
      }
      analyticsGranted = await analytics.isGranted();
      // Keep a previous explicit opt-out when the publication flow changes.
      leaderboardOptIn =
          await store.getPreference('leaderboard.optIn') != false;
      _forcePublicationRefresh =
          await store.getPreference('leaderboard.publicationSyncVersion') != 1;
      _sharingPreferencePending =
          await store.getPreference('leaderboard.sharingPending') == true;
      _sharingMigrationComplete =
          await store.getPreference('leaderboard.sharingMigrationComplete') ==
          true;
      _pendingSharingAccountId = await store.getPreference(
        'leaderboard.sharingPendingAccountId',
      ) as String?;
      unawaited(analytics.record('app_started'));
      await refreshSlots();
      _onboardingCompleted =
          await store.getPreference('onboarding.completed') == true;
      final languageSelected =
          await store.getPreference('language.selected') == true;
      stage = languageSelected
          ? (_onboardingCompleted ? AppStage.careerSlots : AppStage.onboarding)
          : AppStage.languageSelection;
      notifyListeners();
      unawaited(_restoreOnlineServices());
    } on Object {
      lastMessage = 'Your local data could not be opened.';
      stage = AppStage.careerSlots;
      notifyListeners();
    }
  }

  Future<void> _restoreOnlineServices() async {
    final session = _sessionGeneration;
    final restored = await auth.restoreSession();
    if (_disposed || _sessionGeneration != session) return;
    account = restored;
    if (account != null) {
      await _adoptAccountSharing();
      await analytics.replayConsent();
      await analytics.flush();
      try {
        entitlementState = await entitlements.login(account!.id);
      } on Object {
        entitlementState = entitlements.state;
      }
      _scheduleOnlineSync();
    }
    notifyListeners();
    try {
      final update = await content.checkForUpdate();
      if (update != null) {
        availableContent = update;
        if (stage != AppStage.playing) activeContent = update;
        notifyListeners();
      }
    } on Object {
      // A bundled, validated launch catalog always remains available offline.
    }
  }

  Future<void> refreshSlots() async {
    slots = await store.listSlots();
    await _serializePolishPreferences(_loadPolishPreferences);
    final accountId = account?.id;
    archiveBackupPending =
        accountId != null &&
        (await store.pendingArchives(accountId)).isNotEmpty;
    _careerBackups.clear();
    if (accountId != null) {
      for (final slot in slots) {
        final careerId = slot.snapshot?.careerId;
        if (careerId == null) continue;
        final value = await store.getPreference('backup.$accountId.$careerId');
        if (value is String) {
          final stamp = DateTime.tryParse(value)?.toUtc();
          if (stamp != null) _careerBackups[careerId] = stamp;
        }
      }
      final value = await store.getPreference('backup.$accountId.lastSuccess');
      lastBackupAt = value is String ? DateTime.tryParse(value)?.toUtc() : null;
    } else {
      lastBackupAt = null;
    }
    notifyListeners();
  }

  // Reading shares the write queue so a refresh cannot publish stale values
  // over a completed save or lose rapid successive favorite toggles.
  Future<void> _serializePolishPreferences(Future<void> Function() action) {
    final next = _polishPreferenceMutation.then((_) => action());
    _polishPreferenceMutation = next.catchError((Object _) {});
    return next;
  }

  Future<Object?> _readPolishPreference(String key) async {
    try {
      return await store.getPreference(key);
    } on FormatException {
      return null;
    }
  }

  Set<String> _favoriteIdsFromPreference(Object? value) =>
      Set<String>.unmodifiable(
        value is List
            ? value.whereType<String>().where((id) => id.trim().isNotEmpty)
            : const <String>[],
      );

  Future<void> _loadPolishPreferences() async {
    _trainingPreset = TrainingPreset.fromJson(
      await _readPolishPreference('ui.trainingPreset'),
    );
    _favoriteClubIds = _favoriteIdsFromPreference(
      await _readPolishPreference('ui.favoriteClubIds'),
    );
    _favoriteLeagueIds = _favoriteIdsFromPreference(
      await _readPolishPreference('ui.favoriteLeagueIds'),
    );
  }

  Future<void> saveTrainingPreset(TrainingPreset preset) =>
      _serializePolishPreferences(() async {
        await store.setPreference('ui.trainingPreset', preset.toJson());
        _trainingPreset = preset;
        notifyListeners();
      });

  Future<void> clearTrainingPreset() => _serializePolishPreferences(() async {
    await store.setPreference('ui.trainingPreset', null);
    _trainingPreset = null;
    notifyListeners();
  });

  Future<void> toggleFavoriteClub(String id) =>
      _toggleFavorite(id, clubs: true);

  Future<void> toggleFavoriteLeague(String id) =>
      _toggleFavorite(id, clubs: false);

  Future<void> _toggleFavorite(String id, {required bool clubs}) {
    if (id.trim().isEmpty) {
      return Future<void>.error(ArgumentError.value(id, 'id'));
    }
    return _serializePolishPreferences(() async {
      final updated = Set<String>.from(
        clubs ? _favoriteClubIds : _favoriteLeagueIds,
      );
      if (!updated.remove(id)) updated.add(id);
      final sortedIds = updated.toList()..sort();
      await store.setPreference(
        clubs ? 'ui.favoriteClubIds' : 'ui.favoriteLeagueIds',
        sortedIds,
      );
      if (clubs) {
        _favoriteClubIds = Set<String>.unmodifiable(updated);
      } else {
        _favoriteLeagueIds = Set<String>.unmodifiable(updated);
      }
      notifyListeners();
    });
  }

  BackupState backupStateFor(SavedCareerSlot slot) {
    if (account == null) return BackupState.deviceOnly;
    if (slot.syncState == SlotSyncState.conflict) return BackupState.conflict;
    if (slot.syncState == SlotSyncState.synced &&
        _careerBackups.containsKey(slot.snapshot?.careerId)) {
      return BackupState.backedUp;
    }
    return syncStatus == SyncUiStatus.failed
        ? BackupState.failed
        : BackupState.pending;
  }

  DateTime? lastBackupAtFor(SavedCareerSlot slot) =>
      _careerBackups[slot.snapshot?.careerId];

  /// Resume retries pending durable work without advancing the career.
  void resumed() {
    if (account != null && !busy) _queueOnlineSync();
    unawaited(analytics.flush());
  }

  Future<void> completeOnboarding() async {
    await store.setPreference('onboarding.completed', true);
    _onboardingCompleted = true;
    stage = AppStage.careerSlots;
    notifyListeners();
  }

  /// Records the explicit first-launch language choice before onboarding.
  Future<void> selectInitialLanguage(Locale value) async {
    locale = value;
    await store.setPreference(
      'locale',
      [value.languageCode, value.countryCode].whereType<String>().join('-'),
    );
    await store.setPreference('language.selected', true);
    stage = _onboardingCompleted ? AppStage.careerSlots : AppStage.onboarding;
    notifyListeners();
  }

  Future<void> openSlot(int index) => _serializeCareer(() async {
    try {
      final snapshot = await store.loadSlot(index);
      if (snapshot == null) return;
      final pinnedContent = await content.loadVersion(snapshot.contentVersion);
      if (pinnedContent == null) {
        lastMessage =
            'This career needs content ${snapshot.contentVersion}, which is not available on this device.';
        notifyListeners();
        return;
      }
      activeSlotIndex = index;
      activeCareer = snapshot;
      activeCareerGeneration += 1;
      activeWeeklyFocus = await _loadWeeklyFocus(snapshot.careerId);
      activeContent = pinnedContent;
      lastMessage = store.consumeRecoveryNotice();
      await _rememberCareer(snapshot.careerId);
      stage = AppStage.playing;
      notifyListeners();
    } on FormatException {
      lastMessage = 'This career and its recovery journal are unreadable. Other slots are safe; contact support with the slot number.';
      notifyListeners();
    }
  });

  Future<void> createCareer({
    required int slotIndex,
    required String firstName,
    required String lastName,
    required Archetype archetype,
    required String nationalTeamId,
    required String portraitId,
    required ClubDefinition club,
    required Difficulty difficulty,
  }) => _mutateSlot(() async {
    if (await _slotHasPendingConflict(slotIndex)) return;
    final saved = (await store.listSlots()).firstWhere(
      (slot) => slot.slotIndex == slotIndex,
    );
    if (saved.isOccupied) {
      lastMessage = featureCopy(_copyLocale, 'slotOccupied');
      notifyListeners();
      return;
    }
    final normalizedFirstName = _normalizeNamePart(firstName);
    final normalizedLastName = _normalizeNamePart(lastName);
    if (normalizedFirstName.isEmpty || normalizedLastName.isEmpty) {
      throw ArgumentError('Both first name and last name are required.');
    }
    final selectedContent = availableContent ?? activeContent;
    final careerId = generateUuidV4();
    final snapshot = CareerSnapshot.newCareer(
      careerId: careerId,
      seed: uuidSeed(careerId),
      updatedAt: DateTime.now().toUtc(),
      clubId: club.id,
      clubName: club.name,
      contentVersion:
          selectedContent?.version ?? buildLaunchWorld().contentVersion,
      difficulty: difficulty,
      worldDefinition: selectedContent?.catalog.world ?? buildLaunchWorld(),
      player: PlayerState.newCareer(
        id: generateUuidV4(),
        name: '$normalizedFirstName $normalizedLastName',
        archetype: archetype,
        nationalTeamId: nationalTeamId,
        portraitId: portraitId,
      ),
    );
    final startingFocus = recommendedTrainingFocus(archetype);
    await store.saveWeeklyFocus(careerId, startingFocus);
    await store.saveSlot(slotIndex, snapshot, eventType: 'career_started');
    await _rememberCareer(careerId);
    await refreshSlots();
    activeSlotIndex = slotIndex;
    activeCareer = snapshot;
    activeCareerGeneration += 1;
    activeWeeklyFocus = startingFocus;
    activeContent = selectedContent;
    stage = AppStage.playing;
    notifyListeners();
    _scheduleOnlineSync();
    unawaited(
      analytics.record(
        'career_started',
        properties: {
          'position': archetype.positionFamily.name,
          'difficulty': difficulty.name,
        },
      ),
    );
  });

  static String _normalizeNamePart(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> saveCareer(
    CareerSnapshot snapshot, {
    String eventType = 'snapshot_saved',
    int? expectedGeneration,
    String? expectedCareerId,
    int? expectedRevision,
  }) => _serializeCareer(() async {
    if (expectedGeneration != null &&
        expectedGeneration != activeCareerGeneration) {
      throw StateError(
        'The active career was replaced before this choice saved.',
      );
    }
    if ((expectedCareerId != null &&
            activeCareer?.careerId != expectedCareerId) ||
        (expectedRevision != null &&
            activeCareer?.revision != expectedRevision)) {
      throw StateError('The active career changed before this choice saved.');
    }
    await _saveCareer(snapshot, eventType: eventType);
  });

  Future<void> _saveCareer(
    CareerSnapshot snapshot, {
    required String eventType,
  }) async {
    final slot = activeSlotIndex;
    if (slot == null) throw StateError('No active career slot.');
    final previous = activeCareer;
    await store.saveSlot(slot, snapshot, eventType: eventType);
    await refreshSlots();
    // Publish the new career only once its durable slot list has also been
    // refreshed. This keeps UI listeners from observing a partly saved state.
    activeCareer = snapshot;
    notifyListeners();
    _scheduleOnlineSync();
    final position = snapshot.player.position.name;
    final difficulty = snapshot.difficulty.name;
    if (eventType == 'week_completed') {
      final pointsDelta = snapshot.points - (previous?.points ?? 0);
      unawaited(
        analytics.record(
          'week_completed',
          properties: {
            'position': position,
            'difficulty': difficulty,
            'season': snapshot.season,
            'week': snapshot.week,
            'result': pointsDelta >= 3
                ? 'win'
                : pointsDelta == 1
                ? 'draw'
                : 'loss',
          },
        ),
      );
    } else if (eventType == 'offseason_completed') {
      final completed = snapshot.seasonHistory.lastOrNull;
      final placement = completed == null
          ? 0
          : previous?.world
                    .table(previous.world.leagueIdForClub(previous.clubId))
                    .indexWhere((row) => row.clubId == previous.clubId) ??
                -1;
      unawaited(
        analytics.record(
          'season_completed',
          properties: {
            'position': position,
            'difficulty': difficulty,
            'season': completed?.season ?? snapshot.season - 1,
            'placement': placement + 1,
          },
        ),
      );
    } else if (eventType == 'career_retired') {
      unawaited(
        analytics.record(
          'career_retired',
          properties: {
            'position': position,
            'difficulty': difficulty,
            'seasons': snapshot.seasonHistory.length,
            'legacyScore': snapshot.legacyScore,
          },
        ),
      );
    }
  }

  Future<void> requestReviewAfterSeason(
    CareerSnapshot snapshot, {
    bool Function()? isEligible,
  }) async {
    await reviewPrompts?.requestAfterSeason(snapshot, isEligible: isEligible);
  }

  Future<void> chooseCareerGoal(CareerGoalKind kind, {int? target}) async {
    final current = activeCareer;
    if (current == null) throw StateError('No active career.');
    final next = const CareerEngine().chooseCareerGoal(
      snapshot: current,
      kind: kind,
      target: target,
      updatedAt: DateTime.now().toUtc(),
    );
    await saveCareer(
      next,
      eventType: 'goal_chosen',
      expectedGeneration: activeCareerGeneration,
      expectedCareerId: current.careerId,
      expectedRevision: current.revision,
    );
  }

  Future<void> acceptOffseasonLoan(LoanOffer offer) async {
    final current = activeCareer;
    if (current == null) throw StateError('No active career.');
    final next = const CareerEngine().completeOffseason(
      current,
      acceptedLoan: offer,
      updatedAt: DateTime.now().toUtc(),
      definition: activeContent?.catalog.world,
    );
    await saveCareer(
      next,
      eventType: 'offseason_completed',
      expectedGeneration: activeCareerGeneration,
      expectedCareerId: current.careerId,
      expectedRevision: current.revision,
    );
  }

  /// Device archives never wait for a network request.
  Future<List<CareerSnapshot>> localHallOfFame() => store.listArchives();

  Future<void> refreshHallOfFame() {
    final pending = _archiveRefresh;
    if (pending != null) return pending;
    final work = _importArchives();
    _archiveRefresh = work;
    return work.whenComplete(() {
      if (identical(_archiveRefresh, work)) _archiveRefresh = null;
    });
  }

  Future<void> _importArchives() async {
    final accountId = account?.id;
    final operation = _archiveOperationGeneration;
    final session = _sessionGeneration;
    if (accountId == null || _disposed) return;
    try {
      final archives = await sync.archives(
        isCurrentSession: () =>
            !_disposed &&
            account?.id == accountId &&
            _sessionGeneration == session,
      );
      if (_disposed ||
          account?.id != accountId ||
          _sessionGeneration != session ||
          _archiveOperationGeneration != operation) {
        return;
      }
      await _serializeArchives(() async {
        if (_archiveOperationGeneration != operation ||
            _sessionGeneration != session ||
            account?.id != accountId) {
          return;
        }
        final existing = {
          for (final career in await store.listArchives())
            career.careerId: career.encode(),
        };
        var changed = false;
        for (final snapshot in archives) {
          if (_disposed ||
              account?.id != accountId ||
              _sessionGeneration != session ||
              _archiveOperationGeneration != operation) {
            return;
          }
          final owner = await store.archiveOwner(snapshot.careerId);
          if (owner != null && owner != accountId) continue;
          if (existing[snapshot.careerId] == snapshot.encode()) continue;
          await store.saveArchive(
            snapshot,
            accountId: accountId,
            cloudSynced: true,
          );
          changed = true;
        }
        if (changed) {
          archiveGeneration += 1;
          notifyListeners();
        }
      });
    } on Object {
      // A failed refresh leaves all cached archives available.
    }
  }

  Future<void> archiveCareer(CareerSnapshot snapshot) =>
      _serializeArchives(() async {
        _archiveOperationGeneration += 1;
        final accountId = account?.id;
        await store.saveArchive(snapshot, accountId: accountId);
        archiveGeneration += 1;
        archiveBackupPending = accountId != null;
        lastMessage = accountId == null
            ? null
            : onlineCopy(_copyLocale, 'archivePending');
        notifyListeners();
        _scheduleOnlineSync();
      });

  Future<void> deleteArchivedCareer(String careerId) =>
      _serializeArchives(() async {
        _archiveOperationGeneration += 1;
        final owner = await store.archiveOwner(careerId);
        final accountId = account?.id;
        final session = _sessionGeneration;
        if (owner != null && owner == accountId) {
          await sync.deleteArchive(
            careerId,
            isCurrentSession: () =>
                !_disposed &&
                session == _sessionGeneration &&
                account?.id == accountId,
          );
          if (_sessionGeneration != session || account?.id != accountId) {
            throw StateError('Account changed.');
          }
        }
        await store.deleteArchive(careerId);
        archiveGeneration += 1;
        notifyListeners();
      });

  Future<void> deleteSlot(
    int index, {
    String? expectedCareerId,
    int? expectedRevision,
  }) => _mutateSlot(() async {
    if (await _slotHasPendingConflict(index)) return;
    final currentSlot = (await store.listSlots()).firstWhere(
      (slot) => slot.slotIndex == index,
    );
    final current = currentSlot.snapshot ?? currentSlot.tombstoneSnapshot;
    if ((expectedCareerId != null && current?.careerId != expectedCareerId) ||
        (expectedRevision != null &&
            currentSlot.localRevision != expectedRevision)) {
      lastMessage = featureCopy(_copyLocale, 'careerChangedBeforeDeletion');
      notifyListeners();
      return;
    }
    final careerId = activeSlotIndex == index
        ? activeCareer?.careerId
        : slots
              .where((slot) => slot.slotIndex == index)
              .firstOrNull
              ?.snapshot
              ?.careerId;
    await store.deleteSlot(index, DateTime.now().toUtc());
    if (careerId != null) {
      try {
        await store.removeWeeklyFocus(careerId);
      } on Object {
        lastMessage = uiCopy(_copyLocale, 'focusClearFailed');
      }
    }
    if (activeSlotIndex == index) {
      activeSlotIndex = null;
      activeCareer = null;
      activeWeeklyFocus = PlayerAttribute.finishing;
      activeContent = availableContent;
      stage = AppStage.careerSlots;
    }
    await refreshSlots();
    _scheduleOnlineSync();
  });

  void showCareerSlots() {
    activeCareerGeneration += 1;
    activeSlotIndex = null;
    activeCareer = null;
    activeWeeklyFocus = PlayerAttribute.finishing;
    activeContent = availableContent;
    stage = AppStage.careerSlots;
    notifyListeners();
  }

  Future<void> changeLocale(Locale? value) async {
    locale = value;
    await store.setPreference(
      'locale',
      value == null
          ? ''
          : [
              value.languageCode,
              value.countryCode,
            ].whereType<String>().join('-'),
    );
    notifyListeners();
  }

  Future<void> _rememberCareer(String careerId) async {
    lastPlayedCareerId = careerId;
    try {
      await store.setPreference('ui.lastPlayedCareerId', careerId);
    } on Object {
      // A failed convenience preference must never prevent opening a save.
    }
  }

  Future<void> changeGameplayPreference(String key, bool value) async {
    final previous = switch (key) {
      'quickTransitions' => quickTransitions,
      'showCoachingTips' => showCoachingTips,
      'showCareerTarget' => showCareerTarget,
      _ => throw ArgumentError.value(key),
    };
    void apply(bool next) {
      switch (key) {
        case 'quickTransitions':
          quickTransitions = next;
        case 'showCoachingTips':
          showCoachingTips = next;
        case 'showCareerTarget':
          showCareerTarget = next;
      }
    }

    apply(value);
    notifyListeners();
    try {
      await store.setPreference('ui.$key', value);
    } on Object {
      apply(previous);
      lastMessage = uiCopy(_copyLocale, 'cosmeticSaveFailed');
      notifyListeners();
    }
  }

  Future<void> dismissCoachTip(String id) async {
    final previous = Set<String>.from(dismissedCoachTips);
    dismissedCoachTips = {...dismissedCoachTips, id};
    notifyListeners();
    try {
      await store.setPreference(
        'ui.dismissedCoachTips',
        dismissedCoachTips.toList(),
      );
    } on Object {
      dismissedCoachTips = previous;
      notifyListeners();
    }
  }

  Future<void> changeAnalyticsConsent(bool value) async {
    analyticsGranted = value;
    notifyListeners();
    await analytics.setConsent(value);
  }

  Future<void> changeLeaderboardOptIn(bool value) {
    _sharingPreferenceGeneration += 1;
    final accountId = account?.id;
    leaderboardOptIn = value;
    _sharingPreferencePending = true;
    _pendingSharingAccountId = accountId;
    _forcePublicationRefresh = true;
    notifyListeners();
    return _serializeSharing(() async {
      await store.setPreference('leaderboard.optIn', value);
      await store.setPreference('leaderboard.sharingPending', true);
      await store.setPreference(
        'leaderboard.sharingPendingAccountId',
        accountId,
      );
      _scheduleOnlineSync();
    });
  }

  Future<void> changeWeeklyFocus(PlayerAttribute value) {
    final career = activeCareer;
    if (career == null) return Future<void>.value();
    final generation = activeCareerGeneration;
    return _serializeCareer(() async {
      if (generation != activeCareerGeneration ||
          activeCareer?.careerId != career.careerId) {
        throw StateError('The active career changed before the focus saved.');
      }
      try {
        await store.saveWeeklyFocus(career.careerId, value);
        if (generation != activeCareerGeneration ||
            activeCareer?.careerId != career.careerId) {
          return;
        }
        activeWeeklyFocus = value;
        notifyListeners();
      } on Object {
        if (generation == activeCareerGeneration &&
            activeCareer?.careerId == career.careerId) {
          lastMessage = uiCopy(_copyLocale, 'focusSaveFailed');
          notifyListeners();
        }
        rethrow;
      }
    });
  }

  Future<void> fileTransferRequest({
    required String targetLeagueId,
    String? preferredClubId,
    int? expectedGeneration,
  }) async {
    final generation = expectedGeneration ?? activeCareerGeneration;
    if (generation != activeCareerGeneration) {
      throw StateError('The active career changed.');
    }
    final career = activeCareer;
    if (career == null) return;
    final next = const CareerEngine().fileTransferRequest(
      snapshot: career,
      targetLeagueId: targetLeagueId,
      preferredClubId: preferredClubId,
      updatedAt: DateTime.now().toUtc(),
      definition: activeContent?.catalog.world,
    );
    await saveCareer(
      next,
      eventType: 'transfer_requested',
      expectedGeneration: generation,
      expectedCareerId: career.careerId,
      expectedRevision: career.revision,
    );
  }

  Future<void> cancelTransferRequest({int? expectedGeneration}) async {
    final generation = expectedGeneration ?? activeCareerGeneration;
    if (generation != activeCareerGeneration) {
      throw StateError('The active career changed.');
    }
    final career = activeCareer;
    if (career?.transferRequest == null) return;
    final next = const CareerEngine().cancelTransferRequest(
      snapshot: career!,
      updatedAt: DateTime.now().toUtc(),
    );
    await saveCareer(
      next,
      eventType: 'transfer_request_cancelled',
      expectedGeneration: generation,
      expectedCareerId: career.careerId,
      expectedRevision: career.revision,
    );
  }

  Future<bool> updatePublicUsername(String username) async {
    if (busy || account == null) return false;
    busy = true;
    lastMessage = null;
    notifyListeners();
    try {
      account = await sync.updatePublicUsername(username);
      await auth.updateCurrentAccount(account!);
      return true;
    } on ApiFailure catch (error) {
      lastMessage = error.message;
      return false;
    } on Object {
      lastMessage = uiCopy(_copyLocale, 'leaderboardOffline');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String> _stringPreference(String key, String fallback) async {
    final value = await store.getPreference(key);
    return value is String && value.isNotEmpty ? value : fallback;
  }

  Future<void> changeDisplayMode(ThemeMode value) async {
    final previous = displayMode;
    displayMode = value;
    lastMessage = null;
    notifyListeners();
    try {
      await store.setPreference('ui.displayMode', value.name);
    } on Object {
      displayMode = previous;
      lastMessage = uiCopy(_copyLocale, 'cosmeticSaveFailed');
      notifyListeners();
    }
  }

  Future<PlayerAttribute> _loadWeeklyFocus(String careerId) async {
    try {
      return await store.loadWeeklyFocus(careerId);
    } on Object {
      lastMessage = uiCopy(_copyLocale, 'focusLoadFailed');
      return PlayerAttribute.finishing;
    }
  }

  Future<void> setCosmeticPreference(String key, String value) async {
    const freeValues = {'graphite', 'initials', 'timeline', 'classic'};
    if (key == 'theme' && value == 'pitch') value = 'graphite';
    if (!entitlementState.premiumCosmetics && !freeValues.contains(value)) {
      lastMessage = uiCopy(_copyLocale, 'premiumCosmeticRequired');
      notifyListeners();
      return;
    }
    final previous = switch (key) {
      'theme' => themeId,
      'avatar' => avatarId,
      'archiveLayout' => archiveLayoutId,
      'shareCard' => shareCardStyleId,
      _ => throw ArgumentError.value(key, 'key'),
    };
    void apply(String selected) {
      switch (key) {
        case 'theme':
          themeId = selected;
        case 'avatar':
          avatarId = selected;
        case 'archiveLayout':
          archiveLayoutId = selected;
        case 'shareCard':
          shareCardStyleId = selected;
      }
    }

    apply(value);
    lastMessage = null;
    notifyListeners();
    try {
      await store.setPreference('cosmetic.$key', value);
    } on Object {
      apply(previous);
      lastMessage = uiCopy(_copyLocale, 'cosmeticSaveFailed');
      notifyListeners();
    }
  }

  Future<void> signInApple() => _runOnline(() async {
    _sessionGeneration += 1;
    account = await auth.signInWithApple();
    await _adoptAccountSharing();
    await analytics.replayConsent();
    await analytics.flush();
    entitlementState = await entitlements.login(account!.id);
    await _synchronize();
  });

  Future<void> signInGoogle() => _runOnline(() async {
    _sessionGeneration += 1;
    account = await auth.signInWithGoogle();
    await _adoptAccountSharing();
    await analytics.replayConsent();
    await analytics.flush();
    entitlementState = await entitlements.login(account!.id);
    await _synchronize();
  });

  Future<void> signOut() => _runOnline(() async {
    _sessionGeneration += 1;
    _onlineSyncTimer?.cancel();
    try {
      await auth.signOut();
    } finally {
      account = auth.currentAccount;
    }
    await entitlements.logout();
    await refreshSlots();
  });

  Future<void> deleteAccount() => _runOnline(() async {
    _sessionGeneration += 1;
    _onlineSyncTimer?.cancel();
    var cleanupComplete = await auth.deleteAccount();
    account = null;
    await refreshSlots();
    try {
      entitlementState = await entitlements.logout();
    } on Object {
      cleanupComplete = false;
    }
    lastMessage = cleanupComplete
        ? 'Your account and cloud data were deleted. Local careers remain on this device.'
        : 'Your account and cloud data were deleted. Local careers remain. Restart the app to retry local account/store cleanup.';
  });

  Future<Map<String, Object?>?> requestDeletionChallenge() async {
    if (busy || account == null) return null;
    busy = true;
    lastMessage = null;
    notifyListeners();
    try {
      return await auth.createDeletionChallenge();
    } on Object {
      lastMessage = 'The deletion code could not be created. Try again.';
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> synchronize() => _runOnline(_synchronize);

  Future<void> resolveConflict(
    PreservedConflict conflict, {
    required bool keepLocal,
  }) => _runOnline(
    () => _serializeCareer(() async {
      final remoteId = conflict.remoteConflictId;
      if (remoteId == null) {
        throw StateError('This conflict cannot be resolved remotely.');
      }
      final session = _sessionGeneration;
      final accountId = account?.id;
      final currentSlot = (await store.listSlots()).firstWhere(
        (s) => s.slotIndex == conflict.slotIndex,
      );
      final current = currentSlot.snapshot ?? currentSlot.tombstoneSnapshot;
      if (current?.careerId != conflict.careerId ||
          (keepLocal && currentSlot.isTombstone != conflict.localDeleted)) {
        throw StateError(
          'This slot changed. Refresh cloud conflicts before choosing.',
        );
      }
      await sync.resolve(
        localConflictId: conflict.id,
        slotIndex: conflict.slotIndex,
        remoteConflictId: remoteId,
        keepLocal: keepLocal,
        expectedCareerId: current!.careerId,
        expectedLocalRevision: currentSlot.localRevision,
        publishLeaderboard: leaderboardOptIn,
        localSnapshot: keepLocal && !conflict.localDeleted ? current : null,
        expectedRemoteRevision: conflict.remoteRevision,
        isCurrentSession: () =>
            !_disposed &&
            session == _sessionGeneration &&
            account?.id == accountId,
      );
      await refreshSlots();
      if (activeSlotIndex == conflict.slotIndex) {
        final resolved = await store.loadSlot(conflict.slotIndex);
        if (resolved == null) {
          activeCareerGeneration += 1;
          activeSlotIndex = null;
          activeCareer = null;
          activeWeeklyFocus = PlayerAttribute.finishing;
          activeContent = availableContent;
          stage = AppStage.careerSlots;
        } else {
          final pinned = await content.loadVersion(resolved.contentVersion);
          if (pinned == null) {
            activeSlotIndex = null;
            activeCareer = null;
            activeWeeklyFocus = PlayerAttribute.finishing;
            activeContent = availableContent;
            stage = AppStage.careerSlots;
            lastMessage =
                'The resolved career needs content ${resolved.contentVersion}, which is not available on this device.';
            return;
          }
          activeCareer = resolved;
          activeCareerGeneration += 1;
          activeWeeklyFocus = await _loadWeeklyFocus(resolved.careerId);
          activeContent = pinned;
        }
      }
      lastMessage ??= 'Cloud conflict resolved.';
    }),
  );

  void _scheduleOnlineSync() {
    if (account == null) return;
    _localSyncVersion += 1;
    _queueOnlineSync();
  }

  Future<void> _adoptAccountSharing() async {
    final signedIn = account;
    if (signedIn == null) return;
    if (_sharingPreferencePending &&
        _pendingSharingAccountId != null &&
        _pendingSharingAccountId != signedIn.id) {
      _sharingPreferencePending = false;
      _pendingSharingAccountId = null;
      await store.setPreference('leaderboard.sharingPending', false);
      await store.setPreference('leaderboard.sharingPendingAccountId', null);
    }
    final storedChoice = await store.getPreference('leaderboard.optIn');
    if (!_sharingPreferencePending &&
        !_sharingMigrationComplete &&
        storedChoice == false &&
        signedIn.leaderboardSharingEnabled) {
      // Older builds stored opt-out only on this device. Transfer it to the
      // account before any career is uploaded from this device.
      _sharingPreferencePending = true;
      _pendingSharingAccountId = signedIn.id;
      await store.setPreference('leaderboard.sharingPending', true);
      await store.setPreference(
        'leaderboard.sharingPendingAccountId',
        signedIn.id,
      );
    }
    _sharingMigrationComplete = true;
    await store.setPreference('leaderboard.sharingMigrationComplete', true);
    if (!_sharingPreferencePending) {
      leaderboardOptIn = signedIn.leaderboardSharingEnabled;
      await store.setPreference('leaderboard.optIn', leaderboardOptIn);
    }
    notifyListeners();
  }

  Future<void> _flushSharingPreference() async {
    if (!_sharingPreferencePending || account == null) return;
    final session = _sessionGeneration;
    final accountId = account?.id;
    final preference = _sharingPreferenceGeneration;
    final requested = leaderboardOptIn;
    final updated = await sync.updateLeaderboardSharing(
      requested,
      isCurrentSession: () =>
          !_disposed &&
          session == _sessionGeneration &&
          account?.id == accountId,
    );
    if (session != _sessionGeneration || account?.id != accountId) {
      throw StateError('Account changed.');
    }
    account = updated;
    await auth.updateCurrentAccount(account!);
    await _serializeSharing(() async {
      if (preference != _sharingPreferenceGeneration ||
          leaderboardOptIn != requested ||
          session != _sessionGeneration ||
          account?.id != accountId) {
        _scheduleOnlineSync();
        return;
      }
      await store.setPreference('leaderboard.sharingPending', false);
      await store.setPreference('leaderboard.sharingPendingAccountId', null);
      if (preference == _sharingPreferenceGeneration) {
        _sharingPreferencePending = false;
        _pendingSharingAccountId = null;
      }
    });
    notifyListeners();
  }

  void _queueOnlineSync() {
    if (_disposed) return;
    _onlineSyncTimer?.cancel();
    _onlineSyncTimer = Timer(const Duration(milliseconds: 800), () async {
      if (account == null) return;
      if (busy) {
        _queueOnlineSync();
        return;
      }
      try {
        await _synchronize(silent: true);
      } on Object {
        // The saved career stays local and the next change or manual retry
        // will attempt cloud sync again.
      }
    });
  }

  Future<void> _synchronize({bool silent = false}) {
    final pending = _syncInFlight;
    if (pending != null) {
      if (_syncAccountId == account?.id &&
          _syncSessionGeneration == _sessionGeneration) {
        return pending;
      }
      return pending
          .catchError((Object _) {})
          .then((_) => _synchronize(silent: silent));
    }
    final mutation = _destructiveSlotMutation;
    if (mutation != null) {
      return mutation.then((_) => _synchronize(silent: silent));
    }
    _syncAccountId = account?.id;
    _syncSessionGeneration = _sessionGeneration;
    final work = _performSynchronize(silent: silent);
    _syncInFlight = work;
    return work.whenComplete(() {
      if (identical(_syncInFlight, work)) _syncInFlight = null;
    });
  }

  Future<void> _performSynchronize({required bool silent}) async {
    final syncVersion = _localSyncVersion;
    final accountId = account?.id;
    final session = _sessionGeneration;
    bool currentSession() =>
        !_disposed && account?.id == accountId && session == _sessionGeneration;
    if (accountId == null) return;
    syncStatus = SyncUiStatus.running;
    syncProgress = const SyncProgressUpdate(
      phase: SyncProgressPhase.loading,
      completed: 0,
      total: 0,
    );
    notifyListeners();
    try {
      await store.adoptCloudAccount(
        accountId,
        isCurrentSession: currentSession,
      );
      if (!currentSession()) return;
      await _flushSharingPreference();
      if (!currentSession()) return;
      final report = await sync.synchronize(
        publishLeaderboard: leaderboardOptIn,
        forcePublicationRefresh: _forcePublicationRefresh,
        isCurrentSession: currentSession,
        onProgress: (progress) {
          if (currentSession()) {
            syncProgress = progress;
            notifyListeners();
          }
        },
      );
      if (!currentSession()) return;
      lastSyncReport = report;
      syncStatus = SyncUiStatus.complete;
      final now = DateTime.now().toUtc();
      final savedSlots = await store.listSlots();
      for (final slot in savedSlots) {
        if (slot.syncState == SlotSyncState.synced && slot.snapshot != null) {
          await store.setPreference(
            'backup.$accountId.${slot.snapshot!.careerId}',
            now.toIso8601String(),
          );
        }
      }
      if (report.conflicts == 0) {
        await store.setPreference(
          'backup.$accountId.lastSuccess',
          now.toIso8601String(),
        );
      }
      await _serializeArchives(() async {
        for (final archive in await store.pendingArchives(accountId)) {
          if (!currentSession()) return;
          await sync.archive(archive, isCurrentSession: currentSession);
          if (!currentSession()) return;
          await store.markArchiveSynced(archive.careerId, accountId);
        }
      });
      if (!currentSession()) return;
      if (report.conflicts == 0) {
        _forcePublicationRefresh = false;
        await store.setPreference('leaderboard.publicationSyncVersion', 1);
      }
      await refreshSlots();
      await _serializeCareer(() async {
        if (_disposed || account?.id != accountId) return;
        final index = activeSlotIndex;
        if (index == null) return;
        final remote = await store.loadSlot(index);
        if (remote != null && activeCareer?.encode() != remote.encode()) {
          final pinned = await content.loadVersion(remote.contentVersion);
          if (pinned != null && !_disposed && activeSlotIndex == index) {
            activeCareer = remote;
            activeContent = pinned;
            activeWeeklyFocus = await _loadWeeklyFocus(remote.careerId);
            activeCareerGeneration += 1;
            notifyListeners();
          }
        }
      });
      if (!silent || report.conflicts > 0) {
        lastMessage = report.conflicts > 0
            ? '${report.conflicts} cloud conflict(s) need your choice.'
            : 'Cloud sync complete: ${report.uploaded} uploaded, ${report.downloaded} downloaded.';
      }
    } on Object {
      if (!currentSession()) return;
      syncStatus = SyncUiStatus.failed;
      rethrow;
    } finally {
      if (account != null && _localSyncVersion != syncVersion) {
        _queueOnlineSync();
      }
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _onlineSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> purchase(GamePassId id) async {
    if (busy) return;
    busy = true;
    processingPass = id;
    lastPurchaseOutcome = null;
    lastMessage = null;
    notifyListeners();
    try {
      entitlementState = await entitlements.purchase(id);
      await refreshSlots();
      lastPurchaseOutcome = PurchaseUiOutcome.purchased;
    } on PurchaseCancelledException {
      lastPurchaseOutcome = PurchaseUiOutcome.cancelled;
    } on Object {
      lastPurchaseOutcome = PurchaseUiOutcome.failed;
    } finally {
      busy = false;
      processingPass = null;
      notifyListeners();
    }
  }

  Future<void> refreshStoreCatalog() async {
    if (busy) return;
    busy = true;
    lastMessage = null;
    final refresh = entitlements.refreshCatalog();
    notifyListeners();
    try {
      await refresh;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (busy) return;
    busy = true;
    lastPurchaseOutcome = null;
    lastMessage = null;
    notifyListeners();
    try {
      entitlementState = await entitlements.restore();
      await refreshSlots();
      lastPurchaseOutcome = PurchaseUiOutcome.restored;
    } on Object {
      lastPurchaseOutcome = PurchaseUiOutcome.failed;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _runOnline(Future<void> Function() operation) async {
    if (busy) return;
    busy = true;
    lastMessage = null;
    notifyListeners();
    try {
      await operation();
    } on Object {
      lastMessage = 'The online request failed. Your local career is safe.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String get _copyLocale =>
      locale?.languageCode == 'pt' ? 'pt-BR' : locale?.languageCode ?? 'en';
}
