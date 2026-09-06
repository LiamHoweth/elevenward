import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';

final class LifeScreen extends StatefulWidget {
  const LifeScreen({super.key, required this.controller, this.contentCatalog});
  final AppController controller;
  final ContentCatalog? contentCatalog;

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

final class _LifeScreenState extends State<LifeScreen> {
  static const _engine = CareerEngine();
  LifestyleCategory _category = LifestyleCategory.home;

  @override
  Widget build(BuildContext context) {
    final career = widget.controller.activeCareer!;
    final locale = contentLocale(context);
    final items = (widget.contentCatalog ?? buildLaunchContent()).lifestyleItems
        .where((item) => item.category == _category);
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          pinned: true,
          title: Text(context.l10n.life),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '£${career.player.money}',
                  style: const TextStyle(
                    color: ElevenwardColors.grass,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            child: _CareerTeamCard(
              career: career,
              eligible: _engine.isNationalTeamEligible(career),
              hasInvitation: _engine.hasNationalTeamInvitation(career),
              onCallUpDecision: _decideCallUp,
              onChooseAgent: _chooseAgent,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Text(
              uiCopy(locale, 'lifestyleMarket').toUpperCase(),
              style: const TextStyle(
                color: ElevenwardColors.grass,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .9,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: SegmentedButton<LifestyleCategory>(
              segments: LifestyleCategory.values
                  .map(
                    (value) => ButtonSegment(
                      value: value,
                      icon: Icon(_icon(value)),
                      tooltip: _title(value.name),
                    ),
                  )
                  .toList(),
              selected: {_category},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _category = value.single),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final item = items.elementAt(index);
              final owned = career.ownedItemIds.contains(item.id);
              final equipped =
                  career.equippedItemIds[item.category.name] == item.id;
              final affordable = career.player.money >= item.price;
              return _LifeItem(
                item: item,
                locale: locale,
                owned: owned,
                equipped: equipped,
                affordable: affordable,
                onBuy: owned || !affordable ? null : () => _buy(item),
                onEquip: owned && !equipped ? () => _equip(item) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _buy(LifestyleItemDefinition item) async {
    final current = widget.controller.activeCareer!;
    final next = _engine.purchaseLifestyleItem(
      snapshot: current,
      item: item,
      updatedAt: DateTime.now().toUtc(),
    );
    await widget.controller.saveCareer(next, eventType: 'lifestyle_purchase');
    if (mounted) setState(() {});
  }

  Future<void> _chooseAgent(AgentDefinition agent) async {
    final current = widget.controller.activeCareer!;
    final next = _engine.chooseAgent(
      snapshot: current,
      agentId: agent.id,
      updatedAt: DateTime.now().toUtc(),
    );
    if (identical(next, current)) return;
    await widget.controller.saveCareer(next, eventType: 'agent_changed');
    if (mounted) setState(() {});
  }

  Future<void> _decideCallUp(bool accept) async {
    final current = widget.controller.activeCareer!;
    final next = _engine.decideNationalTeamCallUp(
      snapshot: current,
      accept: accept,
      updatedAt: DateTime.now().toUtc(),
    );
    await widget.controller.saveCareer(
      next,
      eventType: accept
          ? 'national_callup_accepted'
          : 'national_callup_declined',
    );
    if (mounted) setState(() {});
  }

  Future<void> _equip(LifestyleItemDefinition item) async {
    final current = widget.controller.activeCareer!;
    final next = _engine.equipLifestyleItem(
      snapshot: current,
      item: item,
      updatedAt: DateTime.now().toUtc(),
    );
    await widget.controller.saveCareer(next, eventType: 'lifestyle_equipped');
    if (mounted) setState(() {});
  }

  IconData _icon(LifestyleCategory category) => switch (category) {
    LifestyleCategory.home => Icons.home_outlined,
    LifestyleCategory.transportation => Icons.directions_car_outlined,
    LifestyleCategory.style => Icons.checkroom_outlined,
    LifestyleCategory.wellness => Icons.spa_outlined,
  };

  String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}

final class _CareerTeamCard extends StatelessWidget {
  const _CareerTeamCard({
    required this.career,
    required this.eligible,
    required this.hasInvitation,
    required this.onCallUpDecision,
    required this.onChooseAgent,
  });

  final CareerSnapshot career;
  final bool eligible;
  final bool hasInvitation;
  final ValueChanged<bool> onCallUpDecision;
  final ValueChanged<AgentDefinition> onChooseAgent;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final accepted = career.nationalTeam.acceptedFor(career.season);
    final declined = career.nationalTeam.declinedFor(career.season);
    final nationalStatus = accepted
        ? uiCopy(locale, 'nationalCallUpAccepted')
        : declined
        ? uiCopy(locale, 'nationalCallUpDeclined')
        : hasInvitation
        ? uiCopy(locale, 'nationalCallUpArrived')
        : eligible
        ? uiCopy(locale, 'nationalEligible')
        : uiCopy(locale, 'nationalNotEligible');
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: ElevenwardColors.panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: ElevenwardColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiCopy(locale, 'careerTeam').toUpperCase(),
            style: const TextStyle(
              color: ElevenwardColors.grass,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: ElevenwardColors.sky),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  nationalStatus,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Icon(
                accepted
                    ? Icons.verified_rounded
                    : hasInvitation
                    ? Icons.mark_email_unread_outlined
                    : Icons.track_changes,
                color: eligible || hasInvitation
                    ? ElevenwardColors.grass
                    : ElevenwardColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${uiCopy(locale, 'nationalRecord')}: ${career.nationalTeam.caps} ${uiCopy(locale, 'caps')} · ${career.nationalTeam.goals} ${uiCopy(locale, 'goals')} · ${career.nationalTeam.assists} ${uiCopy(locale, 'assists')}',
            style: const TextStyle(color: ElevenwardColors.muted, fontSize: 12),
          ),
          if (hasInvitation) ...[
            const SizedBox(height: 12),
            Text(
              uiCopy(locale, 'nationalCallUpBody'),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onCallUpDecision(false),
                    child: Text(uiCopy(locale, 'decline')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onCallUpDecision(true),
                    icon: const Icon(Icons.flag_rounded),
                    label: Text(uiCopy(locale, 'acceptCallUp')),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(
                Icons.handshake_outlined,
                color: ElevenwardColors.amber,
              ),
              const SizedBox(width: 9),
              Text(
                '${uiCopy(locale, 'activeSponsors')}: ${career.sponsorIds.length}',
              ),
            ],
          ),
          const Divider(height: 28),
          Text(
            uiCopy(locale, 'chooseAgent'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: career.activeAgentId,
            onChanged: (value) {
              if (value == null) return;
              onChooseAgent(
                launchAgents.firstWhere((agent) => agent.id == value),
              );
            },
            child: Column(
              children: launchAgents
                  .map(
                    (agent) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: agent.id,
                      title: Text(localizedAgentName(locale, agent.id)),
                      subtitle: Text(localizedAgentDescription(locale, agent)),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

final class _LifeItem extends StatelessWidget {
  const _LifeItem({
    required this.item,
    required this.locale,
    required this.owned,
    required this.equipped,
    required this.affordable,
    required this.onBuy,
    required this.onEquip,
  });

  final LifestyleItemDefinition item;
  final String locale;
  final bool owned;
  final bool equipped;
  final bool affordable;
  final VoidCallback? onBuy;
  final VoidCallback? onEquip;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: ElevenwardColors.panel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: owned ? ElevenwardColors.grass : ElevenwardColors.line,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _rarityColor(item.rarity).withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.diamond_outlined, color: _rarityColor(item.rarity)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name.forLocale(locale),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                item.description.forLocale(locale),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                '£${item.price}',
                style: const TextStyle(
                  color: ElevenwardColors.amber,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (equipped)
          Text(
            uiCopy(locale, 'equipped').toUpperCase(),
            style: const TextStyle(
              color: ElevenwardColors.grass,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          )
        else if (owned)
          TextButton(onPressed: onEquip, child: Text(uiCopy(locale, 'equip')))
        else
          IconButton.filledTonal(
            tooltip: affordable
                ? context.l10n.buy
                : context.l10n.notEnoughMoney,
            onPressed: onBuy,
            icon: const Icon(Icons.add_shopping_cart_rounded),
          ),
      ],
    ),
  );

  Color _rarityColor(ItemRarity rarity) => switch (rarity) {
    ItemRarity.common => ElevenwardColors.muted,
    ItemRarity.uncommon => ElevenwardColors.grass,
    ItemRarity.rare => ElevenwardColors.sky,
    ItemRarity.epic => const Color(0xFFBA9BFF),
    ItemRarity.legendary => ElevenwardColors.amber,
  };
}
