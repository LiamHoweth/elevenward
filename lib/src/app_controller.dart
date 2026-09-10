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
import 'ui_copy.dart';
import 'util/uuid.dart';

enum AppStage { booting, languageSelection, onboarding, careerSlots, playing }

enum SyncUiStatus { idle, running, complete, failed }

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
  ElevenwardAccount? account;
  EntitlementState entitlementState = const EntitlementState();
  ActiveContent? availableContent;
  ActiveContent? activeContent;
  Locale? locale;
  bool analyticsGranted = false;
  bool leaderboardOptIn = false;
  String themeId = 'pitch';
  String avatarId = 'initials';
  String archiveLayoutId = 'timeline';
  String shareCardStyleId = 'classic';
  PlayerAttribute activeWeeklyFocus = PlayerAttribute.finishing;
  bool busy = false;
  GamePassId? processingPass;
  PurchaseUiOutcome? lastPurchaseOutcome;
  String? lastMessage;
  SyncUiStatus syncStatus = SyncUiStatus.idle;
  SyncProgressUpdate? syncProgress;
  SyncReport? lastSyncReport;
  bool _onboardingCompleted = false;

  Future<void> initialize() async {
    try {
      final localeValue = await store.getPreference('locale');
      if (localeValue is String && localeValue.isNotEmpty) {
        final parts = localeValue.split('-');
        locale = Locale(parts.first, parts.length > 1 ? parts[1] : null);
      }
      themeId = await _stringPreference('cosmetic.theme', 'pitch');
      avatarId = await _stringPreference('cosmetic.avatar', 'initials');
      archiveLayoutId = await _stringPreference(
        'cosmetic.archiveLayout',
        'timeline',
      );
      shareCardStyleId = await _stringPreference(
        'cosmetic.shareCard',
        'classic',
      );
      availableContent = await content.load();
      activeContent = availableContent;
      try {
        entitlementState = await entitlements.initialize();
      } on Object {
        entitlementState = entitlements.state;
      }
      analyticsGranted = await analytics.isGranted();
      leaderboardOptIn = await store.getPreference('leaderboard.optIn') == true;
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
    account = await auth.restoreSession();
    if (account != null) {
      await analytics.replayConsent();
      await analytics.flush();
      try {
        entitlementState = await entitlements.login(account!.id);
      } on Object {
        entitlementState = entitlements.state;
      }
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
    notifyListeners();
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

  Future<void> openSlot(int index) async {
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
      activeWeeklyFocus = await _loadWeeklyFocus(snapshot.careerId);
      activeContent = pinnedContent;
      lastMessage = store.consumeRecoveryNotice();
      stage = AppStage.playing;
      notifyListeners();
    } on FormatException {
      lastMessage = 'This career and its recovery journal are unreadable. Other slots are safe; contact support with the slot number.';
      notifyListeners();
    }
  }

  Future<void> createCareer({
    required int slotIndex,
    required String firstName,
    required String lastName,
    required Archetype archetype,
    required String nationalTeamId,
    required ClubDefinition club,
    required Difficulty difficulty,
  }) async {
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
      ),
    );
    await store.saveSlot(slotIndex, snapshot, eventType: 'career_started');
    await refreshSlots();
    activeSlotIndex = slotIndex;
    activeCareer = snapshot;
    activeWeeklyFocus = PlayerAttribute.finishing;
    activeContent = selectedContent;
    stage = AppStage.playing;
    notifyListeners();
    unawaited(
      analytics.record(
        'career_started',
        properties: {
          'position': archetype.positionFamily.name,
          'difficulty': difficulty.name,
        },
      ),
    );
  }

  static String _normalizeNamePart(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> saveCareer(
    CareerSnapshot snapshot, {
    String eventType = 'snapshot_saved',
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
      if (account != null && leaderboardOptIn) {
        unawaited(_runOnline(() => sync.submitLeaderboard(snapshot)));
      }
    }
  }

  Future<void> requestReviewAfterSeason(CareerSnapshot snapshot) async {
    await reviewPrompts?.requestAfterSeason(snapshot);
  }

  Future<void> deleteSlot(int index) async {
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
  }

  void showCareerSlots() {
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

  Future<void> changeAnalyticsConsent(bool value) async {
    analyticsGranted = value;
    notifyListeners();
    await analytics.setConsent(value);
  }

  Future<void> changeLeaderboardOptIn(bool value) async {
    leaderboardOptIn = value;
    await store.setPreference('leaderboard.optIn', value);
    notifyListeners();
  }

  Future<void> changeWeeklyFocus(PlayerAttribute value) async {
    final career = activeCareer;
    if (career == null) return;
    activeWeeklyFocus = value;
    notifyListeners();
    try {
      await store.saveWeeklyFocus(career.careerId, value);
    } on Object {
      lastMessage = uiCopy(_copyLocale, 'focusSaveFailed');
      notifyListeners();
    }
  }

  Future<void> fileTransferRequest({
    required String targetLeagueId,
    String? preferredClubId,
  }) async {
    final career = activeCareer;
    if (career == null) return;
    final next = const CareerEngine().fileTransferRequest(
      snapshot: career,
      targetLeagueId: targetLeagueId,
      preferredClubId: preferredClubId,
      updatedAt: DateTime.now().toUtc(),
      definition: activeContent?.catalog.world,
    );
    await saveCareer(next, eventType: 'transfer_requested');
  }

  Future<void> cancelTransferRequest() async {
    final career = activeCareer;
    if (career?.transferRequest == null) return;
    final next = const CareerEngine().cancelTransferRequest(
      snapshot: career!,
      updatedAt: DateTime.now().toUtc(),
    );
    await saveCareer(next, eventType: 'transfer_request_cancelled');
  }

  Future<void> submitActiveCareerLeaderboard() => _runOnline(() async {
    final career = activeCareer;
    if (career == null || !career.retired) {
      throw StateError('Only completed careers can be submitted.');
    }
    if (!leaderboardOptIn) {
      throw StateError('Leaderboard sharing is not enabled.');
    }
    await sync.submitLeaderboard(career);
    lastMessage = 'Your generated alias is now on the leaderboard.';
  });

  Future<String> _stringPreference(String key, String fallback) async {
    final value = await store.getPreference(key);
    return value is String && value.isNotEmpty ? value : fallback;
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
    const freeValues = {'pitch', 'initials', 'timeline', 'classic'};
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
    account = await auth.signInWithApple();
    await analytics.replayConsent();
    await analytics.flush();
    entitlementState = await entitlements.login(account!.id);
    await _synchronize();
  });

  Future<void> signInGoogle() => _runOnline(() async {
    account = await auth.signInWithGoogle();
    await analytics.replayConsent();
    await analytics.flush();
    entitlementState = await entitlements.login(account!.id);
    await _synchronize();
  });

  Future<void> signOut() => _runOnline(() async {
    try {
      await auth.signOut();
    } finally {
      account = auth.currentAccount;
    }
    await entitlements.logout();
  });

  Future<void> deleteAccount() => _runOnline(() async {
    var cleanupComplete = await auth.deleteAccount();
    account = null;
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
  }) => _runOnline(() async {
    final remoteId = conflict.remoteConflictId;
    if (remoteId == null) {
      throw StateError('This conflict cannot be resolved remotely.');
    }
    await sync.resolve(
      localConflictId: conflict.id,
      slotIndex: conflict.slotIndex,
      remoteConflictId: remoteId,
      keepLocal: keepLocal,
    );
    await refreshSlots();
    if (activeSlotIndex == conflict.slotIndex) {
      final resolved = await store.loadSlot(conflict.slotIndex);
      if (resolved == null) {
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
        activeWeeklyFocus = await _loadWeeklyFocus(resolved.careerId);
        activeContent = pinned;
      }
    }
    lastMessage ??= 'Cloud conflict resolved.';
  });

  Future<void> _synchronize() async {
    syncStatus = SyncUiStatus.running;
    syncProgress = const SyncProgressUpdate(
      phase: SyncProgressPhase.loading,
      completed: 0,
      total: 0,
    );
    notifyListeners();
    try {
      final report = await sync.synchronize(
        onProgress: (progress) {
          syncProgress = progress;
          notifyListeners();
        },
      );
      lastSyncReport = report;
      syncStatus = SyncUiStatus.complete;
      await refreshSlots();
      lastMessage = report.conflicts > 0
          ? '${report.conflicts} cloud conflict(s) need your choice.'
          : 'Cloud sync complete: ${report.uploaded} uploaded, ${report.downloaded} downloaded.';
    } on Object {
      syncStatus = SyncUiStatus.failed;
      rethrow;
    }
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
