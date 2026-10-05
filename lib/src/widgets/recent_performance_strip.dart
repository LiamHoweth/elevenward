import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n_context.dart';
import '../theme.dart';

/// The journal is committed newest first. Preserve that order: postseason
/// matchdays can restart at one, so sorting the week would reorder appearances.
List<MatchJournalEntry> recentPlayedMatches(CareerSnapshot career) => career
    .matchJournal
    .where((match) => match.appeared)
    .take(5)
    .toList(growable: false)
    .reversed
    .toList(growable: false);

final class RecentPerformanceStrip extends StatelessWidget {
  const RecentPerformanceStrip({super.key, required this.career});

  final CareerSnapshot career;

  @override
  Widget build(BuildContext context) {
    final matches = recentPlayedMatches(career);
    final locale = contentLocale(context);
    final formatter = NumberFormat('0.0', locale);
    final title = _copy(locale, 'title');
    final description = _copy(
      locale,
      matches.isEmpty
          ? 'empty'
          : matches.length == 1
          ? 'one'
          : 'history',
      {'count': matches.length},
    );
    final labels = [
      for (var i = 0; i < matches.length; i++)
        _copy(locale, 'appearance', {
          'index': i + 1,
          'season': matches[i].season,
          'week': matches[i].week,
          'opponent': matches[i].opponentName,
          'rating': formatter.format(matches[i].rating),
        }),
    ];
    final palette = Theme.of(context).brightness == Brightness.dark
        ? ElevenwardPalette.dark
        : ElevenwardPalette.light;

    return Semantics(
      key: const Key('recent-performance-strip'),
      container: true,
      label: [title, description, ...labels].join('. '),
      child: ExcludeSemantics(
        child: BroadcastPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(description, style: TextStyle(color: palette.muted)),
              if (matches.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: CustomPaint(
                    key: const Key('recent-rating-trend'),
                    painter: _RatingTrendPainter(
                      ratings: [for (final match in matches) match.rating],
                      lineColor: palette.action,
                      guideColor: palette.line,
                      surfaceColor: palette.panel,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context)
                        .scale(14);
                    final wrap =
                        constraints.maxWidth / matches.length < textScale * 2.9;
                    final values = [
                      for (var i = 0; i < matches.length; i++)
                        Text(
                          wrap
                              ? '${i + 1} · ${formatter.format(matches[i].rating)}'
                              : formatter.format(matches[i].rating),
                          key: Key('recent-rating-${matches[i].id}'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.text,
                            fontWeight: i == matches.length - 1
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                    ];
                    if (wrap) {
                      return Wrap(spacing: 16, runSpacing: 8, children: values);
                    }
                    return Row(
                      children: [
                        for (final value in values) Expanded(child: value),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  _copy(locale, 'scale'),
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _RatingTrendPainter extends CustomPainter {
  const _RatingTrendPainter({
    required this.ratings,
    required this.lineColor,
    required this.guideColor,
    required this.surfaceColor,
  });

  final List<double> ratings;
  final Color lineColor, guideColor, surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 5.0;
    final guide = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    for (final y in [inset, size.height - inset]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }
    final points = [
      for (var i = 0; i < ratings.length; i++)
        Offset(
          size.width * (i + .5) / ratings.length,
          inset +
              (1 - ratings[i].clamp(0, 10) / 10) * (size.height - inset * 2),
        ),
    ];
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 3.5, Paint()..color = surfaceColor);
      canvas.drawCircle(
        points[i],
        i == points.length - 1 ? 3.5 : 2.5,
        Paint()..color = lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(_RatingTrendPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.guideColor != guideColor ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.ratings.length != ratings.length ||
      Iterable<int>.generate(ratings.length)
          .any((index) => oldDelegate.ratings[index] != ratings[index]);
}

String _copy(
  String locale,
  String key, [
  Map<String, Object> values = const {},
]) {
  var text = (_strings[locale] ?? _strings['en']!)[key]!;
  for (final entry in values.entries) {
    text = text.replaceAll('{${entry.key}}', '${entry.value}');
  }
  return text;
}

const _strings = {
  'en': {
    'title': 'Recent match ratings',
    'empty': 'Ratings appear here after your next appearance.',
    'one': 'One recorded appearance. Play another match to see a trend.',
    'history': 'Last {count} appearances · oldest → latest',
    'scale': 'Ratings out of 10',
    'appearance': 'Appearance {index}, season {season}, week {week}, against {opponent}: {rating} out of 10',
  },
  'es': {
    'title': 'Valoraciones recientes',
    'empty': 'Las valoraciones aparecerán tras tu próxima participación.',
    'one': 'Una participación registrada. Juega otro partido para ver la tendencia.',
    'history': 'Últimas {count} participaciones · anterior → reciente',
    'scale': 'Valoraciones sobre 10',
    'appearance': 'Participación {index}, temporada {season}, semana {week}, contra {opponent}: {rating} sobre 10',
  },
  'pt-BR': {
    'title': 'Notas recentes',
    'empty': 'As notas aparecem aqui após sua próxima participação.',
    'one': 'Uma participação registrada. Jogue outra partida para ver a tendência.',
    'history': 'Últimas {count} participações · antiga → recente',
    'scale': 'Notas de 0 a 10',
    'appearance': 'Participação {index}, temporada {season}, semana {week}, contra {opponent}: {rating} de 10',
  },
  'fr': {
    'title': 'Notes récentes',
    'empty': 'Les notes apparaîtront après votre prochaine participation.',
    'one': 'Une participation enregistrée. Jouez un autre match pour voir la tendance.',
    'history': 'Les {count} dernières participations · ancienne → récente',
    'scale': 'Notes sur 10',
    'appearance': 'Participation {index}, saison {season}, semaine {week}, contre {opponent} : {rating} sur 10',
  },
};
