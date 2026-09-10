import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../services/entitlement_service.dart';
import '../theme.dart';
import '../ui_copy.dart';

enum ShopProductUiState {
  loading,
  available,
  processing,
  owned,
  includedWithAllAccess,
  unavailable,
}

final class ShopScreen extends StatelessWidget {
  const ShopScreen({
    super.key,
    required this.controller,
    this.showAtmosphere = true,
  });

  final AppController controller;
  final bool showAtmosphere;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final catalogStatus = controller.entitlements.catalogStatus;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 68,
            backgroundColor: ElevenwardColors.ink.withValues(alpha: 0.98),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: Text(
              uiCopy(locale, 'shop'),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.2),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: ElevenwardSpacing.sm),
                child: IconButton(
                  tooltip: context.l10n.restorePurchases,
                  style: IconButton.styleFrom(
                    backgroundColor: ElevenwardColors.panel,
                    foregroundColor: ElevenwardColors.cream,
                    disabledBackgroundColor: ElevenwardColors.panel,
                    disabledForegroundColor: ElevenwardColors.muted,
                    side: const BorderSide(color: ElevenwardColors.line),
                  ),
                  onPressed: controller.busy
                      ? null
                      : controller.restorePurchases,
                  icon: const Icon(Icons.restore_rounded),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: ElevenwardColors.line.withValues(alpha: 0.72),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList.list(
              children: [
                const _ShopHero(key: Key('shop-hero')),
                const SizedBox(height: ElevenwardSpacing.sm),
                const _StackingExplainer(key: Key('stacking-explainer')),
                const SizedBox(height: ElevenwardSpacing.lg),
                if (catalogStatus == StoreCatalogStatus.loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: ElevenwardSpacing.md),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (catalogStatus == StoreCatalogStatus.failed ||
                    catalogStatus == StoreCatalogStatus.partial ||
                    catalogStatus == StoreCatalogStatus.unconfigured)
                  _StoreNotice(
                    text: catalogStatus == StoreCatalogStatus.unconfigured
                        ? uiCopy(locale, 'unavailable')
                        : uiCopy(locale, 'purchaseFailed'),
                    onRetry:
                        controller.busy ||
                            catalogStatus == StoreCatalogStatus.unconfigured
                        ? null
                        : controller.refreshStoreCatalog,
                  ),
                if (controller.lastPurchaseOutcome case final outcome?) ...[
                  const SizedBox(height: ElevenwardSpacing.sm),
                  _OutcomeNotice(outcome: outcome),
                ],
                if (controller.entitlementState.hasAnyCorePass &&
                    !controller.entitlementState.hasAllAccess) ...[
                  const SizedBox(height: ElevenwardSpacing.sm),
                  _StoreNotice(text: uiCopy(locale, 'partialOwnership')),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                  child: Text(
                    uiCopy(locale, 'shopOptions'),
                    style: const TextStyle(
                      color: ElevenwardColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.35,
                    ),
                  ),
                ),
                for (final definition in gamePassDefinitions) ...[
                  _GamePassCard(
                    definition: definition,
                    controller: controller,
                    showAtmosphere: showAtmosphere,
                  ),
                  const SizedBox(height: ElevenwardSpacing.sm),
                ],
                const SizedBox(height: ElevenwardSpacing.sm),
                OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : controller.restorePurchases,
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(context.l10n.restorePurchases),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _ShopHero extends StatelessWidget {
  const _ShopHero({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Container(
      padding: const EdgeInsets.all(ElevenwardSpacing.lg),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF193222), ElevenwardColors.panel],
        ),
        borderRadius: BorderRadius.circular(ElevenwardRadii.hero),
        border: Border.all(color: ElevenwardColors.line),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -34,
            top: -42,
            child: _AtmosphereOrb(
              size: 126,
              color: ElevenwardColors.grass,
              opacity: 0.10,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: ElevenwardColors.grass,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.north_east_rounded,
                      size: 20,
                      color: ElevenwardColors.ink,
                    ),
                  ),
                  const SizedBox(width: ElevenwardSpacing.sm),
                  Expanded(
                    child: Text(
                      uiCopy(locale, 'shopEyebrow'),
                      style: const TextStyle(
                        color: ElevenwardColors.grass,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ElevenwardSpacing.md),
              Text(
                uiCopy(locale, 'shopHeadline'),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: ElevenwardSpacing.xs),
              Text(
                uiCopy(locale, 'shopIntro'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _StackingExplainer extends StatelessWidget {
  const _StackingExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return BroadcastPanel(
      accent: ElevenwardColors.grass.withValues(alpha: 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.layers_rounded, color: ElevenwardColors.grass),
              const SizedBox(width: ElevenwardSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uiCopy(locale, 'stackingTitle'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: ElevenwardSpacing.xxs),
                    Text(
                      uiCopy(locale, 'stackingBody'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ElevenwardSpacing.md),
          Wrap(
            spacing: 5,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _EquationToken(label: 'VIP', value: '1.5×'),
              const _EquationMark('×'),
              _EquationToken(label: uiCopy(locale, 'boostShort'), value: '2×'),
              const _EquationMark('='),
              _EquationToken(
                label: uiCopy(locale, 'totalShort'),
                value: '3×',
                emphasized: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _EquationToken extends StatelessWidget {
  const _EquationToken({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      color: emphasized ? ElevenwardColors.grass : ElevenwardColors.grassDark,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: ElevenwardColors.grass.withValues(alpha: emphasized ? 1 : 0.42),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasized ? ElevenwardColors.ink : ElevenwardColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: emphasized ? ElevenwardColors.ink : ElevenwardColors.cream,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

final class _EquationMark extends StatelessWidget {
  const _EquationMark(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => Text(
    value,
    style: const TextStyle(
      color: ElevenwardColors.muted,
      fontSize: 18,
      fontWeight: FontWeight.w900,
    ),
  );
}

final class _AtmosphereOrb extends StatelessWidget {
  const _AtmosphereOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity),
            blurRadius: size * 0.34,
            spreadRadius: size * 0.08,
          ),
        ],
      ),
    ),
  );
}

final class _GamePassCard extends StatelessWidget {
  const _GamePassCard({
    required this.definition,
    required this.controller,
    required this.showAtmosphere,
  });

  final GamePassDefinition definition;
  final AppController controller;
  final bool showAtmosphere;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final state = _state;
    final featured = definition.id == GamePassId.allAccess;
    final price = controller.entitlements.localizedPrice(definition.productId);
    final title = _title(locale, definition.id);
    final benefit = _benefit(locale, definition.id);
    final accent = _accent(definition.id);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final visualWeight = (definition.referencePriceUsd / 9.99).clamp(0.0, 1.0);
    final contentPadding = 18.0 + (visualWeight * 8);
    final iconSize = 44.0 + (visualWeight * 14);
    return Semantics(
      key: Key('gamepass-${definition.id.name}'),
      container: true,
      label: '$title. $benefit. ${_stateLabel(locale, state)}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: ElevenwardColors.panel,
          gradient: featured
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.06 + (visualWeight * 0.08)),
                    ElevenwardColors.panel,
                  ],
                ),
          image: featured && showAtmosphere
              ? const DecorationImage(
                  image: AssetImage('assets/visual/shop-all-access.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Color(0xB307110C),
                    BlendMode.srcOver,
                  ),
                )
              : null,
          borderRadius: BorderRadius.circular(ElevenwardRadii.hero),
          border: Border.all(
            color: accent.withValues(alpha: 0.42 + (visualWeight * 0.42)),
            width: 1 + visualWeight,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.04 + (visualWeight * 0.07)),
              blurRadius: 12 + (visualWeight * 22),
              offset: Offset(0, 6 + (visualWeight * 6)),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -28 - (visualWeight * 14),
              bottom: -46 - (visualWeight * 8),
              child: _AtmosphereOrb(
                size: 104 + (visualWeight * 76),
                color: accent,
                opacity: 0.035 + (visualWeight * 0.055),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(contentPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: accent.withValues(
                            alpha: 0.12 + (visualWeight * 0.09),
                          ),
                          borderRadius: BorderRadius.circular(
                            14 + (visualWeight * 4),
                          ),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Icon(
                          _icon(definition.id),
                          color: accent,
                          size: 23 + (visualWeight * 7),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (featured)
                              Text(
                                uiCopy(locale, 'featuredValue'),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: featured ? 21 : null,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            if (largeText && price != null) ...[
                              const SizedBox(height: 7),
                              _PriceBadge(price: price, accent: accent),
                            ],
                          ],
                        ),
                      ),
                      if (!largeText && price != null) ...[
                        const SizedBox(width: ElevenwardSpacing.sm),
                        _PriceBadge(price: price, accent: accent),
                      ],
                    ],
                  ),
                  SizedBox(height: featured ? 18 : 14),
                  Text(
                    benefit,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: featured
                          ? ElevenwardColors.cream.withValues(alpha: 0.82)
                          : null,
                    ),
                  ),
                  const SizedBox(height: ElevenwardSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.26),
                        ),
                      ),
                      child: Text(
                        _stackLabel(locale, definition.id),
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.75,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: featured ? 22 : 18),
                  _PurchaseButton(
                    key: Key('purchase-${definition.id.name}'),
                    state: state,
                    accent: accent,
                    price: price,
                    onPressed:
                        state == ShopProductUiState.available &&
                            !controller.busy
                        ? () => controller.purchase(definition.id)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ShopProductUiState get _state {
    final id = definition.id;
    final entitlements = controller.entitlementState;
    if (controller.processingPass == id) return ShopProductUiState.processing;
    if (entitlements.ownsDirectly(id)) return ShopProductUiState.owned;
    if (id != GamePassId.allAccess && entitlements.hasAllAccess) {
      return ShopProductUiState.includedWithAllAccess;
    }
    if (id == GamePassId.allAccess && entitlements.hasAnyCorePass) {
      return ShopProductUiState.unavailable;
    }
    if (controller.entitlements.catalogStatus == StoreCatalogStatus.loading) {
      return ShopProductUiState.loading;
    }
    if (controller.entitlements.isProductAvailable(definition.productId)) {
      return ShopProductUiState.available;
    }
    return ShopProductUiState.unavailable;
  }
}

final class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price, required this.accent});

  final String price;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.38)),
    ),
    child: Text(
      price,
      style: TextStyle(
        color: accent,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

final class _PurchaseButton extends StatelessWidget {
  const _PurchaseButton({
    super.key,
    required this.state,
    required this.accent,
    required this.price,
    required this.onPressed,
  });

  final ShopProductUiState state;
  final Color accent;
  final String? price;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    if (state == ShopProductUiState.processing ||
        state == ShopProductUiState.loading) {
      return const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final label = switch (state) {
      ShopProductUiState.owned => uiCopy(locale, 'owned'),
      ShopProductUiState.includedWithAllAccess => uiCopy(
        locale,
        'includedAllAccess',
      ),
      ShopProductUiState.unavailable => uiCopy(locale, 'unavailable'),
      ShopProductUiState.available =>
        '${uiCopy(locale, 'buyPermanent')}${price == null ? '' : ' · $price'}',
      ShopProductUiState.processing => uiCopy(locale, 'processing'),
      ShopProductUiState.loading => uiCopy(locale, 'processing'),
    };
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        disabledBackgroundColor: ElevenwardColors.line,
        disabledForegroundColor: ElevenwardColors.muted,
      ),
      onPressed: onPressed,
      icon: Icon(
        state == ShopProductUiState.owned ||
                state == ShopProductUiState.includedWithAllAccess
            ? Icons.check_circle_rounded
            : Icons.lock_open_rounded,
      ),
      label: Text(label, textAlign: TextAlign.center),
    );
  }
}

final class _StoreNotice extends StatelessWidget {
  const _StoreNotice({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final stacked =
        MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final message = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: ElevenwardColors.amber),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
    return BroadcastPanel(
      accent: ElevenwardColors.amber,
      child: onRetry == null
          ? message
          : stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                message,
                const SizedBox(height: ElevenwardSpacing.xs),
                TextButton(
                  onPressed: onRetry,
                  child: Text(uiCopy(locale, 'retryStore')),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: ElevenwardColors.amber,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
                TextButton(
                  onPressed: onRetry,
                  child: Text(uiCopy(locale, 'retryStore')),
                ),
              ],
            ),
    );
  }
}

final class _OutcomeNotice extends StatelessWidget {
  const _OutcomeNotice({required this.outcome});

  final PurchaseUiOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final (icon, color, text) = switch (outcome) {
      PurchaseUiOutcome.purchased => (
        Icons.check_circle_outline_rounded,
        ElevenwardColors.grass,
        uiCopy(locale, 'owned'),
      ),
      PurchaseUiOutcome.cancelled => (
        Icons.cancel_outlined,
        ElevenwardColors.amber,
        uiCopy(locale, 'purchaseCancelled'),
      ),
      PurchaseUiOutcome.failed => (
        Icons.error_outline_rounded,
        ElevenwardColors.coral,
        uiCopy(locale, 'purchaseFailed'),
      ),
      PurchaseUiOutcome.restored => (
        Icons.restore_rounded,
        ElevenwardColors.sky,
        uiCopy(locale, 'purchasesRestored'),
      ),
    };
    return BroadcastPanel(
      accent: color,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _title(String locale, GamePassId id) => switch (id) {
  GamePassId.vip => uiCopy(locale, 'vipStarter'),
  GamePassId.doubleDevelopment => uiCopy(locale, 'doubleDevelopment'),
  GamePassId.doubleMoney => uiCopy(locale, 'doubleMoney'),
  GamePassId.allAccess => uiCopy(locale, 'allAccess'),
};

String _benefit(String locale, GamePassId id) => switch (id) {
  GamePassId.vip => uiCopy(locale, 'vipBenefits'),
  GamePassId.doubleDevelopment => uiCopy(locale, 'developmentBenefits'),
  GamePassId.doubleMoney => uiCopy(locale, 'moneyBenefits'),
  GamePassId.allAccess => uiCopy(locale, 'allAccessBenefits'),
};

String _stackLabel(String locale, GamePassId id) => switch (id) {
  GamePassId.allAccess => uiCopy(locale, 'fullStackIncluded'),
  GamePassId.vip => uiCopy(locale, 'stacksWithTwoX'),
  GamePassId.doubleDevelopment ||
  GamePassId.doubleMoney => uiCopy(locale, 'stacksWithVip'),
};

String _stateLabel(String locale, ShopProductUiState state) => switch (state) {
  ShopProductUiState.loading ||
  ShopProductUiState.processing => uiCopy(locale, 'processing'),
  ShopProductUiState.available => uiCopy(locale, 'buyPermanent'),
  ShopProductUiState.owned => uiCopy(locale, 'owned'),
  ShopProductUiState.includedWithAllAccess => uiCopy(
    locale,
    'includedAllAccess',
  ),
  ShopProductUiState.unavailable => uiCopy(locale, 'unavailable'),
};

IconData _icon(GamePassId id) => switch (id) {
  GamePassId.vip => Icons.workspace_premium_rounded,
  GamePassId.doubleDevelopment => Icons.trending_up_rounded,
  GamePassId.doubleMoney => Icons.payments_rounded,
  GamePassId.allAccess => Icons.all_inclusive_rounded,
};

Color _accent(GamePassId id) => switch (id) {
  GamePassId.vip => ElevenwardColors.sky,
  GamePassId.doubleDevelopment => ElevenwardColors.grass,
  GamePassId.doubleMoney => ElevenwardColors.amber,
  GamePassId.allAccess => const Color(0xFFD6B7FF),
};
