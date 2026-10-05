import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../feature_copy.dart';
import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';
import '../widgets/identity_badge.dart';

enum LifeDestination {
  attention,
  agent,
  sponsorships,
  relationships,
  market,
  collection,
  nationalTeam,
}

final class LifeScreen extends StatefulWidget {
  const LifeScreen({super.key, required this.controller, this.contentCatalog});

  final AppController controller;
  final ContentCatalog? contentCatalog;

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

final class _LifeScreenState extends State<LifeScreen> {
  static const _engine = CareerEngine();

  @override
  Widget build(BuildContext context) {
    final career = widget.controller.activeCareer!;
    final locale = contentLocale(context);
    final activeAgent = launchAgents.firstWhere(
      (agent) => agent.id == career.activeAgentId,
      orElse: () => launchAgents.first,
    );
    final sponsorIncome = career.sponsorContracts.fold<int>(
      0,
      (total, contract) => total + contract.weeklyPayout,
    );
    final invitation = _engine.hasNationalTeamInvitation(
      career,
      definition: widget.contentCatalog?.world,
    );

    return ListView(
      key: const Key('life-action-list'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
      children: [
        _LifePulseStrip(
          monthlySalary: career.contract.weeklyWage * 4,
          sponsorIncome: sponsorIncome,
          agentFee: activeAgent.monthlyFee,
          wellness: career.wellness,
        ),
        if (invitation) ...[
          const SizedBox(height: 10),
          _AttentionTile(
            title: uiCopy(locale, 'lifeAttention'),
            body: uiCopy(locale, 'nationalCallUpArrived'),
            onTap: () => _open(LifeDestination.nationalTeam),
          ),
        ],
        const SizedBox(height: 16),
        _SectionLabel(uiCopy(locale, 'lifeActions')),
        const SizedBox(height: 8),
        Material(
          color: ElevenwardColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ElevenwardRadii.card),
            side: BorderSide(color: ElevenwardColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _LifeActionTile(
                key: const Key('life-action-agent'),
                leading: RoleIconBadge(
                  icon: _agentIcon(activeAgent.id),
                  label: localizedAgentName(locale, activeAgent.id),
                  size: 48,
                  color: _agentColor(activeAgent.id),
                ),
                title: context.l10n.agent,
                subtitle: localizedAgentName(locale, activeAgent.id),
                badge: activeAgent.monthlyFee == 0
                    ? uiCopy(locale, 'free')
                    : '£${activeAgent.monthlyFee}/mo',
                onTap: () => _open(LifeDestination.agent),
              ),
              const Divider(height: 1),
              _LifeActionTile(
                key: const Key('life-action-sponsors'),
                leading: RoleIconBadge(
                  icon: Icons.campaign_outlined,
                  label: context.l10n.sponsors,
                  size: 48,
                  color: ElevenwardColors.amber,
                ),
                title: context.l10n.sponsors,
                subtitle: uiCopy(locale, 'sponsorsBody'),
                badge: '${career.sponsorContracts.length}',
                onTap: () => _open(LifeDestination.sponsorships),
              ),
              const Divider(height: 1),
              _LifeActionTile(
                key: const Key('life-action-relationships'),
                leading: RoleIconBadge(
                  icon: Icons.groups_2_outlined,
                  label: context.l10n.relationships,
                  size: 48,
                  color: ElevenwardColors.sky,
                ),
                title: context.l10n.relationships,
                subtitle: uiCopy(locale, 'relationshipsBody'),
                onTap: () => _open(LifeDestination.relationships),
              ),
              const Divider(height: 1),
              _LifeActionTile(
                key: const Key('life-action-market'),
                leading: _ActionIcon(
                  icon: Icons.storefront_outlined,
                  color: ElevenwardColors.amber,
                ),
                title: uiCopy(locale, 'lifestyleMarket'),
                subtitle: uiCopy(locale, 'marketBody'),
                onTap: () => _open(LifeDestination.market),
              ),
              const Divider(height: 1),
              _LifeActionTile(
                key: const Key('life-action-collection'),
                leading: _ActionIcon(
                  icon: Icons.inventory_2_outlined,
                  color: ElevenwardColors.sky,
                ),
                title: uiCopy(locale, 'lifeCollection'),
                subtitle: uiCopy(locale, 'collectionBody'),
                badge: '${career.ownedItemIds.length}',
                onTap: () => _open(LifeDestination.collection),
              ),
              const Divider(height: 1),
              _LifeActionTile(
                key: const Key('life-action-national-team'),
                leading: _ActionIcon(
                  icon: Icons.flag_outlined,
                  color: ElevenwardColors.grass,
                ),
                title: context.l10n.nationalTeam,
                subtitle: _nationalStatus(
                  career,
                  locale,
                  definition: widget.contentCatalog?.world,
                ),
                badge: invitation ? '!' : '${career.nationalTeam.caps}',
                onTap: () => _open(LifeDestination.nationalTeam),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _open(LifeDestination destination) async {
    final page = switch (destination) {
      LifeDestination.attention || LifeDestination.nationalTeam =>
        _NationalTeamScreen(controller: widget.controller),
      LifeDestination.agent => _AgentScreen(controller: widget.controller),
      LifeDestination.sponsorships => _SponsorScreen(
        controller: widget.controller,
      ),
      LifeDestination.relationships => _RelationshipsScreen(
        controller: widget.controller,
      ),
      LifeDestination.market => _LifestyleHubScreen(
        controller: widget.controller,
        contentCatalog: widget.contentCatalog,
        collection: false,
      ),
      LifeDestination.collection => _LifestyleHubScreen(
        controller: widget.controller,
        contentCatalog: widget.contentCatalog,
        collection: true,
      ),
    };
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }
}

final class _LifePulseStrip extends StatelessWidget {
  const _LifePulseStrip({
    required this.monthlySalary,
    required this.sponsorIncome,
    required this.agentFee,
    required this.wellness,
  });

  final int monthlySalary;
  final int sponsorIncome;
  final int agentFee;
  final int wellness;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final values = [
      (
        Icons.payments_outlined,
        uiCopy(locale, 'monthlyIncome'),
        '£$monthlySalary',
        ElevenwardColors.grass,
      ),
      (
        Icons.campaign_outlined,
        uiCopy(locale, 'weeklySponsors'),
        '+£$sponsorIncome',
        ElevenwardColors.amber,
      ),
      (
        Icons.handshake_outlined,
        context.l10n.agent,
        '−£$agentFee',
        ElevenwardColors.sky,
      ),
      (
        Icons.self_improvement_rounded,
        uiCopy(locale, 'wellness'),
        '$wellness',
        ElevenwardColors.coral,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(12) >= 17;
        final columns = largeText ? 2 : 4;
        // The border consumes one logical pixel on each side of the Wrap.
        final width = (constraints.maxWidth - 2) / columns;
        return Container(
          key: const Key('life-pulse-strip'),
          decoration: BoxDecoration(
            color: ElevenwardColors.panel,
            borderRadius: BorderRadius.circular(ElevenwardRadii.card),
            border: Border.all(color: ElevenwardColors.sky),
          ),
          clipBehavior: Clip.antiAlias,
          child: Wrap(
            children: values
                .map(
                  (value) => SizedBox(
                    width: width,
                    child: _PulseMetric(
                      icon: value.$1,
                      label: value.$2,
                      value: value.$3,
                      color: value.$4,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }
}

final class _PulseMetric extends StatelessWidget {
  const _PulseMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ElevenwardColors.muted,
              fontSize: 9,
              height: 1.15,
            ),
          ),
        ],
      ),
    ),
  );
}

final class _AttentionTile extends StatelessWidget {
  const _AttentionTile({
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ElevenwardColors.amber.withValues(alpha: .12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: ElevenwardColors.amber),
    ),
    child: ListTile(
      minVerticalPadding: 10,
      leading: Icon(
        Icons.notification_important_outlined,
        color: ElevenwardColors.amber,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(body),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

final class _LifeActionTile extends StatelessWidget {
  const _LifeActionTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w900),
    );
    final detail = Text(
      subtitle,
      style: TextStyle(color: ElevenwardColors.muted, fontSize: 11),
    );
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: ElevenwardColors.grassDark,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                color: ElevenwardColors.grass,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        const SizedBox(width: 3),
        const Icon(Icons.chevron_right_rounded),
      ],
    );
    if (MediaQuery.textScalerOf(context).scale(14) >= 21) {
      return Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [leading, const Spacer(), trailing]),
                const SizedBox(height: 10),
                heading,
                const SizedBox(height: 5),
                detail,
              ],
            ),
          ),
        ),
      );
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      minVerticalPadding: 8,
      leading: leading,
      title: heading,
      subtitle: detail,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

final class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Icon(icon, color: color),
  );
}

final class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(
      color: ElevenwardColors.grass,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: .9,
    ),
  );
}

final class _AgentScreen extends StatefulWidget {
  const _AgentScreen({required this.controller});

  final AppController controller;

  @override
  State<_AgentScreen> createState() => _AgentScreenState();
}

final class _AgentScreenState extends State<_AgentScreen> {
  static const _engine = CareerEngine();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final career = widget.controller.activeCareer!;
    final locale = contentLocale(context);
    return Scaffold(
      key: const Key('life-destination-agent'),
      appBar: AppBar(title: Text(context.l10n.agent)),
      body: ListView.separated(
        key: const Key('agent-options-list'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        itemCount: launchAgents.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final agent = launchAgents[index];
          final active = agent.id == career.activeAgentId;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ElevenwardColors.panel,
              borderRadius: BorderRadius.circular(ElevenwardRadii.card),
              border: Border.all(
                color: active ? ElevenwardColors.grass : ElevenwardColors.line,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    RoleIconBadge(
                      icon: _agentIcon(agent.id),
                      label: localizedAgentName(locale, agent.id),
                      size: 64,
                      color: _agentColor(agent.id),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizedAgentName(locale, agent.id),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            agent.monthlyFee == 0
                                ? uiCopy(locale, 'free')
                                : '£${agent.monthlyFee} ${uiCopy(locale, 'monthlyRetainer')}',
                            style: TextStyle(
                              color: ElevenwardColors.amber,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (active)
                      Icon(
                        Icons.verified_rounded,
                        color: ElevenwardColors.grass,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  localizedAgentDescription(locale, agent),
                  style: TextStyle(color: ElevenwardColors.muted),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: active || _busy ? null : () => _confirm(agent),
                  icon: Icon(
                    active ? Icons.check_rounded : Icons.handshake_outlined,
                  ),
                  label: Text(
                    active
                        ? uiCopy(locale, 'currentAgent')
                        : uiCopy(locale, 'selectAgent'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirm(AgentDefinition agent) async {
    if (_busy) return;
    final locale = contentLocale(context);
    final current = widget.controller.activeCareer!;
    final generation = widget.controller.activeCareerGeneration;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(uiCopy(locale, 'changeAgent')),
          content: Text(
            '${localizedAgentName(locale, agent.id)} · '
            '${agent.monthlyFee == 0 ? uiCopy(locale, 'free') : '£${agent.monthlyFee} ${uiCopy(locale, 'monthlyRetainer')}'}\n\n'
            '${uiCopy(locale, 'changeAgentBody')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.close),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(uiCopy(locale, 'selectAgent')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final next = _engine.chooseAgent(
        snapshot: current,
        agentId: agent.id,
        updatedAt: DateTime.now().toUtc(),
      );
      if (!identical(next, current)) {
        await widget.controller.saveCareer(
          next,
          eventType: 'agent_changed',
          expectedGeneration: generation,
          expectedCareerId: current.careerId,
          expectedRevision: current.revision,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.errorTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class _SponsorScreen extends StatelessWidget {
  const _SponsorScreen({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final career = controller.activeCareer!;
    final locale = contentLocale(context);
    final total = career.sponsorContracts.fold<int>(
      0,
      (sum, contract) => sum + contract.weeklyPayout,
    );
    return Scaffold(
      key: const Key('life-destination-sponsorships'),
      appBar: AppBar(title: Text(context.l10n.sponsors)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [
          BroadcastPanel(
            accent: ElevenwardColors.amber,
            child: Row(
              children: [
                RoleIconBadge(
                  icon: Icons.campaign_outlined,
                  label: context.l10n.sponsors,
                  size: 64,
                  color: ElevenwardColors.amber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiCopy(locale, 'weeklySponsors'),
                        style: TextStyle(color: ElevenwardColors.muted),
                      ),
                      Text(
                        '+£$total',
                        style: TextStyle(
                          color: ElevenwardColors.amber,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (career.sponsorContracts.isEmpty)
            BroadcastPanel(child: Text(uiCopy(locale, 'noActiveSponsors')))
          else
            ...career.sponsorContracts.indexed.map((entry) {
              final contract = entry.$2;
              final threshold = RegExp(r'(\d+)$')
                  .firstMatch(contract.obligation)
                  ?.group(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _DetailCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.handshake_outlined,
                      color: ElevenwardColors.amber,
                    ),
                    title: Text(
                      '${uiCopy(locale, 'sponsorContract')} ${entry.$1 + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${contract.weeksRemaining} ${uiCopy(locale, 'weeksRemaining')}\n'
                      '${uiCopy(locale, 'maintainReputation')}${threshold == null ? '' : ' $threshold+'}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '+£${contract.weeklyPayout}',
                      style: TextStyle(
                        color: ElevenwardColors.grass,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

final class _RelationshipsScreen extends StatelessWidget {
  const _RelationshipsScreen({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final career = controller.activeCareer!;
    final locale = contentLocale(context);
    final relationships = <(String, String, int, String)>[
      (
        'manager',
        uiCopy(locale, 'manager'),
        career.relationships.manager,
        uiCopy(locale, 'managerConsequence'),
      ),
      (
        'teammates',
        uiCopy(locale, 'teammates'),
        career.relationships.teammates,
        uiCopy(locale, 'teammateConsequence'),
      ),
      (
        'agent',
        context.l10n.agent,
        career.relationships.agent,
        uiCopy(locale, 'agentConsequence'),
      ),
      (
        'family',
        uiCopy(locale, 'family'),
        career.relationships.family,
        uiCopy(locale, 'familyConsequence'),
      ),
      (
        'community',
        uiCopy(locale, 'community'),
        career.relationships.community,
        uiCopy(locale, 'communityConsequence'),
      ),
    ];
    return Scaffold(
      key: const Key('life-destination-relationships'),
      appBar: AppBar(title: Text(context.l10n.relationships)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        itemCount: relationships.length,
        separatorBuilder: (_, _) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          final value = relationships[index];
          return _DetailCard(
            child: Row(
              children: [
                RoleIconBadge(
                  icon: _relationshipIcon(value.$1),
                  label: value.$2,
                  size: 58,
                  color: _relationshipColor(value.$3),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              value.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '${value.$3}/100',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: value.$3 / 100,
                          minHeight: 7,
                          backgroundColor: ElevenwardColors.line,
                          color: _relationshipColor(value.$3),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        value.$4,
                        style: TextStyle(
                          color: ElevenwardColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _relationshipColor(int score) => score >= 70
      ? ElevenwardColors.grass
      : score >= 40
      ? ElevenwardColors.amber
      : ElevenwardColors.coral;
}

final class _LifestyleHubScreen extends StatelessWidget {
  const _LifestyleHubScreen({
    required this.controller,
    required this.contentCatalog,
    required this.collection,
  });

  final AppController controller;
  final ContentCatalog? contentCatalog;
  final bool collection;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final career = controller.activeCareer!;
    final catalog = contentCatalog ?? buildLaunchContent();
    final market = const LifestyleMarketEngine().stockFor(career, catalog);
    return Scaffold(
      key: Key(
        collection ? 'life-destination-collection' : 'life-destination-market',
      ),
      appBar: AppBar(
        title: Text(
          collection
              ? uiCopy(locale, 'lifeCollection')
              : uiCopy(locale, 'lifestyleMarket'),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        itemCount: LifestyleCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          final category = LifestyleCategory.values[index];
          final allItems = catalog.lifestyleItems
              .where((item) => item.category == category)
              .toList(growable: false);
          final owned = allItems
              .where((item) => career.ownedItemIds.contains(item.id))
              .length;
          final weeklyItems = market.forCategory(category);
          final count = collection ? owned : weeklyItems.length;
          return Material(
            key: Key('lifestyle-shop-${category.name}'),
            color: ElevenwardColors.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(color: ElevenwardColors.line),
            ),
            child: ListTile(
              minVerticalPadding: 12,
              leading: _ActionIcon(
                icon: _categoryIcon(category),
                color: _categoryColor(category),
              ),
              title: Text(
                _categoryTitle(locale, category),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                collection
                    ? '$owned ${uiCopy(locale, 'itemsOwned')}'
                    : '${weeklyItems.length} ${uiCopy(locale, 'weeklyListings')} · '
                          '$owned ${uiCopy(locale, 'itemsOwned')}\n'
                          '${uiCopy(locale, 'refreshesNextWeek')}',
              ),
              isThreeLine: !collection,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      color: ElevenwardColors.grass,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => _LifestyleItemsScreen(
                    controller: controller,
                    catalog: catalog,
                    category: category,
                    collection: collection,
                    weeklyItems: collection ? null : weeklyItems,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

final class _LifestyleItemsScreen extends StatefulWidget {
  const _LifestyleItemsScreen({
    required this.controller,
    required this.catalog,
    required this.category,
    required this.collection,
    required this.weeklyItems,
  });

  final AppController controller;
  final ContentCatalog catalog;
  final LifestyleCategory category;
  final bool collection;
  final List<LifestyleItemDefinition>? weeklyItems;

  @override
  State<_LifestyleItemsScreen> createState() => _LifestyleItemsScreenState();
}

final class _LifestyleItemsScreenState extends State<_LifestyleItemsScreen> {
  static const _engine = CareerEngine();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final career = widget.controller.activeCareer!;
    final items = widget.collection
        ? widget.catalog.lifestyleItems
              .where(
                (item) =>
                    item.category == widget.category &&
                    career.ownedItemIds.contains(item.id),
              )
              .toList(growable: false)
        : widget.weeklyItems ?? const <LifestyleItemDefinition>[];
    return Scaffold(
      appBar: AppBar(title: Text(_categoryTitle(locale, widget.category))),
      body: items.isEmpty
          ? Center(child: Text(uiCopy(locale, 'emptyCollection')))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
              children: [
                _DetailCard(
                  child: Text(
                    '${featureCopy(locale, 'availableFunds')}: £${career.player.money}',
                    key: const Key('lifestyle-available-money'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 10),
                if (!widget.collection) ...[
                  _WeeklyMarketBanner(
                    season: career.season,
                    week: career.week,
                    count: items.length,
                  ),
                  const SizedBox(height: 10),
                ],
                ...items.indexed.map((entry) {
                  final item = entry.$2;
                  final owned = career.ownedItemIds.contains(item.id);
                  final equipped =
                      career.equippedItemIds[item.category.name] == item.id;
                  final affordable = career.player.money >= item.price;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.$1 == items.length - 1 ? 0 : 9,
                    ),
                    child: _LifeItem(
                      key: Key('lifestyle-listing-${item.id}'),
                      item: item,
                      locale: locale,
                      owned: owned,
                      equipped: equipped,
                      affordable: affordable,
                      onBuy: owned || !affordable || _busy
                          ? null
                          : () => _buy(item),
                      onEquip: widget.collection && owned && !equipped && !_busy
                          ? () => _equip(item)
                          : null,
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Future<void> _buy(LifestyleItemDefinition item) async {
    if (_busy) return;
    final locale = contentLocale(context);
    setState(() => _busy = true);
    try {
      final current = widget.controller.activeCareer!;
      final generation = widget.controller.activeCareerGeneration;
      final next = _engine.purchaseLifestyleItem(
        snapshot: current,
        item: item,
        updatedAt: DateTime.now().toUtc(),
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('lifestyle-purchase-review'),
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            context.l10n.buy,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '£${item.price}',
                key: const Key('lifestyle-purchase-price'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${featureCopy(locale, 'availableFunds')}: '
                '£${current.player.money} → £${next.player.money}',
                key: const Key('lifestyle-purchase-balance'),
              ),
              if (item.reputationEffect != 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${uiCopy(locale, 'reputationLong')}: '
                  '${current.player.reputation} → ${next.player.reputation}',
                ),
              ],
              if (item.wellnessEffect != 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${uiCopy(locale, 'wellness')}: '
                  '${current.wellness} → ${next.wellness}',
                ),
              ],
              const SizedBox(height: 16),
              Text(
                item.name.forLocale(locale),
                key: const Key('lifestyle-purchase-item-name'),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(item.description.forLocale(locale)),
              const SizedBox(height: 8),
              Text(
                '${uiCopy(locale, 'equipped')}: ${item.name.forLocale(locale)}',
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('lifestyle-purchase-cancel'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.close),
            ),
            FilledButton(
              key: const Key('lifestyle-purchase-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.buy),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final active = widget.controller.activeCareer;
      if (active?.careerId != current.careerId ||
          active?.revision != current.revision ||
          generation != widget.controller.activeCareerGeneration) {
        throw StateError('The reviewed career changed.');
      }
      await widget.controller.saveCareer(
        next,
        eventType: 'lifestyle_purchase',
        expectedGeneration: generation,
        expectedCareerId: current.careerId,
        expectedRevision: current.revision,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.errorTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _equip(LifestyleItemDefinition item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final current = widget.controller.activeCareer!;
      final generation = widget.controller.activeCareerGeneration;
      final next = _engine.equipLifestyleItem(
        snapshot: current,
        item: item,
        updatedAt: DateTime.now().toUtc(),
      );
      await widget.controller.saveCareer(
        next,
        eventType: 'lifestyle_equipped',
        expectedGeneration: generation,
        expectedCareerId: current.careerId,
        expectedRevision: current.revision,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.errorTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class _NationalTeamScreen extends StatefulWidget {
  const _NationalTeamScreen({required this.controller});

  final AppController controller;

  @override
  State<_NationalTeamScreen> createState() => _NationalTeamScreenState();
}

final class _NationalTeamScreenState extends State<_NationalTeamScreen> {
  static const _engine = CareerEngine();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final career = widget.controller.activeCareer!;
    final locale = contentLocale(context);
    final world = widget.controller.activeContent?.catalog.world;
    final invitation = _engine.hasNationalTeamInvitation(
      career,
      definition: world,
    );
    final eligible = _engine.isNationalTeamEligible(career, definition: world);
    return Scaffold(
      key: const Key('life-destination-national-team'),
      appBar: AppBar(title: Text(context.l10n.nationalTeam)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [
          BroadcastPanel(
            accent: invitation ? ElevenwardColors.amber : ElevenwardColors.sky,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      invitation
                          ? Icons.mark_email_unread_outlined
                          : Icons.flag_outlined,
                      color: invitation
                          ? ElevenwardColors.amber
                          : ElevenwardColors.sky,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _nationalStatus(career, locale, definition: world),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${uiCopy(locale, 'nationalRecord')}: '
                  '${career.nationalTeam.caps} ${uiCopy(locale, 'caps')} · '
                  '${career.nationalTeam.goals} ${uiCopy(locale, 'goals')} · '
                  '${career.nationalTeam.assists} ${uiCopy(locale, 'assists')}',
                  style: TextStyle(color: ElevenwardColors.muted),
                ),
                if (!eligible && !invitation) ...[
                  const SizedBox(height: 12),
                  Text(uiCopy(locale, 'nationalTeamBody')),
                ],
                if (invitation) ...[
                  const SizedBox(height: 14),
                  Text(uiCopy(locale, 'nationalCallUpBody')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _decide(false),
                          child: Text(uiCopy(locale, 'decline')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _decide(true),
                          icon: const Icon(Icons.flag_rounded),
                          label: Text(uiCopy(locale, 'acceptCallUp')),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _decide(bool accept) async {
    if (_busy) return;
    final current = widget.controller.activeCareer!;
    final generation = widget.controller.activeCareerGeneration;
    setState(() => _busy = true);
    try {
      final next = _engine.decideNationalTeamCallUp(
        snapshot: current,
        accept: accept,
        updatedAt: DateTime.now().toUtc(),
        definition: widget.controller.activeContent?.catalog.world,
      );
      await widget.controller.saveCareer(
        next,
        eventType: accept
            ? 'national_callup_accepted'
            : 'national_callup_declined',
        expectedGeneration: generation,
        expectedCareerId: current.careerId,
        expectedRevision: current.revision,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.errorTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ElevenwardColors.panel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: ElevenwardColors.line),
    ),
    child: child,
  );
}

final class _WeeklyMarketBanner extends StatelessWidget {
  const _WeeklyMarketBanner({
    required this.season,
    required this.week,
    required this.count,
  });

  final int season;
  final int week;
  final int count;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Container(
      key: const Key('weekly-market-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ElevenwardColors.panelLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ElevenwardColors.line),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 6,
        children: [
          Text(
            '${uiCopy(locale, 'season')} $season · '
            '${uiCopy(locale, 'week')} $week',
            style: TextStyle(
              color: ElevenwardColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '$count ${uiCopy(locale, 'newListings')}',
            style: TextStyle(
              color: ElevenwardColors.grass,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

final class _LifeItem extends StatelessWidget {
  const _LifeItem({
    super.key,
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
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ElevenwardColors.panel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: owned ? ElevenwardColors.grass : ElevenwardColors.line,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _rarityColor(item.rarity).withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _categoryIcon(item.category),
                color: _rarityColor(item.rarity),
              ),
            ),
            const SizedBox(width: 12),
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
                    _rarityLabel(locale, item.rarity),
                    style: TextStyle(
                      color: _rarityColor(item.rarity),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.description.forLocale(locale),
          style: TextStyle(color: ElevenwardColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(_effects(), style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              '£${item.price}',
              style: TextStyle(
                color: ElevenwardColors.amber,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (equipped)
              Text(
                uiCopy(locale, 'equipped').toUpperCase(),
                style: TextStyle(
                  color: ElevenwardColors.grass,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              )
            else if (owned)
              onEquip == null
                  ? Text(
                      uiCopy(locale, 'owned').toUpperCase(),
                      style: TextStyle(
                        color: ElevenwardColors.grass,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : TextButton(
                      onPressed: onEquip,
                      child: Text(uiCopy(locale, 'equip')),
                    )
            else
              FilledButton.tonalIcon(
                key: Key('lifestyle-buy-${item.id}'),
                onPressed: onBuy,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text(context.l10n.buy),
              ),
          ],
        ),
        if (!owned && !affordable) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.notEnoughMoney,
            style: TextStyle(color: ElevenwardColors.muted, fontSize: 12),
          ),
        ],
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

  String _effects() {
    final effects = <String>[
      if (item.reputationEffect > 0)
        '${uiCopy(locale, 'reputation')} +${item.reputationEffect}',
      if (item.wellnessEffect > 0)
        '${uiCopy(locale, 'wellness')} +${item.wellnessEffect}',
    ];
    return effects.isEmpty
        ? uiCopy(locale, 'collectionOnly')
        : effects.join(' · ');
  }
}

String _rarityLabel(String locale, ItemRarity rarity) {
  final index = switch (locale) {
    'es' => 1,
    'pt-BR' => 2,
    'fr' => 3,
    _ => 0,
  };
  return switch (rarity) {
    ItemRarity.common => const ['Common', 'Común', 'Comum', 'Commun'][index],
    ItemRarity.uncommon => const [
      'Uncommon',
      'Poco común',
      'Incomum',
      'Peu commun',
    ][index],
    ItemRarity.rare => const ['Rare', 'Raro', 'Raro', 'Rare'][index],
    ItemRarity.epic => const ['Epic', 'Épico', 'Épico', 'Épique'][index],
    ItemRarity.legendary => const [
      'Legendary',
      'Legendario',
      'Lendário',
      'Légendaire',
    ][index],
  };
}

String _nationalStatus(
  CareerSnapshot career,
  String locale, {
  WorldDefinition? definition,
}) {
  const engine = CareerEngine();
  final accepted = career.nationalTeam.acceptedFor(career.season);
  final declined = career.nationalTeam.declinedFor(career.season);
  final invitation = engine.hasNationalTeamInvitation(
    career,
    definition: definition,
  );
  final eligible = engine.isNationalTeamEligible(
    career,
    definition: definition,
  );
  return accepted
      ? uiCopy(locale, 'nationalCallUpAccepted')
      : declined
      ? uiCopy(locale, 'nationalCallUpDeclined')
      : invitation
      ? uiCopy(locale, 'nationalCallUpArrived')
      : eligible
      ? uiCopy(locale, 'nationalEligible')
      : uiCopy(locale, 'nationalNotEligible');
}

IconData _categoryIcon(LifestyleCategory category) => switch (category) {
  LifestyleCategory.home => Icons.home_outlined,
  LifestyleCategory.transportation => Icons.directions_car_outlined,
  LifestyleCategory.style => Icons.checkroom_outlined,
  LifestyleCategory.wellness => Icons.spa_outlined,
};

Color _categoryColor(LifestyleCategory category) => switch (category) {
  LifestyleCategory.home => ElevenwardColors.grass,
  LifestyleCategory.transportation => ElevenwardColors.sky,
  LifestyleCategory.style => ElevenwardColors.coral,
  LifestyleCategory.wellness => ElevenwardColors.amber,
};

IconData _agentIcon(String agentId) => switch (agentId) {
  'agent-player-first' => Icons.favorite_outline_rounded,
  'agent-global-network' => Icons.public_rounded,
  'agent-negotiator' => Icons.request_quote_outlined,
  _ => Icons.person_outline_rounded,
};

Color _agentColor(String agentId) => switch (agentId) {
  'agent-player-first' => ElevenwardColors.coral,
  'agent-global-network' => ElevenwardColors.sky,
  'agent-negotiator' => ElevenwardColors.amber,
  _ => ElevenwardColors.grass,
};

IconData _relationshipIcon(String role) => switch (role) {
  'manager' => Icons.manage_accounts_outlined,
  'teammates' => Icons.groups_2_outlined,
  'agent' => Icons.handshake_outlined,
  'family' => Icons.family_restroom_rounded,
  _ => Icons.diversity_3_outlined,
};

String _categoryTitle(String locale, LifestyleCategory category) =>
    switch (category) {
      LifestyleCategory.home => uiCopy(locale, 'lifestyleHome'),
      LifestyleCategory.transportation => uiCopy(
        locale,
        'lifestyleTransportation',
      ),
      LifestyleCategory.style => uiCopy(locale, 'lifestyleStyle'),
      LifestyleCategory.wellness => uiCopy(locale, 'lifestyleWellness'),
    };
