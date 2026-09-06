import 'dart:async';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import 'services/analytics_service.dart';
import 'services/api_models.dart';
import 'services/auth_service.dart';
import 'services/content_service.dart';
import 'services/entitlement_service.dart';
import 'services/sync_service.dart';
import 'storage/career_store.dart';
import 'util/uuid.dart';

enum AppStage { booting, onboarding, careerSlots, playing }

enum SyncUiStatus { idle, running, complete, failed }

final class AppController extends ChangeNotifier {
  AppController({
    required this.store,
    required this.auth,
    required this.entitlements,
    required this.sync,
    required this.analytics,
    required this.content,
  });

  final CareerStore store;
  final AuthService auth;
  final EntitlementService entitlements;
  final SyncService sync;
  final AnalyticsService analytics;
  final ContentService content;

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
  bool busy = false;
  String? lastMessage;
  SyncUiStatus syncStatus = SyncUiStatus.idle;
  SyncProgressUpdate? syncProgress;
  SyncReport? lastSyncReport;

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
      final completedOnboarding =
          await store.getPreference('onboarding.completed') == true;
      stage = completedOnboarding ? AppStage.careerSlots : AppStage.onboarding;
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
    stage = AppStage.careerSlots;
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
    required String playerName,
    required Archetype archetype,
    required String nationalTeamId,
    required ClubDefinition club,
    required Difficulty difficulty,
  }) async {
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
      player: PlayerState.newCareer(
        id: generateUuidV4(),
        name: playerName.trim(),
        archetype: archetype,
        nationalTeamId: nationalTeamId,
      ),
    );
    await store.saveSlot(slotIndex, snapshot, eventType: 'career_started');
    await refreshSlots();
    activeSlotIndex = slotIndex;
    activeCareer = snapshot;
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

  Future<void> saveCareer(
    CareerSnapshot snapshot, {
    String eventType = 'snapshot_saved',
  }) async {
    final slot = activeSlotIndex;
    if (slot == null) throw StateError('No active career slot.');
    final previous = activeCareer;
    await store.saveSlot(slot, snapshot, eventType: eventType);
    activeCareer = snapshot;
    await refreshSlots();
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

  Future<void> deleteSlot(int index) async {
    await store.deleteSlot(index, DateTime.now().toUtc());
    if (activeSlotIndex == index) {
      activeSlotIndex = null;
      activeCareer = null;
      activeContent = availableContent;
      stage = AppStage.careerSlots;
    }
    await refreshSlots();
  }

  void showCareerSlots() {
    activeSlotIndex = null;
    activeCareer = null;
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

  Future<void> setCosmeticPreference(String key, String value) async {
    const freeValues = {'pitch', 'initials', 'timeline', 'classic'};
    if (!entitlementState.supporterPack && !freeValues.contains(value)) {
      lastMessage = 'The Supporter Pack unlocks this cosmetic.';
      notifyListeners();
      return;
    }
    switch (key) {
      case 'theme':
        themeId = value;
      case 'avatar':
        avatarId = value;
      case 'archiveLayout':
        archiveLayoutId = value;
      case 'shareCard':
        shareCardStyleId = value;
      default:
        throw ArgumentError.value(key, 'key');
    }
    await store.setPreference('cosmetic.$key', value);
    notifyListeners();
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
        activeContent = availableContent;
        stage = AppStage.careerSlots;
      } else {
        final pinned = await content.loadVersion(resolved.contentVersion);
        if (pinned == null) {
          activeSlotIndex = null;
          activeCareer = null;
          activeContent = availableContent;
          stage = AppStage.careerSlots;
          lastMessage =
              'The resolved career needs content ${resolved.contentVersion}, which is not available on this device.';
          return;
        }
        activeCareer = resolved;
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

  Future<void> purchase(String entitlementId) => _runOnline(() async {
    entitlementState = await entitlements.purchase(entitlementId);
    await refreshSlots();
    lastMessage = 'Purchase restored on this device.';
  });

  Future<void> restorePurchases() => _runOnline(() async {
    entitlementState = await entitlements.restore();
    await refreshSlots();
    lastMessage = 'Purchases restored.';
  });

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
}
