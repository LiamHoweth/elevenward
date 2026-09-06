import 'dart:convert';
import 'dart:io';

import 'package:purchases_flutter/purchases_flutter.dart';

import '../storage/career_store.dart';
import '../storage/secure_credentials.dart';

const extraSlotsEntitlement = 'extra_career_slots';
const supporterPackEntitlement = 'supporter_pack';
const extraSlotsProduct = 'com.howethstudio.elevenward.extra_slots';
const supporterPackProduct = 'com.howethstudio.elevenward.supporter_pack';

final class EntitlementState {
  const EntitlementState({
    this.extraCareerSlots = false,
    this.supporterPack = false,
  });

  factory EntitlementState.fromJson(Map<String, Object?> json) =>
      EntitlementState(
        extraCareerSlots: json['extraCareerSlots'] as bool? ?? false,
        supporterPack: json['supporterPack'] as bool? ?? false,
      );

  final bool extraCareerSlots;
  final bool supporterPack;

  int get careerSlotLimit => extraCareerSlots ? 5 : 2;

  Map<String, Object?> toJson() => {
    'extraCareerSlots': extraCareerSlots,
    'supporterPack': supporterPack,
  };
}

final class EntitlementService {
  EntitlementService({
    required SecureCredentials credentials,
    required CareerStore store,
  }) : _credentials = credentials, // ignore: prefer_initializing_formals
       _store = store; // ignore: prefer_initializing_formals

  final SecureCredentials _credentials;
  final CareerStore _store;
  bool _configured = false;
  EntitlementState _state = const EntitlementState();
  final Map<String, String> _localizedPrices = {};

  EntitlementState get state => _state;
  bool get isConfigured => _configured;
  String? localizedPrice(String productId) => _localizedPrices[productId];

  Future<EntitlementState> initialize() async {
    final cached = await _credentials.readEntitlementCache();
    if (cached != null) {
      try {
        _state = EntitlementState.fromJson(
          (jsonDecode(cached) as Map).cast<String, Object?>(),
        );
      } on FormatException {
        _state = const EntitlementState();
      }
    }
    _store.updateMaxSlots(_state.careerSlotLimit);

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
    Purchases.addCustomerInfoUpdateListener(_acceptCustomerInfo);
    try {
      await _loadLocalizedPrices();
    } on Object {
      // A storefront price outage must not suppress entitlement restoration.
    }
    return _refresh();
  }

  Future<EntitlementState> login(String accountId) async {
    if (!_configured) return _state;
    final result = await Purchases.logIn(accountId);
    return _acceptCustomerInfo(result.customerInfo);
  }

  Future<EntitlementState> logout() async {
    if (!_configured) return _state;
    return _acceptCustomerInfo(await Purchases.logOut());
  }

  Future<EntitlementState> restore() async {
    if (!_configured) {
      throw StateError('Store purchases are not configured in this build.');
    }
    return _acceptCustomerInfo(await Purchases.restorePurchases());
  }

  Future<EntitlementState> purchase(String entitlementId) async {
    if (!_configured) {
      throw StateError('Store purchases are not configured in this build.');
    }
    final productId = switch (entitlementId) {
      extraSlotsEntitlement => extraSlotsProduct,
      supporterPackEntitlement => supporterPackProduct,
      _ => throw ArgumentError.value(entitlementId, 'entitlementId'),
    };
    final offerings = await Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? const <Package>[];
    final package = packages.where(
      (candidate) => candidate.storeProduct.identifier == productId,
    );
    if (package.isEmpty) {
      throw StateError(
        'This permanent upgrade is unavailable in the current store region.',
      );
    }
    final result = await Purchases.purchase(
      PurchaseParams.package(package.first),
    );
    return _acceptCustomerInfo(result.customerInfo);
  }

  Future<void> _loadLocalizedPrices() async {
    final products = await Purchases.getProducts(const [
      extraSlotsProduct,
      supporterPackProduct,
    ], productCategory: ProductCategory.nonSubscription);
    for (final product in products) {
      _localizedPrices[product.identifier] = product.priceString;
    }
  }

  Future<EntitlementState> _refresh() async =>
      _acceptCustomerInfo(await Purchases.getCustomerInfo());

  EntitlementState _acceptCustomerInfo(CustomerInfo customerInfo) {
    final active = customerInfo.entitlements.active;
    final next = EntitlementState(
      extraCareerSlots: active[extraSlotsEntitlement]?.isActive ?? false,
      supporterPack: active[supporterPackEntitlement]?.isActive ?? false,
    );
    _state = next;
    _store.updateMaxSlots(next.careerSlotLimit);
    _credentials.writeEntitlementCache(jsonEncode(next.toJson()));
    return next;
  }
}
