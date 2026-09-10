import 'dart:convert';
import 'dart:io';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../storage/career_store.dart';
import '../storage/secure_credentials.dart';

const extraSlotsEntitlement = 'extra_career_slots';
const supporterPackEntitlement = 'supporter_pack';
const extraSlotsProduct = 'com.howethstudio.elevenward.extra_slots';
const supporterPackProduct = 'com.howethstudio.elevenward.supporter_pack';

enum GamePassId { vip, doubleDevelopment, doubleMoney, allAccess }

final class GamePassDefinition {
  const GamePassDefinition({
    required this.id,
    required this.entitlementId,
    required this.productId,
    required this.referencePriceUsd,
  });

  final GamePassId id;
  final String entitlementId;
  final String productId;
  final double referencePriceUsd;
}

const gamePassDefinitions = <GamePassDefinition>[
  GamePassDefinition(
    id: GamePassId.allAccess,
    entitlementId: 'all_access',
    productId: 'com.howethstudio.elevenward.all_access',
    referencePriceUsd: 9.99,
  ),
  GamePassDefinition(
    id: GamePassId.vip,
    entitlementId: 'vip_starter_pack',
    productId: 'com.howethstudio.elevenward.vip',
    referencePriceUsd: 4.99,
  ),
  GamePassDefinition(
    id: GamePassId.doubleDevelopment,
    entitlementId: 'double_development',
    productId: 'com.howethstudio.elevenward.double_development',
    referencePriceUsd: 3.99,
  ),
  GamePassDefinition(
    id: GamePassId.doubleMoney,
    entitlementId: 'double_money',
    productId: 'com.howethstudio.elevenward.double_money',
    referencePriceUsd: 3.99,
  ),
];

GamePassDefinition gamePassDefinition(GamePassId id) =>
    gamePassDefinitions.firstWhere((definition) => definition.id == id);

enum StoreCatalogStatus { unconfigured, loading, available, partial, failed }

final class PurchaseCancelledException implements Exception {
  const PurchaseCancelledException();
}

final class EntitlementState {
  const EntitlementState({
    this.ownedPasses = const {},
    this.legacyExtraCareerSlots = false,
    this.legacySupporterPack = false,
  });

  factory EntitlementState.fromJson(Map<String, Object?> json) {
    final names = (json['ownedPasses'] as List<Object?>? ?? const [])
        .whereType<String>();
    return EntitlementState(
      ownedPasses: {
        for (final name in names)
          for (final id in GamePassId.values)
            if (id.name == name) id,
      },
      legacyExtraCareerSlots:
          json['legacyExtraCareerSlots'] as bool? ??
          json['extraCareerSlots'] as bool? ??
          false,
      legacySupporterPack:
          json['legacySupporterPack'] as bool? ??
          json['supporterPack'] as bool? ??
          false,
    );
  }

  final Set<GamePassId> ownedPasses;
  final bool legacyExtraCareerSlots;
  final bool legacySupporterPack;

  bool ownsDirectly(GamePassId id) => ownedPasses.contains(id);

  bool ownsBenefit(GamePassId id) =>
      ownedPasses.contains(id) || ownedPasses.contains(GamePassId.allAccess);

  bool get hasVip => ownsBenefit(GamePassId.vip);
  bool get hasDoubleDevelopment => ownsBenefit(GamePassId.doubleDevelopment);
  bool get hasDoubleMoney => ownsBenefit(GamePassId.doubleMoney);
  bool get hasAllAccess => ownsDirectly(GamePassId.allAccess);
  bool get hasAnyCorePass =>
      ownsDirectly(GamePassId.vip) ||
      ownsDirectly(GamePassId.doubleDevelopment) ||
      ownsDirectly(GamePassId.doubleMoney);

  bool get extraCareerSlots => legacyExtraCareerSlots || hasVip;
  bool get supporterPack => legacySupporterPack || hasVip;
  bool get premiumCosmetics => supporterPack;
  int get careerSlotLimit => extraCareerSlots ? 5 : 2;

  RewardModifiers get rewardModifiers {
    var development = 1.0;
    var money = 1.0;
    if (hasVip) {
      development *= 1.5;
      money *= 1.5;
    }
    if (hasDoubleDevelopment) development *= 2;
    if (hasDoubleMoney) money *= 2;
    final sources = <String>[
      if (hasAllAccess)
        GamePassId.allAccess.name
      else ...[
        if (ownsDirectly(GamePassId.vip)) GamePassId.vip.name,
        if (ownsDirectly(GamePassId.doubleDevelopment))
          GamePassId.doubleDevelopment.name,
        if (ownsDirectly(GamePassId.doubleMoney)) GamePassId.doubleMoney.name,
      ],
    ];
    return RewardModifiers(
      developmentMultiplier: development,
      moneyMultiplier: money,
      sourceIds: sources,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 2,
    'ownedPasses': (ownedPasses.map((id) => id.name).toList()..sort()),
    'legacyExtraCareerSlots': legacyExtraCareerSlots,
    'legacySupporterPack': legacySupporterPack,
  };
}

final class EntitlementService {
  EntitlementService({
    required this.credentials,
    required this.store,
    EntitlementState initialState = const EntitlementState(),
    StoreCatalogStatus initialCatalogStatus = StoreCatalogStatus.unconfigured,
    Map<String, String> initialLocalizedPrices = const {},
    Set<String> initialAvailableProductIds = const {},
  }) : _state = initialState,
       _catalogStatus = initialCatalogStatus {
    _localizedPrices.addAll(initialLocalizedPrices);
    _availableProductIds.addAll(initialAvailableProductIds);
  }

  final SecureCredentials credentials;
  final CareerStore store;
  bool _configured = false;
  EntitlementState _state;
  final Map<String, String> _localizedPrices = {};
  final Set<String> _availableProductIds = {};
  StoreCatalogStatus _catalogStatus;
  bool _initialReconciliation = true;

  EntitlementState get state => _state;
  bool get isConfigured => _configured;
  StoreCatalogStatus get catalogStatus => _catalogStatus;
  String? localizedPrice(String productId) => _localizedPrices[productId];
  bool isProductAvailable(String productId) =>
      _availableProductIds.contains(productId);

  Future<EntitlementState> initialize() async {
    final cached = await credentials.readEntitlementCache();
    if (cached != null) {
      try {
        _state = EntitlementState.fromJson(
          (jsonDecode(cached) as Map).cast<String, Object?>(),
        );
      } on Object {
        _state = const EntitlementState();
      }
    }
    store.updateMaxSlots(_state.careerSlotLimit);

    final key = Platform.isIOS
        ? const String.fromEnvironment('REVENUECAT_IOS_PUBLIC_KEY')
        : const String.fromEnvironment('REVENUECAT_ANDROID_PUBLIC_KEY');
    if (key.isEmpty) return _state;
    final configuration = PurchasesConfiguration(key)
      ..automaticDeviceIdentifierCollectionEnabled = false
      ..diagnosticsEnabled = false
      ..entitlementVerificationMode = EntitlementVerificationMode.informational;
    await Purchases.configure(configuration);
    _configured = true;
    _catalogStatus = StoreCatalogStatus.loading;
    Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
    await refreshCatalog();
    final result = await _refresh(preserveMissingLegacy: true);
    _initialReconciliation = false;
    return result;
  }

  Future<EntitlementState> login(String accountId) async {
    if (!_configured) return _state;
    _initialReconciliation = false;
    final result = await Purchases.logIn(accountId);
    return _acceptCustomerInfo(result.customerInfo);
  }

  Future<EntitlementState> logout() async {
    if (!_configured) return _state;
    _initialReconciliation = false;
    return _acceptCustomerInfo(await Purchases.logOut());
  }

  Future<EntitlementState> restore() async {
    if (!_configured) {
      throw StateError('Store purchases are not configured in this build.');
    }
    return _acceptCustomerInfo(await Purchases.restorePurchases());
  }

  Future<EntitlementState> purchase(GamePassId id) async {
    if (!_configured) {
      throw StateError('Store purchases are not configured in this build.');
    }
    final definition = gamePassDefinition(id);
    final offerings = await Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? const <Package>[];
    final matches = packages.where(
      (candidate) => candidate.storeProduct.identifier == definition.productId,
    );
    if (matches.isEmpty) {
      throw StateError(
        'This permanent upgrade is unavailable in the current store region.',
      );
    }
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(matches.first),
      );
      return _acceptCustomerInfo(result.customerInfo);
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        throw const PurchaseCancelledException();
      }
      rethrow;
    }
  }

  Future<void> refreshCatalog() async {
    if (!_configured) {
      _catalogStatus = StoreCatalogStatus.unconfigured;
      return;
    }
    _catalogStatus = StoreCatalogStatus.loading;
    try {
      final offerings = await Purchases.getOfferings();
      final packages =
          offerings.current?.availablePackages ?? const <Package>[];
      final expectedIds = gamePassDefinitions
          .map((definition) => definition.productId)
          .toSet();
      _localizedPrices.clear();
      _availableProductIds.clear();
      for (final package in packages) {
        final product = package.storeProduct;
        if (!expectedIds.contains(product.identifier)) continue;
        _localizedPrices[product.identifier] = product.priceString;
        _availableProductIds.add(product.identifier);
      }
      _catalogStatus = _availableProductIds.length == gamePassDefinitions.length
          ? StoreCatalogStatus.available
          : StoreCatalogStatus.partial;
    } on Object {
      _catalogStatus = StoreCatalogStatus.failed;
    }
  }

  Future<EntitlementState> _refresh({
    bool preserveMissingLegacy = false,
  }) async => _acceptCustomerInfo(
    await Purchases.getCustomerInfo(),
    preserveMissingLegacy: preserveMissingLegacy,
  );

  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    _acceptCustomerInfo(
      customerInfo,
      preserveMissingLegacy: _initialReconciliation,
    );
  }

  EntitlementState _acceptCustomerInfo(
    CustomerInfo customerInfo, {
    bool preserveMissingLegacy = false,
  }) {
    final active = customerInfo.entitlements.active;
    bool legacyIsActive(String id, bool cached) {
      final record = customerInfo.entitlements.all[id];
      return record == null ? preserveMissingLegacy && cached : record.isActive;
    }

    final next = EntitlementState(
      ownedPasses: {
        for (final definition in gamePassDefinitions)
          if (active[definition.entitlementId]?.isActive ?? false)
            definition.id,
      },
      legacyExtraCareerSlots: legacyIsActive(
        extraSlotsEntitlement,
        _state.legacyExtraCareerSlots,
      ),
      legacySupporterPack: legacyIsActive(
        supporterPackEntitlement,
        _state.legacySupporterPack,
      ),
    );
    _state = next;
    store.updateMaxSlots(next.careerSlotLimit);
    credentials.writeEntitlementCache(jsonEncode(next.toJson()));
    return next;
  }
}
