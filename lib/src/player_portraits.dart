/// Bundled player portraits use stable IDs stored with each career.
const playerPortraitIds = <String>[
  'player_01',
  'player_02',
  'player_03',
  'player_04',
  'player_05',
  'player_06',
  'player_07',
  'player_08',
  'player_09',
  'player_10',
  'player_11',
  'player_12',
  'player_13',
  'player_14',
  'player_15',
  'player_16',
  'player_17',
  'player_18',
  'player_19',
  'player_20',
  'player_21',
  'player_22',
  'player_23',
  'player_24',
  'player_25',
  'player_26',
  'player_27',
  'player_28',
  'player_29',
  'player_30',
];

String? playerPortraitAsset(String? id) =>
    id != null && playerPortraitIds.contains(id)
    ? 'assets/visual/player_portraits/$id.webp'
    : null;
