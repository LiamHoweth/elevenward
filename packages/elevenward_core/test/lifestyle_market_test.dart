import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  const market = LifestyleMarketEngine();
  const careerEngine = CareerEngine();
  final catalog = buildLaunchContent();

  test('weekly stock is stable, unique, and contains five items per shop', () {
    final snapshot = CareerSnapshot.newCareer(seed: 91204);
    final first = market.stockFor(snapshot, catalog);
    final second = market.stockFor(snapshot.copyWith(revision: 99), catalog);

    for (final category in LifestyleCategory.values) {
      final listings = first.forCategory(category);
      expect(listings, hasLength(5));
      expect(listings.map((item) => item.id).toSet(), hasLength(5));
      expect(
        second.forCategory(category).map((item) => item.id),
        listings.map((item) => item.id),
      );
    }
  });

  test('the next week changes stock without immediate repeats', () {
    final snapshot = CareerSnapshot.newCareer(seed: 44811);
    final current = market.stockFor(snapshot, catalog);
    final next = market.stockFor(snapshot.copyWith(week: 2), catalog);

    for (final category in LifestyleCategory.values) {
      final currentIds =
          current.forCategory(category).map((item) => item.id).toSet();
      final nextIds = next.forCategory(category).map((item) => item.id).toSet();
      expect(nextIds, isNot(equals(currentIds)));
      expect(nextIds.intersection(currentIds), isEmpty);
    }
  });

  test('week 18 and the following season also avoid immediate repeats', () {
    final snapshot = CareerSnapshot.newCareer(seed: 7751);
    final finalWeek = market.stockFor(
      snapshot.copyWith(season: 1, week: 18),
      catalog,
    );
    final newSeason = market.stockFor(
      snapshot.copyWith(season: 2, week: 1),
      catalog,
    );

    for (final category in LifestyleCategory.values) {
      expect(
        finalWeek
            .forCategory(category)
            .map((item) => item.id)
            .toSet()
            .intersection(
              newSeason.forCategory(category).map((item) => item.id).toSet(),
            ),
        isEmpty,
      );
    }
  });

  test('purchasing marks ownership without rerolling weekly stock', () {
    final base = CareerSnapshot.newCareer(seed: 1539);
    final snapshot = base.copyWith(
      player: base.player.copyWith(money: 100000000),
    );
    final before = market.stockFor(snapshot, catalog);
    final item = before.forCategory(LifestyleCategory.home).first;
    final purchased = careerEngine.purchaseLifestyleItem(
      snapshot: snapshot,
      item: item,
      updatedAt: snapshot.updatedAt.add(const Duration(minutes: 1)),
    );
    final after = market.stockFor(purchased, catalog);

    expect(purchased.ownedItemIds, contains(item.id));
    for (final category in LifestyleCategory.values) {
      expect(
        after.forCategory(category).map((item) => item.id),
        before.forCategory(category).map((item) => item.id),
      );
    }
  });

  test('small future pools return every item once', () {
    final homeItems = catalog.lifestyleItems
        .where((item) => item.category == LifestyleCategory.home)
        .take(3)
        .toList(growable: false);
    final smallCatalog = ContentCatalog(
      version: catalog.version,
      matchSituations: catalog.matchSituations,
      careerEvents: catalog.careerEvents,
      lifestyleItems: homeItems,
    );

    final stock = market.stockFor(
      CareerSnapshot.newCareer(seed: 64),
      smallCatalog,
    );
    expect(stock.forCategory(LifestyleCategory.home), hasLength(3));
    expect(
      stock.forCategory(LifestyleCategory.home).map((item) => item.id).toSet(),
      hasLength(3),
    );
    expect(stock.forCategory(LifestyleCategory.style), isEmpty);
    expect(
      () => stock.forCategory(LifestyleCategory.home).add(homeItems.first),
      throwsUnsupportedError,
    );
  });

  test('rarity weights favor common stock over scarce rarities', () {
    final counts = <ItemRarity, int>{
      for (final rarity in ItemRarity.values) rarity: 0,
    };
    for (var seed = 1; seed <= 1000; seed += 1) {
      final stock = market.stockFor(
        CareerSnapshot.newCareer(seed: seed),
        catalog,
      );
      for (final item in stock.forCategory(LifestyleCategory.home)) {
        counts[item.rarity] = counts[item.rarity]! + 1;
      }
    }

    expect(counts[ItemRarity.common]!, greaterThan(counts[ItemRarity.rare]!));
    expect(
        counts[ItemRarity.rare]!, greaterThan(counts[ItemRarity.legendary]!));
  });
}
