import 'dart:io';
import 'dart:ui' as ui;

import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';

final class ShareCareerCard extends StatefulWidget {
  const ShareCareerCard({
    super.key,
    required this.career,
    required this.styleId,
    required this.avatarId,
  });

  final CareerSnapshot career;
  final String styleId;
  final String avatarId;

  @override
  State<ShareCareerCard> createState() => _ShareCareerCardState();
}

final class _ShareCareerCardState extends State<ShareCareerCard> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('Share card is not ready.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Share card could not be rendered.');
      final directory = await getTemporaryDirectory();
      final safeId = widget.career.careerId.replaceAll(
        RegExp('[^a-zA-Z0-9-]'),
        '',
      );
      final file = File('${directory.path}/elevenward-$safeId.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await SharePlus.instance.share(
        ShareParams(
          title: _shareLabel(
            contentLocale(context),
            'Elevenward career',
            'Carrera en Elevenward',
            'Carreira no Elevenward',
            'Carrière Elevenward',
          ),
          subject: '${widget.career.player.name} — Elevenward',
          text:
              '${widget.career.player.name} · ${widget.career.clubName} · '
              '${widget.career.player.overall} OVR',
          files: [XFile(file.path, mimeType: 'image/png')],
          fileNameOverrides: ['elevenward-career.png'],
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      RepaintBoundary(
        key: _boundaryKey,
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: _CareerCard(
            career: widget.career,
            styleId: widget.styleId,
            avatarId: widget.avatarId,
          ),
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _sharing ? null : _share,
        icon: _sharing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.ios_share_rounded),
        label: Text(context.l10n.shareCareer),
      ),
    ],
  );
}

final class _CareerCard extends StatelessWidget {
  const _CareerCard({
    required this.career,
    required this.styleId,
    required this.avatarId,
  });

  final CareerSnapshot career;
  final String styleId;
  final String avatarId;

  @override
  Widget build(BuildContext context) {
    final colors = switch (styleId) {
      'stadium' => (
        const Color(0xFF061D2B),
        ElevenwardColors.sky,
        const Color(0xFFBFE9F8),
      ),
      'editorial' => (
        const Color(0xFFF3F0E5),
        const Color(0xFFEA5741),
        ElevenwardColors.ink,
      ),
      'midnight' => (
        const Color(0xFF140B29),
        const Color(0xFFBA9BFF),
        const Color(0xFFF1EAFE),
      ),
      _ => (
        ElevenwardColors.deep,
        ElevenwardColors.grass,
        ElevenwardColors.cream,
      ),
    };
    final trophies = career.seasonHistory.fold<int>(
      0,
      (sum, season) => sum + season.trophies.length,
    );
    final seasons = career.seasonHistory.length + (career.retired ? 0 : 1);
    return Semantics(
      image: true,
      label: _shareLabel(
        contentLocale(context),
        '${career.player.name} Elevenward career summary',
        'Resumen de la carrera de ${career.player.name} en Elevenward',
        'Resumo da carreira de ${career.player.name} no Elevenward',
        'Résumé de carrière Elevenward de ${career.player.name}',
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.$1,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.$2, width: 2),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -64,
              top: -54,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.$2.withValues(alpha: .22),
                    width: 30,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: DefaultTextStyle(
                style: TextStyle(color: colors.$3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: colors.$2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.north_east_rounded,
                            color: colors.$1,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ELEVENWARD',
                          style: TextStyle(
                            color: colors.$3,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 58,
                      height: 58,
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.$2.withValues(alpha: .16),
                        border: Border.all(color: colors.$2),
                      ),
                      child: Icon(
                        elevenwardAvatarIcon(avatarId),
                        color: colors.$2,
                        size: 30,
                      ),
                    ),
                    Text(
                      career.retired
                          ? _shareLabel(
                              contentLocale(context),
                              'FINAL LEGACY',
                              'LEGADO FINAL',
                              'LEGADO FINAL',
                              'HÉRITAGE FINAL',
                            )
                          : _shareLabel(
                              contentLocale(context),
                              'CAREER IN MOTION',
                              'CARRERA EN MARCHA',
                              'CARREIRA EM CURSO',
                              'CARRIÈRE EN COURS',
                            ),
                      style: TextStyle(
                        color: colors.$2,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      career.player.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.$3,
                        fontSize: 32,
                        height: .95,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${career.clubName} · ${career.player.position.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.$3.withValues(alpha: .72),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _Metric(
                          value: '${career.player.overall}',
                          label: 'OVR',
                          color: colors.$2,
                          textColor: colors.$3,
                        ),
                        _Metric(
                          value: '$seasons',
                          label: _shareLabel(
                            contentLocale(context),
                            'SEASONS',
                            'TEMPORADAS',
                            'TEMPORADAS',
                            'SAISONS',
                          ),
                          color: colors.$2,
                          textColor: colors.$3,
                        ),
                        _Metric(
                          value: '${career.player.goals}',
                          label: uiCopy(contentLocale(context), 'goals'),
                          color: colors.$2,
                          textColor: colors.$3,
                        ),
                        _Metric(
                          value: '$trophies',
                          label: _shareLabel(
                            contentLocale(context),
                            'TROPHIES',
                            'TROFEOS',
                            'TROFÉUS',
                            'TROPHÉES',
                          ),
                          color: colors.$2,
                          textColor: colors.$3,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      career.retired
                          ? '${uiCopy(contentLocale(context), 'legacy').toUpperCase()} ${career.legacyScore}'
                          : '${uiCopy(contentLocale(context), 'season').toUpperCase()} ${career.season} · ${uiCopy(contentLocale(context), 'week').toUpperCase()} ${career.week}',
                      style: TextStyle(
                        color: colors.$3,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shareLabel(
  String locale,
  String english,
  String spanish,
  String portuguese,
  String french,
) =>
    {'en': english, 'es': spanish, 'pt-BR': portuguese, 'fr': french}[locale] ??
    english;

final class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String value;
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ],
    ),
  );
}
