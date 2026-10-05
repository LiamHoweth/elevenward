import 'api_models.dart';

Map<String, Object?> onlineObject(Object? value) =>
    (value as Map).cast<String, Object?>();

final class LeaderboardPage {
  const LeaderboardPage({
    required this.entries,
    required this.nearbyEntries,
    required this.totalEntries,
    this.myEntry,
  });
  factory LeaderboardPage.fromJson(Map<String, Object?> json) =>
      LeaderboardPage(
        entries: (json['entries'] as List? ?? [])
            .map((e) => LeaderboardEntry.fromJson(onlineObject(e)))
            .toList(),
        nearbyEntries: (json['nearbyEntries'] as List? ?? [])
            .map((e) => LeaderboardEntry.fromJson(onlineObject(e)))
            .toList(),
        totalEntries:
            (json['totalEntries'] as num?)?.toInt() ??
            (json['entries'] as List? ?? []).length,
        myEntry: json['myEntry'] == null
            ? null
            : LeaderboardEntry.fromJson(onlineObject(json['myEntry'])),
      );
  final List<LeaderboardEntry> entries;
  final List<LeaderboardEntry> nearbyEntries;
  final LeaderboardEntry? myEntry;
  final int totalEntries;
}

final class FriendCareer {
  FriendCareer.fromJson(Map<String, Object?> json)
    : position = json['position'] as String,
      difficulty = json['difficulty'] as String,
      rulesVersion = json['rulesVersion'] as String,
      legacyScore = (json['legacyScore'] as num).toInt(),
      seasons =
          (onlineObject(json['aggregateMetrics'] ?? {})['seasons'] as num?)
              ?.toInt() ??
          0,
      trophies =
          (onlineObject(json['aggregateMetrics'] ?? {})['trophies'] as num?)
              ?.toInt() ??
          0;
  final String position;
  final String difficulty;
  final String rulesVersion;
  final int legacyScore;
  final int seasons;
  final int trophies;
}

final class FriendProfile {
  FriendProfile.fromJson(Map<String, Object?> json)
    : profileId = json['profileId'] as String,
      alias = json['alias'] as String,
      comparisonAvailable = json['comparisonAvailable'] == true,
      careers = (json['careers'] as List? ?? [])
          .map((e) => FriendCareer.fromJson(onlineObject(e)))
          .toList();
  final String profileId;
  final String alias;
  final bool comparisonAvailable;
  final List<FriendCareer> careers;
}

final class FriendRequest {
  FriendRequest.fromJson(Map<String, Object?> json)
    : requestId = json['requestId'] as String,
      profileId = json['profileId'] as String,
      alias = json['alias'] as String;
  final String requestId;
  final String profileId;
  final String alias;
}

final class FriendsState {
  FriendsState.fromJson(Map<String, Object?> json)
    : comparisonSharingEnabled = json['comparisonSharingEnabled'] == true,
      friends = (json['friends'] as List? ?? [])
          .map((e) => FriendProfile.fromJson(onlineObject(e)))
          .toList(),
      incoming = (json['incomingRequests'] as List? ?? [])
          .map((e) => FriendRequest.fromJson(onlineObject(e)))
          .toList(),
      outgoing = (json['outgoingRequests'] as List? ?? [])
          .map((e) => FriendRequest.fromJson(onlineObject(e)))
          .toList(),
      blocked = (json['blocked'] as List? ?? [])
          .map((e) => onlineObject(e)['profileId'] as String)
          .toList();
  final bool comparisonSharingEnabled;
  final List<FriendProfile> friends;
  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;
  final List<String> blocked;
}

final class ApiChallenge {
  ApiChallenge.fromJson(Map<String, Object?> json)
    : id = json['id'] as String,
      startsAt = DateTime.parse(json['startsAt'] as String).toUtc(),
      endsAt = DateTime.parse(json['endsAt'] as String).toUtc(),
      rulesVersion = json['rulesVersion'] as String,
      contentVersion = json['contentVersion'] as String,
      matchCount = json['matchCount'] as int,
      configuration = onlineObject(json['configuration']);
  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String rulesVersion;
  final String contentVersion;
  final int matchCount;
  final Map<String, Object?> configuration;
}

final class ChallengeAttempt {
  ChallengeAttempt.fromJson(Map<String, Object?> json)
    : id = json['attemptId'] as String,
      seed = json['seed'] as int,
      careerId = json['careerId'] as String,
      status = json['status'] as String,
      enrolledAt = DateTime.parse(json['enrolledAt'] as String).toUtc(),
      score = (json['score'] as num?)?.toInt();
  final String id;
  final int seed;
  final String careerId;
  final String status;
  final DateTime enrolledAt;
  final int? score;
}

final class ChallengeStanding {
  ChallengeStanding.fromJson(Map<String, Object?> json)
    : rank = json['rank'] as int,
      alias = json['alias'] as String,
      score = json['score'] as int,
      isCurrentUser = json['isCurrentUser'] == true;
  final int rank;
  final String alias;
  final int score;
  final bool isCurrentUser;
}

final class ChallengeState {
  ChallengeState.fromJson(Map<String, Object?> json)
    : challenge = ApiChallenge.fromJson(onlineObject(json['challenge'])),
      attempt = json['attempt'] == null
          ? null
          : ChallengeAttempt.fromJson(onlineObject(json['attempt'])),
      entries = (json['entries'] as List? ?? [])
          .map((e) => ChallengeStanding.fromJson(onlineObject(e)))
          .toList();
  final ApiChallenge challenge;
  final ChallengeAttempt? attempt;
  final List<ChallengeStanding> entries;
}
