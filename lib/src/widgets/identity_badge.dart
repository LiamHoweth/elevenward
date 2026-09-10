import 'package:flutter/material.dart';

import '../theme.dart';

final class PlayerIdentityBadge extends StatelessWidget {
  const PlayerIdentityBadge({
    super.key,
    required this.playerName,
    required this.avatarId,
    this.size = 48,
  });

  final String playerName;
  final String avatarId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = elevenwardCosmeticColor(avatarId);
    final showStyleMark = avatarId != 'initials';
    return Semantics(
      image: true,
      label: playerName,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ElevenwardColors.panelLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _initials(playerName),
                      style: TextStyle(
                        color: ElevenwardColors.cream,
                        fontSize: size * .34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.3,
                      ),
                    ),
                  ),
                ),
              ),
              if (showStyleMark)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: size * .38,
                    height: size * .38,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ElevenwardColors.deep,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      elevenwardAvatarIcon(avatarId),
                      size: size * .21,
                      color: ElevenwardColors.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '11';
    final first = words.first.characters.first;
    final last = words.length == 1 ? '' : words.last.characters.first;
    return '$first$last'.toUpperCase();
  }
}

final class RoleIconBadge extends StatelessWidget {
  const RoleIconBadge({
    super.key,
    required this.icon,
    required this.label,
    this.color = ElevenwardColors.sky,
    this.size = 48,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(size * .3),
          border: Border.all(color: color.withValues(alpha: .55)),
        ),
        child: Icon(icon, color: color, size: size * .5),
      ),
    ),
  );
}
