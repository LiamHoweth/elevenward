import '../model/enums.dart';

const supportedLocales = ['en', 'es', 'pt-BR', 'fr'];

final class LocalizedText {
  LocalizedText(Map<String, String> values) : values = Map.unmodifiable(values);

  factory LocalizedText.fromJson(Map<String, Object?> json) => LocalizedText(
        json.map((key, value) => MapEntry(key, value as String)),
      );

  final Map<String, String> values;

  String forLocale(String locale) => values[locale] ?? values['en']!;

  Map<String, Object?> toJson() => values;
}

final class SituationOption {
  const SituationOption({
    required this.approach,
    required this.title,
    required this.primaryAttributes,
    required this.trustRisk,
    required this.ratingUpside,
  });

  final SpotlightApproach approach;
  final LocalizedText title;
  final List<PlayerAttribute> primaryAttributes;
  final int trustRisk;
  final double ratingUpside;

  Map<String, Object?> toJson() => {
        'approach': approach.name,
        'title': title.toJson(),
        'primaryAttributes':
            primaryAttributes.map((value) => value.name).toList(),
        'trustRisk': trustRisk,
        'ratingUpside': ratingUpside,
      };
}

final class MatchSituationDefinition {
  const MatchSituationDefinition({
    required this.id,
    required this.position,
    required this.archetypeTags,
    required this.minuteFrom,
    required this.minuteTo,
    required this.prompt,
    required this.options,
  });

  final String id;
  final PositionFamily position;
  final List<Archetype> archetypeTags;
  final int minuteFrom;
  final int minuteTo;
  final LocalizedText prompt;
  final List<SituationOption> options;

  Map<String, Object?> toJson() => {
        'id': id,
        'position': position.name,
        'archetypeTags': archetypeTags.map((value) => value.name).toList(),
        'minuteFrom': minuteFrom,
        'minuteTo': minuteTo,
        'prompt': prompt.toJson(),
        'options': options.map((value) => value.toJson()).toList(),
      };
}

enum CareerEventCategory {
  manager,
  teammate,
  agent,
  sponsor,
  press,
  family,
  reputation,
  wellness,
  community,
  contract,
}

final class EventChoiceDefinition {
  const EventChoiceDefinition({
    required this.id,
    required this.label,
    required this.trustDelta,
    required this.reputationDelta,
    required this.moneyDelta,
    required this.wellnessDelta,
  });

  final String id;
  final LocalizedText label;
  final int trustDelta;
  final int reputationDelta;
  final int moneyDelta;
  final int wellnessDelta;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label.toJson(),
        'trustDelta': trustDelta,
        'reputationDelta': reputationDelta,
        'moneyDelta': moneyDelta,
        'wellnessDelta': wellnessDelta,
      };
}

final class CareerEventDefinition {
  const CareerEventDefinition({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.choices,
  });

  final String id;
  final CareerEventCategory category;
  final LocalizedText title;
  final LocalizedText body;
  final List<EventChoiceDefinition> choices;

  Map<String, Object?> toJson() => {
        'id': id,
        'category': category.name,
        'title': title.toJson(),
        'body': body.toJson(),
        'choices': choices.map((value) => value.toJson()).toList(),
      };
}

enum LifestyleCategory { home, transportation, style, wellness }

enum ItemRarity { common, uncommon, rare, epic, legendary }

final class LifestyleItemDefinition {
  const LifestyleItemDefinition({
    required this.id,
    required this.category,
    required this.rarity,
    required this.name,
    required this.description,
    required this.price,
    required this.reputationEffect,
    required this.wellnessEffect,
  });

  final String id;
  final LifestyleCategory category;
  final ItemRarity rarity;
  final LocalizedText name;
  final LocalizedText description;
  final int price;
  final int reputationEffect;
  final int wellnessEffect;

  Map<String, Object?> toJson() => {
        'id': id,
        'category': category.name,
        'rarity': rarity.name,
        'name': name.toJson(),
        'description': description.toJson(),
        'price': price,
        'reputationEffect': reputationEffect,
        'wellnessEffect': wellnessEffect,
      };
}

final class ContentManifest {
  const ContentManifest({
    required this.releaseVersion,
    required this.minimumClientVersion,
    required this.maximumClientVersion,
    required this.checksum,
    required this.locales,
    required this.assetPath,
    required this.signature,
  });

  final String releaseVersion;
  final String minimumClientVersion;
  final String maximumClientVersion;
  final String checksum;
  final List<String> locales;
  final String assetPath;
  final String signature;

  Map<String, Object?> toJson() => {
        'releaseVersion': releaseVersion,
        'minimumClientVersion': minimumClientVersion,
        'maximumClientVersion': maximumClientVersion,
        'checksum': checksum,
        'locales': locales,
        'assetPath': assetPath,
        'signature': signature,
      };
}

final class ContentCatalog {
  const ContentCatalog({
    required this.version,
    required this.matchSituations,
    required this.careerEvents,
    required this.lifestyleItems,
  });

  /// Decodes a validated remote bundle into the same immutable domain objects
  /// used by the in-app launch catalog. Executable rules never come from this
  /// payload; only authored data is accepted here.
  factory ContentCatalog.fromBundle(Map<String, Object?> bundle) {
    Map<String, Object?> object(Object? value, String path) {
      if (value is! Map) throw FormatException('$path must be an object.');
      return value.cast<String, Object?>();
    }

    List<Object?> list(Object? value, String path) {
      if (value is! List) throw FormatException('$path must be a list.');
      return value.cast<Object?>();
    }

    T named<T extends Enum>(List<T> values, Object? value, String path) {
      if (value is! String) throw FormatException('$path must be a string.');
      return values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => throw FormatException('$path has unsupported value.'),
      );
    }

    final metadata = object(bundle['metadata'], 'metadata');
    final situations = list(
      bundle['matchSituations'],
      'matchSituations',
    ).map((raw) {
      final item = object(raw, 'matchSituation');
      return MatchSituationDefinition(
        id: item['id'] as String,
        position: named(PositionFamily.values, item['position'], 'position'),
        archetypeTags: list(item['archetypeTags'], 'archetypeTags')
            .map((value) => named(Archetype.values, value, 'archetypeTag'))
            .toList(growable: false),
        minuteFrom: item['minuteFrom'] as int,
        minuteTo: item['minuteTo'] as int,
        prompt: LocalizedText.fromJson(object(item['prompt'], 'prompt')),
        options: list(item['options'], 'options').map((rawOption) {
          final option = object(rawOption, 'option');
          return SituationOption(
            approach: named(
              SpotlightApproach.values,
              option['approach'],
              'approach',
            ),
            title: LocalizedText.fromJson(object(option['title'], 'title')),
            primaryAttributes: list(
              option['primaryAttributes'],
              'primaryAttributes',
            )
                .map(
                  (value) => named(
                    PlayerAttribute.values,
                    value,
                    'primaryAttribute',
                  ),
                )
                .toList(growable: false),
            trustRisk: option['trustRisk'] as int,
            ratingUpside: (option['ratingUpside'] as num).toDouble(),
          );
        }).toList(growable: false),
      );
    }).toList(growable: false);
    final events = list(bundle['events'], 'events').map((raw) {
      final item = object(raw, 'event');
      return CareerEventDefinition(
        id: item['id'] as String,
        category: named(
          CareerEventCategory.values,
          item['category'],
          'category',
        ),
        title: LocalizedText.fromJson(object(item['title'], 'title')),
        body: LocalizedText.fromJson(object(item['body'], 'body')),
        choices: list(item['choices'], 'choices').map((rawChoice) {
          final choice = object(rawChoice, 'choice');
          return EventChoiceDefinition(
            id: choice['id'] as String,
            label: LocalizedText.fromJson(object(choice['label'], 'label')),
            trustDelta: choice['trustDelta'] as int,
            reputationDelta: choice['reputationDelta'] as int,
            moneyDelta: choice['moneyDelta'] as int,
            wellnessDelta: choice['wellnessDelta'] as int,
          );
        }).toList(growable: false),
      );
    }).toList(growable: false);
    final items = list(bundle['lifestyleItems'], 'lifestyleItems').map((raw) {
      final item = object(raw, 'lifestyleItem');
      return LifestyleItemDefinition(
        id: item['id'] as String,
        category: named(
          LifestyleCategory.values,
          item['category'],
          'category',
        ),
        rarity: named(ItemRarity.values, item['rarity'], 'rarity'),
        name: LocalizedText.fromJson(object(item['name'], 'name')),
        description: LocalizedText.fromJson(
          object(item['description'], 'description'),
        ),
        price: item['price'] as int,
        reputationEffect: item['reputationEffect'] as int,
        wellnessEffect: item['wellnessEffect'] as int,
      );
    }).toList(growable: false);
    return ContentCatalog(
      version: metadata['releaseVersion'] as String,
      matchSituations: List.unmodifiable(situations),
      careerEvents: List.unmodifiable(events),
      lifestyleItems: List.unmodifiable(items),
    );
  }

  final String version;
  final List<MatchSituationDefinition> matchSituations;
  final List<CareerEventDefinition> careerEvents;
  final List<LifestyleItemDefinition> lifestyleItems;

  Map<String, Object?> toJson() => {
        'version': version,
        'locales': supportedLocales,
        'matchSituations':
            matchSituations.map((value) => value.toJson()).toList(),
        'careerEvents': careerEvents.map((value) => value.toJson()).toList(),
        'lifestyleItems':
            lifestyleItems.map((value) => value.toJson()).toList(),
      };
}
