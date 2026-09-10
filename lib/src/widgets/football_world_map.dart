import 'dart:convert';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';

enum FootballMapRegion {
  europe,
  southAmerica,
  northAmerica,
  asia,
  africa,
  oceania,
}

enum WorldMapFeatureState { unavailable, playable, club, home, selected }

@immutable
final class WorldMapFeatureRoles {
  const WorldMapFeatureRoles({
    required this.countryId,
    required this.isNationality,
    required this.isCurrentClub,
    required this.isPlayable,
    required this.isSelected,
  });

  final String? countryId;
  final bool isNationality;
  final bool isCurrentClub;
  final bool isPlayable;
  final bool isSelected;
}

@immutable
final class WorldMapFeature {
  WorldMapFeature({
    required this.code,
    required this.name,
    required this.region,
    required List<List<Offset>> rings,
  }) : _rings = rings,
       bounds = _boundsFor(rings),
       _normalizedPath = _pathFor(rings, const Size(1, 1));

  final String code;
  final String name;
  final FootballMapRegion? region;

  /// Compatibility view for older map tests. Active UI rendering resolves the
  /// code against its pinned [WorldDefinition] instead.
  String? get countryId => _countryIdForCode(code, buildLaunchWorld());

  /// Legacy compatibility for the six-country 2026.1/2026.2 map tests.
  FootballNation? get nation => _legacyNationFromCountryId(countryId);
  final List<List<Offset>> _rings;
  final Rect bounds;
  final Path _normalizedPath;

  Path pathFor(Size size) => _pathFor(_rings, size);

  bool contains(Offset normalizedPosition) =>
      _normalizedPath.contains(normalizedPosition);

  static Rect _boundsFor(List<List<Offset>> rings) {
    final points = rings.expand((ring) => ring);
    var left = 1.0;
    var top = 1.0;
    var right = 0.0;
    var bottom = 0.0;
    for (final point in points) {
      left = point.dx < left ? point.dx : left;
      top = point.dy < top ? point.dy : top;
      right = point.dx > right ? point.dx : right;
      bottom = point.dy > bottom ? point.dy : bottom;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Path _pathFor(List<List<Offset>> rings, Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final ring in rings) {
      if (ring.length < 3) continue;
      path.moveTo(ring.first.dx * size.width, ring.first.dy * size.height);
      for (final point in ring.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      path.close();
    }
    return path;
  }
}

@immutable
final class WorldMapData {
  const WorldMapData(this.features);

  final List<WorldMapFeature> features;

  static Future<WorldMapData>? _cached;
  static WorldMapData? _resolved;

  static Future<WorldMapData> load() => _cached ??= _load();

  static WorldMapData? get cached => _resolved;

  static Future<WorldMapData> _load() async {
    final source = await rootBundle.loadString(
      'assets/maps/natural_earth_50m_map_units.json',
    );
    final json = jsonDecode(source) as Map<String, Object?>;
    final scale = (json['coordinateScale']! as List<Object?>).cast<num>();
    final rawFeatures = (json['features']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final data = WorldMapData(
      rawFeatures
          .map((feature) {
            final rings = (feature['rings']! as List<Object?>)
                .map((rawRing) {
                  return (rawRing as List<Object?>)
                      .map((rawPoint) {
                        final point = (rawPoint as List<Object?>).cast<num>();
                        return Offset(
                          point[0].toDouble() / scale[0],
                          point[1].toDouble() / scale[1],
                        );
                      })
                      .toList(growable: false);
                })
                .toList(growable: false);
            final code = feature['code']! as String;
            return WorldMapFeature(
              code: code,
              name: feature['name']! as String,
              region: _regionFromName(feature['region'] as String?),
              rings: rings,
            );
          })
          .toList(growable: false),
    );
    _resolved = data;
    return data;
  }

  String? countryIdFor(WorldMapFeature feature, WorldDefinition definition) =>
      _countryIdForCode(feature.code, definition);

  FootballMapRegion? regionFor(
    WorldMapFeature feature,
    WorldDefinition definition,
  ) {
    final countryId = countryIdFor(feature, definition);
    if (countryId == null) return feature.region;
    return _mapRegion(definition.country(countryId).region);
  }

  Rect boundsForRegion(
    FootballMapRegion region, {
    WorldDefinition? definition,
  }) {
    final world = definition ?? buildLaunchWorld();
    return _combinedBounds(
      features.where((feature) => regionFor(feature, world) == region),
    );
  }

  Rect boundsForCountry(String countryId, {WorldDefinition? definition}) {
    final world = definition ?? buildLaunchWorld();
    return _combinedBounds(
      features.where((feature) => countryIdFor(feature, world) == countryId),
    );
  }

  WorldMapFeature? featureAt(Offset normalizedPosition) {
    for (final feature in features.reversed) {
      if (feature.bounds.contains(normalizedPosition) &&
          feature.contains(normalizedPosition)) {
        return feature;
      }
    }
    return null;
  }

  Rect _combinedBounds(Iterable<WorldMapFeature> selected) {
    final iterator = selected.iterator;
    if (!iterator.moveNext()) return const Rect.fromLTWH(0, 0, 1, 1);
    var result = iterator.current.bounds;
    while (iterator.moveNext()) {
      result = result.expandToInclude(iterator.current.bounds);
    }
    return result;
  }
}

WorldMapFeatureState worldMapFeatureState({
  required WorldMapFeature feature,
  WorldDefinition? definition,
  String? homeCountryId,
  String? selectedCountryId,
  FootballNation? homeNation,
  FootballNation? selectedNation,
}) {
  final world = definition ?? buildLaunchWorld();
  final resolvedHome = homeCountryId ?? _countryIdFromLegacyNation(homeNation);
  final resolvedSelected =
      selectedCountryId ?? _countryIdFromLegacyNation(selectedNation);
  final countryId = _countryIdForCode(feature.code, world);
  if (countryId == resolvedHome) return WorldMapFeatureState.home;
  if (resolvedSelected != null && countryId == resolvedSelected) {
    return WorldMapFeatureState.selected;
  }
  final country = countryId == null
      ? null
      : world.countries.where((country) => country.id == countryId).firstOrNull;
  if (country?.hasLeague ?? false) return WorldMapFeatureState.playable;
  return WorldMapFeatureState.unavailable;
}

bool worldMapFeatureIsSelected({
  required WorldMapFeature feature,
  required String? selectedCountryId,
  WorldDefinition? definition,
}) =>
    selectedCountryId != null &&
    _countryIdForCode(feature.code, definition ?? buildLaunchWorld()) ==
        selectedCountryId;

WorldMapFeatureRoles worldMapFeatureRoles({
  required WorldMapFeature feature,
  required WorldDefinition definition,
  required String nationalityCountryId,
  String? currentClubCountryId,
  Set<String>? playableCountryIds,
  String? selectedCountryId,
}) {
  final countryId = _countryIdForCode(feature.code, definition);
  final playable =
      playableCountryIds ??
      definition.leagues.map((league) => league.countryId).toSet();
  return WorldMapFeatureRoles(
    countryId: countryId,
    isNationality: countryId == nationalityCountryId,
    isCurrentClub: countryId != null && countryId == currentClubCountryId,
    isPlayable: countryId != null && playable.contains(countryId),
    isSelected: countryId != null && countryId == selectedCountryId,
  );
}

final class AccurateFootballWorldMap extends StatefulWidget {
  const AccurateFootballWorldMap({
    super.key,
    required this.homeRegion,
    required this.homeCountryId,
    required this.onRegionSelected,
    required this.onCountrySelected,
    required this.onUnavailable,
    required this.onReset,
    this.selectedRegion,
    this.selectedCountryId,
    this.interactive = true,
    this.onExplore,
    this.definition,
    this.currentClubCountryId,
    this.playableCountryIds,
  });

  final FootballMapRegion homeRegion;
  final String homeCountryId;
  final String? currentClubCountryId;
  final Set<String>? playableCountryIds;
  final FootballMapRegion? selectedRegion;
  final String? selectedCountryId;
  final ValueChanged<FootballMapRegion> onRegionSelected;
  final ValueChanged<String> onCountrySelected;
  final ValueChanged<String> onUnavailable;
  final VoidCallback onReset;
  final bool interactive;
  final VoidCallback? onExplore;
  final WorldDefinition? definition;

  @override
  State<AccurateFootballWorldMap> createState() =>
      _AccurateFootballWorldMapState();
}

final class _AccurateFootballWorldMapState
    extends State<AccurateFootballWorldMap>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformation = TransformationController();
  late final AnimationController _animation;
  Matrix4 _animationStart = Matrix4.identity();
  Matrix4 _animationEnd = Matrix4.identity();
  Size _viewportSize = Size.zero;
  WorldMapData? _data;

  @override
  void initState() {
    super.initState();
    _animation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addListener(() {
          final progress = Curves.easeOutCubic.transform(_animation.value);
          _transformation.value = Matrix4Tween(
            begin: _animationStart,
            end: _animationEnd,
          ).transform(progress);
        });
  }

  @override
  void didUpdateWidget(covariant AccurateFootballWorldMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRegion != widget.selectedRegion ||
        oldWidget.selectedCountryId != widget.selectedCountryId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateToFocus());
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final world = widget.definition ?? buildLaunchWorld();
    final nationalityName = world.country(widget.homeCountryId).nameFor(locale);
    final clubCountryName = widget.currentClubCountryId == null
        ? null
        : world.country(widget.currentClubCountryId!).nameFor(locale);
    final roleSummary = clubCountryName == null
        ? '${uiCopy(locale, 'mapNationality')}: $nationalityName'
        : '${uiCopy(locale, 'mapNationality')}: $nationalityName. '
              '${uiCopy(locale, 'mapCurrentClub')}: $clubCountryName';
    return AspectRatio(
      aspectRatio: 1.72,
      child: Material(
        color: ElevenwardColors.deep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElevenwardRadii.card),
          side: const BorderSide(color: ElevenwardColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<WorldMapData>(
          future: WorldMapData.load(),
          initialData: WorldMapData.cached,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: Semantics(
                  label: uiCopy(locale, 'worldMap'),
                  child: const Icon(
                    Icons.public_rounded,
                    size: 34,
                    color: ElevenwardColors.grass,
                  ),
                ),
              );
            }
            _data = snapshot.data;
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                if (_viewportSize != size) {
                  _viewportSize = size;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _animateToFocus(immediate: true),
                  );
                }
                final paintedMap = CustomPaint(
                  size: size,
                  painter: _WorldMapPainter(
                    data: snapshot.data!,
                    homeCountryId: widget.homeCountryId,
                    currentClubCountryId: widget.currentClubCountryId,
                    playableCountryIds: widget.playableCountryIds,
                    selectedCountryId: widget.selectedCountryId,
                    definition: widget.definition ?? buildLaunchWorld(),
                  ),
                );
                final map = Semantics(
                  container: true,
                  button: true,
                  label: roleSummary,
                  hint: uiCopy(locale, 'exploreLeagues'),
                  child: widget.interactive
                      ? GestureDetector(
                          key: const Key('accurate-world-map'),
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) => _handleTap(
                            _transformation.toScene(details.localPosition),
                          ),
                          child: InteractiveViewer(
                            transformationController: _transformation,
                            minScale: 1,
                            maxScale: 8,
                            boundaryMargin: EdgeInsets.zero,
                            clipBehavior: Clip.hardEdge,
                            child: paintedMap,
                          ),
                        )
                      : InkWell(
                          key: const Key('world-map-overview'),
                          onTap: widget.onExplore,
                          child: paintedMap,
                        ),
                );
                return Stack(
                  children: [
                    Positioned.fill(child: map),
                    if (widget.interactive)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IconButton.filledTonal(
                          key: const Key('world-map-reset'),
                          tooltip: uiCopy(locale, 'resetMap'),
                          onPressed: _resetMap,
                          icon: const Icon(Icons.center_focus_strong_rounded),
                        ),
                      ),
                    Positioned(
                      left: 10,
                      right: 58,
                      bottom: 8,
                      child: _MapLegend(
                        locale: locale,
                        showSelected: widget.selectedCountryId != null,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _handleTap(Offset position) {
    final data = _data;
    if (data == null || _viewportSize.isEmpty) return;
    final normalized = Offset(
      position.dx / _viewportSize.width,
      position.dy / _viewportSize.height,
    );
    final selected = data.featureAt(normalized);
    if (selected == null) return;
    final world = widget.definition ?? buildLaunchWorld();
    final selectedRegion = data.regionFor(selected, world);
    if (widget.selectedRegion == null) {
      final region = selectedRegion;
      if (region == null) {
        widget.onUnavailable(selected.name);
      } else {
        widget.onRegionSelected(region);
      }
      return;
    }
    final countryId = data.countryIdFor(selected, world);
    final knownCountry =
        countryId != null &&
        world.countries.any((country) => country.id == countryId);
    if (knownCountry && selectedRegion == widget.selectedRegion) {
      widget.onCountrySelected(countryId);
    } else if (selectedRegion != null &&
        selectedRegion != widget.selectedRegion) {
      widget.onRegionSelected(selectedRegion);
    } else {
      widget.onUnavailable(selected.name);
    }
  }

  void _animateToFocus({bool immediate = false}) {
    final data = _data;
    if (data == null || _viewportSize.isEmpty || !mounted) return;
    final bounds = widget.selectedCountryId != null
        ? data.boundsForCountry(
            widget.selectedCountryId!,
            definition: widget.definition,
          )
        : widget.selectedRegion != null
        ? data.boundsForRegion(
            widget.selectedRegion!,
            definition: widget.definition,
          )
        : const Rect.fromLTWH(0, 0, 1, 1);
    final target = _matrixFor(bounds);
    if (immediate || MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _transformation.value = target;
      return;
    }
    _animationStart = Matrix4.copy(_transformation.value);
    _animationEnd = target;
    _animation.forward(from: 0);
  }

  void _resetMap() {
    _animation.stop();
    _animationStart = Matrix4.copy(_transformation.value);
    _animationEnd = Matrix4.identity();
    if (MediaQuery.disableAnimationsOf(context)) {
      _transformation.value = Matrix4.identity();
    } else {
      _animation.forward(from: 0);
    }
    widget.onReset();
  }

  Matrix4 _matrixFor(Rect bounds) {
    if (bounds.width >= .99 && bounds.height >= .99) return Matrix4.identity();
    const padding = .08;
    final scaleX = (1 - padding * 2) / bounds.width;
    final scaleY = (1 - padding * 2) / bounds.height;
    final maximum = widget.selectedCountryId == null ? 4.6 : 7.5;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final clampedScale = scale.clamp(1.0, maximum);
    final center = bounds.center;
    final translateX =
        _viewportSize.width / 2 -
        center.dx * _viewportSize.width * clampedScale;
    final translateY =
        _viewportSize.height / 2 -
        center.dy * _viewportSize.height * clampedScale;
    return Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(clampedScale, clampedScale, 1, 1);
  }
}

final class _WorldMapPainter extends CustomPainter {
  const _WorldMapPainter({
    required this.data,
    required this.homeCountryId,
    required this.currentClubCountryId,
    required this.playableCountryIds,
    required this.selectedCountryId,
    required this.definition,
  });

  final WorldMapData data;
  final String homeCountryId;
  final String? currentClubCountryId;
  final Set<String>? playableCountryIds;
  final String? selectedCountryId;
  final WorldDefinition definition;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ElevenwardColors.deep);
    final grid = Paint()
      ..color = ElevenwardColors.line.withValues(alpha: .22)
      ..strokeWidth = .5;
    for (var index = 1; index < 6; index += 1) {
      final x = size.width * index / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var index = 1; index < 3; index += 1) {
      final y = size.height * index / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (final feature in data.features) {
      final path = feature.pathFor(size);
      final roles = worldMapFeatureRoles(
        feature: feature,
        definition: definition,
        nationalityCountryId: homeCountryId,
        currentClubCountryId: currentClubCountryId,
        playableCountryIds: playableCountryIds,
        selectedCountryId: selectedCountryId,
      );
      final fill = roles.isNationality
          ? ElevenwardColors.grass
          : roles.isCurrentClub
          ? ElevenwardColors.coral
          : roles.isPlayable
          ? ElevenwardColors.sky
          : ElevenwardColors.panel;
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = roles.isSelected
              ? 2.4
              : roles.isNationality || roles.isCurrentClub
              ? 1.5
              : roles.isPlayable
              ? 1
              : .45
          ..color = roles.isSelected
              ? ElevenwardColors.amber
              : roles.isNationality || roles.isCurrentClub || roles.isPlayable
              ? ElevenwardColors.cream.withValues(alpha: .72)
              : ElevenwardColors.line,
      );
    }

    final nationalityCenter = _countryCenter(homeCountryId, size);
    final clubCenter = currentClubCountryId == null
        ? null
        : _countryCenter(currentClubCountryId!, size);
    if (nationalityCenter != null) {
      canvas.drawCircle(
        nationalityCenter,
        6,
        Paint()..color = ElevenwardColors.grass,
      );
      canvas.drawCircle(
        nationalityCenter,
        2.2,
        Paint()..color = ElevenwardColors.ink,
      );
    }
    if (clubCenter != null) {
      if (currentClubCountryId == homeCountryId) {
        canvas.drawCircle(
          clubCenter,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = ElevenwardColors.coral,
        );
      } else {
        final marker = Path()
          ..moveTo(clubCenter.dx - 6, clubCenter.dy - 6)
          ..lineTo(clubCenter.dx + 6, clubCenter.dy - 6)
          ..lineTo(clubCenter.dx + 5, clubCenter.dy + 1)
          ..quadraticBezierTo(
            clubCenter.dx + 3,
            clubCenter.dy + 6,
            clubCenter.dx,
            clubCenter.dy + 8,
          )
          ..quadraticBezierTo(
            clubCenter.dx - 3,
            clubCenter.dy + 6,
            clubCenter.dx - 5,
            clubCenter.dy + 1,
          )
          ..close();
        canvas.drawPath(marker, Paint()..color = ElevenwardColors.coral);
        canvas.drawCircle(clubCenter, 2, Paint()..color = ElevenwardColors.ink);
      }
    }
  }

  Offset? _countryCenter(String countryId, Size size) {
    final matching = data.features.where(
      (feature) => data.countryIdFor(feature, definition) == countryId,
    );
    if (matching.isEmpty) return null;
    final bounds = data.boundsForCountry(countryId, definition: definition);
    return Offset(
      bounds.center.dx * size.width,
      bounds.center.dy * size.height,
    );
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.homeCountryId != homeCountryId ||
      oldDelegate.currentClubCountryId != currentClubCountryId ||
      !setEquals(oldDelegate.playableCountryIds, playableCountryIds) ||
      oldDelegate.selectedCountryId != selectedCountryId ||
      oldDelegate.definition != definition;
}

final class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.locale, required this.showSelected});

  final String locale;
  final bool showSelected;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _LegendItem(
          icon: Icons.flag_rounded,
          color: ElevenwardColors.grass,
          label: uiCopy(locale, 'mapNationality'),
        ),
        _LegendItem(
          icon: Icons.shield_rounded,
          color: ElevenwardColors.coral,
          label: uiCopy(locale, 'mapCurrentClub'),
        ),
        _LegendItem(
          icon: Icons.public_rounded,
          color: ElevenwardColors.sky,
          label: uiCopy(locale, 'mapPlayable'),
        ),
        _LegendItem(
          icon: Icons.circle_outlined,
          color: ElevenwardColors.panel,
          label: uiCopy(locale, 'mapUnavailable'),
        ),
        if (showSelected)
          _LegendItem(
            icon: Icons.radio_button_checked_rounded,
            color: ElevenwardColors.amber,
            label: uiCopy(locale, 'mapSelected'),
          ),
      ],
    ),
  );
}

final class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: ElevenwardColors.ink.withValues(alpha: .86),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: ElevenwardColors.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 9, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: ElevenwardColors.cream,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

FootballMapRegion? _regionFromName(String? value) => switch (value) {
  'europe' => FootballMapRegion.europe,
  'northAmerica' => FootballMapRegion.northAmerica,
  'southAmerica' => FootballMapRegion.southAmerica,
  'asia' => FootballMapRegion.asia,
  'africa' => FootballMapRegion.africa,
  'oceania' => FootballMapRegion.oceania,
  _ => null,
};

FootballMapRegion _mapRegion(FootballRegion region) => switch (region) {
  FootballRegion.europe => FootballMapRegion.europe,
  FootballRegion.southAmerica => FootballMapRegion.southAmerica,
  FootballRegion.northAmerica => FootballMapRegion.northAmerica,
  FootballRegion.asia => FootballMapRegion.asia,
  FootballRegion.africa => FootballMapRegion.africa,
  FootballRegion.oceania => FootballMapRegion.oceania,
};

String? _countryIdForCode(String code, WorldDefinition definition) {
  for (final country in definition.countries) {
    if (country.mapUnitCodes.contains(code)) return country.id;
  }
  return null;
}

String? _countryIdFromLegacyNation(FootballNation? nation) => switch (nation) {
  FootballNation.england => 'england',
  FootballNation.spain => 'spain',
  FootballNation.france => 'france',
  FootballNation.germany => 'germany',
  FootballNation.unitedStates => 'united-states',
  FootballNation.brazil => 'brazil',
  _ => null,
};

FootballNation? _legacyNationFromCountryId(String? countryId) =>
    switch (countryId) {
      'england' => FootballNation.england,
      'spain' => FootballNation.spain,
      'france' => FootballNation.france,
      'germany' => FootballNation.germany,
      'united-states' => FootballNation.unitedStates,
      'brazil' => FootballNation.brazil,
      _ => null,
    };
