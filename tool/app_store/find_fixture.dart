import 'dart:io';

import 'career_fixture.dart';

void main() {
  final fixture = const AppStoreCareerFixtureBuilder().build();
  final mid = fixture.midCareer;
  final late = fixture.lateCareer;
  final trophies = mid.seasonHistory.fold<int>(
    0,
    (total, season) => total + season.trophies.length,
  );
  stdout.writeln(
    'seed=${fixture.seed} midAge=${mid.player.age} midOverall=${mid.player.overall} '
    'caps=${mid.nationalTeam.caps} trophies=$trophies club=${mid.clubName} '
    'lateAge=${late.player.age} lateSeasons=${late.seasonHistory.length}',
  );
}
