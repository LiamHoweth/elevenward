import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../l10n_context.dart';
import '../theme.dart';
import 'identity_badge.dart';

final class CompactPlayerHud extends StatelessWidget {
  const CompactPlayerHud({
    super.key,
    required this.career,
    required this.avatarId,
    this.actions = const [],
  });

  final CareerSnapshot career;
  final String avatarId;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final accessible = MediaQuery.textScalerOf(context).scale(14) >= 19;
    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerIdentityBadge(
          playerName: career.player.name,
          avatarId: avatarId,
          size: 36,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                career.player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ElevenwardColors.cream,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                career.clubName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ElevenwardColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final facts = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            context.l10n.seasonWeek(career.season, career.week),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: const TextStyle(
              color: ElevenwardColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: '£${career.player.money}',
          child: Text(
            '£${career.player.money}',
            maxLines: 1,
            style: const TextStyle(
              color: ElevenwardColors.grass,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ...actions,
      ],
    );

    return Material(
      key: const Key('compact-player-hud'),
      color: ElevenwardColors.deep,
      child: Container(
        constraints: BoxConstraints(minHeight: accessible ? 78 : 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: ElevenwardColors.line)),
        ),
        child: accessible
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: facts),
                ],
              )
            : Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 8),
                  Flexible(child: facts),
                ],
              ),
      ),
    );
  }
}
