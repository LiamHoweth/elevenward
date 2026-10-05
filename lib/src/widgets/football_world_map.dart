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
  static final _geometryCache =
      Expando<Map<WorldDefinition, List<_MapLabelGeometry>>>();

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

  /// A stable land anchor shared by country labels and nationality/club marks.
  Offset? anchorForCountry(String countryId, {WorldDefinition? definition}) {
    final world = definition ?? buildLaunchWorld();
    for (final geometry in _geometryFor(world)) {
      if (geometry.country.id == countryId) return geometry.anchor;
    }
    return null;
  }

  /// Keep date-line islands from stretching a country focus across the world.
  /// All geometry remains painted and selectable; only the camera fit changes.
  Rect focusBoundsForCountry(String countryId, {WorldDefinition? definition}) {
    final world = definition ?? buildLaunchWorld();
    final bounds = boundsForCountry(countryId, definition: world);
    final anchor = anchorForCountry(countryId, definition: world);
    if (bounds.width < .75 || anchor == null) return bounds;
    final rings = features
        .where((feature) => countryIdFor(feature, world) == countryId)
        .expand((feature) => feature._rings)
        .where((ring) => ring.length >= 3)
        .map((ring) => WorldMapFeature._boundsFor([ring]))
        .where((ringBounds) => (ringBounds.center.dx - anchor.dx).abs() < .5);
    final iterator = rings.iterator;
    if (!iterator.moveNext()) return bounds;
    var focused = iterator.current;
    while (iterator.moveNext()) {
      focused = focused.expandToInclude(iterator.current);
    }
    return focused;
  }

  List<_MapLabelGeometry> _geometryFor(WorldDefinition definition) {
    final cache = _geometryCache[this] ??= {};
    return cache.putIfAbsent(definition, () {
      final countryFeatures = <String, List<WorldMapFeature>>{};
      for (final feature in features) {
        final id = countryIdFor(feature, definition);
        if (id != null) (countryFeatures[id] ??= []).add(feature);
      }
      final result = <_MapLabelGeometry>[];
      for (final country in definition.countries) {
        final matching = countryFeatures[country.id] ?? [];
        WorldMapFeature? largestFeature;
        List<Offset>? largestRing;
        var largestArea = 0.0;
        for (final feature in matching) {
          for (final ring in feature._rings) {
            final area = _ringArea(ring).abs();
            if (area > largestArea) {
              largestArea = area;
              largestFeature = feature;
              largestRing = ring;
            }
          }
        }
        if (largestFeature == null || largestRing == null) continue;
        final bounds = WorldMapFeature._boundsFor([largestRing]);
        result.add(
          _MapLabelGeometry(
            country: country,
            anchor: _labelAnchor(largestFeature, largestRing, bounds),
            bounds: bounds,
            area: largestArea,
          ),
        );
      }
      return result;
    });
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
          side: BorderSide(color: ElevenwardColors.line),
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
                  child: Icon(
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
                    brightness: Theme.of(context).brightness,
                  ),
                );
                final map = Semantics(
                  container: true,
                  image: widget.interactive,
                  button: !widget.interactive && widget.onExplore != null,
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
                            onInteractionStart: (_) => _animation.stop(),
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
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _transformation,
                          builder: (context, _) => _MapCountryLabels(
                            data: snapshot.data!,
                            definition: world,
                            viewport: size,
                            transformation: _transformation.value,
                            locale: locale,
                            homeCountryId: widget.homeCountryId,
                            currentClubCountryId: widget.currentClubCountryId,
                            selectedCountryId: widget.selectedCountryId,
                          ),
                        ),
                      ),
                    if (widget.interactive)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: AnimatedBuilder(
                          animation: _transformation,
                          builder: (context, _) {
                            final scale = _transformation.value
                                .getMaxScaleOnAxis();
                            return Material(
                              color: ElevenwardColors.ink.withValues(
                                alpha: .94,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: ElevenwardColors.line),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: const Key('world-map-zoom-in'),
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    tooltip: _mapCopy(locale, 'zoomIn'),
                                    onPressed: scale < 7.999
                                        ? () => _zoomBy(1.5)
                                        : null,
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                  IconButton(
                                    key: const Key('world-map-zoom-out'),
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    tooltip: _mapCopy(locale, 'zoomOut'),
                                    onPressed: scale > 1.001
                                        ? () => _zoomBy(1 / 1.5)
                                        : null,
                                    icon: const Icon(Icons.remove_rounded),
                                  ),
                                  IconButton(
                                    key: const Key('world-map-reset'),
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    tooltip: uiCopy(locale, 'resetMap'),
                                    onPressed: _resetMap,
                                    icon: const Icon(
                                      Icons.center_focus_strong_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    Positioned(
                      left: 10,
                      right: 10,
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
        ? data.focusBoundsForCountry(
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

  void _zoomBy(double factor) {
    if (_viewportSize.isEmpty) return;
    _animation.stop();
    final scale = _transformation.value.getMaxScaleOnAxis();
    final nextScale = (scale * factor).clamp(1.0, 8.0);
    final center = _transformation.toScene(_viewportSize.center(Offset.zero));
    // Keep the current map center under the viewport center. Clamping matches
    // InteractiveViewer's zero boundary margin, including a full-world reset.
    final x = (_viewportSize.width / 2 - center.dx * nextScale).clamp(
      _viewportSize.width * (1 - nextScale),
      0.0,
    );
    final y = (_viewportSize.height / 2 - center.dy * nextScale).clamp(
      _viewportSize.height * (1 - nextScale),
      0.0,
    );
    final target = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(nextScale, nextScale, 1, 1);
    if (MediaQuery.disableAnimationsOf(context)) {
      _transformation.value = target;
    } else {
      _animationStart = Matrix4.copy(_transformation.value);
      _animationEnd = target;
      _animation.forward(from: 0);
    }
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
        (_viewportSize.width / 2 -
                center.dx * _viewportSize.width * clampedScale)
            .clamp(_viewportSize.width * (1 - clampedScale), 0.0);
    final translateY =
        (_viewportSize.height / 2 -
                center.dy * _viewportSize.height * clampedScale)
            .clamp(_viewportSize.height * (1 - clampedScale), 0.0);
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
    required this.brightness,
  });

  final WorldMapData data;
  final String homeCountryId;
  final String? currentClubCountryId;
  final Set<String>? playableCountryIds;
  final String? selectedCountryId;
  final WorldDefinition definition;
  final Brightness brightness;

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
    final anchor = data.anchorForCountry(countryId, definition: definition);
    if (anchor == null) return null;
    return Offset(anchor.dx * size.width, anchor.dy * size.height);
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.homeCountryId != homeCountryId ||
      oldDelegate.currentClubCountryId != currentClubCountryId ||
      !setEquals(oldDelegate.playableCountryIds, playableCountryIds) ||
      oldDelegate.selectedCountryId != selectedCountryId ||
      oldDelegate.definition != definition ||
      oldDelegate.brightness != brightness;
}

final class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.locale, required this.showSelected});

  final String locale;
  final bool showSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const Key('world-map-legend'),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _LegendItem(
          icon: Icons.flag_rounded,
          color: ElevenwardColors.grass,
          label: uiCopy(locale, 'mapNationality'),
        ),
        const SizedBox(width: 8),
        _LegendItem(
          icon: Icons.shield_rounded,
          color: ElevenwardColors.coral,
          label: uiCopy(locale, 'mapCurrentClub'),
        ),
        const SizedBox(width: 8),
        _LegendItem(
          icon: Icons.public_rounded,
          color: ElevenwardColors.sky,
          label: uiCopy(locale, 'mapPlayable'),
        ),
        const SizedBox(width: 8),
        _LegendItem(
          icon: Icons.circle_outlined,
          color: ElevenwardColors.panel,
          label: uiCopy(locale, 'mapUnavailable'),
        ),
        if (showSelected) ...[
          const SizedBox(width: 8),
          _LegendItem(
            icon: Icons.radio_button_checked_rounded,
            color: ElevenwardColors.amber,
            label: uiCopy(locale, 'mapSelected'),
          ),
        ],
      ],
    ),
  );
}

/// Labels are laid out in viewport coordinates, so pinch zoom enlarges the
/// geography without magnifying or clipping country names. Only the pinned
/// world's localized countries are named; geometry never unlocks new content.
final class _MapCountryLabels extends StatefulWidget {
  const _MapCountryLabels({
    required this.data,
    required this.definition,
    required this.viewport,
    required this.transformation,
    required this.locale,
    required this.homeCountryId,
    required this.currentClubCountryId,
    required this.selectedCountryId,
  });

  final WorldMapData data;
  final WorldDefinition definition;
  final Size viewport;
  final Matrix4 transformation;
  final String locale;
  final String homeCountryId;
  final String? currentClubCountryId;
  final String? selectedCountryId;

  @override
  State<_MapCountryLabels> createState() => _MapCountryLabelsState();
}

final class _MapCountryLabelsState extends State<_MapCountryLabels> {
  late List<_MapLabelGeometry> _geometry;

  @override
  void initState() {
    super.initState();
    _geometry = _resolveGeometry();
  }

  @override
  void didUpdateWidget(covariant _MapCountryLabels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.definition != widget.definition) {
      _geometry = _resolveGeometry();
    }
  }

  List<_MapLabelGeometry> _resolveGeometry() =>
      widget.data._geometryFor(widget.definition);

  @override
  Widget build(BuildContext context) {
    final scale = widget.transformation.getMaxScaleOnAxis();
    if (scale < 1.75) return const SizedBox.shrink();
    final textScaler = MediaQuery.textScalerOf(context);
    final viewport = widget.viewport;
    final style = TextStyle(
      fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
      color: ElevenwardColors.cream,
      fontSize: 11,
      height: 1.15,
      letterSpacing: 0,
      fontWeight: FontWeight.w700,
    );
    final candidates = <_MapLabelCandidate>[];
    for (final geometry in _geometry) {
      final country = geometry.country;
      final bounds = geometry.bounds;
      final priority = country.id == widget.selectedCountryId
          ? 0
          : country.id == widget.homeCountryId
          ? 1
          : country.id == widget.currentClubCountryId
          ? 2
          : 3;
      // Small neighbours appear when there is enough geographic space. A
      // directly selected country can always compete for a label position.
      if (priority == 3 &&
          (bounds.width * viewport.width * scale < 18 ||
              bounds.height * viewport.height * scale < 14)) {
        continue;
      }
      final anchor = geometry.anchor;
      final screenAnchor = MatrixUtils.transformPoint(
        widget.transformation,
        Offset(anchor.dx * viewport.width, anchor.dy * viewport.height),
      );
      if (!(Offset.zero & viewport).contains(screenAnchor)) continue;
      candidates.add(
        _MapLabelCandidate(
          countryId: country.id,
          name: country.nameFor(widget.locale),
          anchor: screenAnchor,
          area: geometry.area,
          priority: priority,
        ),
      );
    }
    candidates.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      return byPriority == 0 ? b.area.compareTo(a.area) : byPriority;
    });
    final legendHeight = textScaler.scale(9) * 1.5 + 24;
    final allowed = Rect.fromLTRB(
      5,
      5,
      viewport.width - 5,
      viewport.height - legendHeight,
    );
    final occupied = <Rect>[Rect.fromLTWH(viewport.width - 160, 0, 160, 64)];
    final labels = <Widget>[];
    for (final candidate in candidates) {
      final painter = TextPainter(
        text: TextSpan(text: candidate.name, style: style),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: viewport.width - 22);
      final labelSize = Size(
        painter.width.ceilToDouble() + 14,
        painter.height.ceilToDouble() + 8,
      );
      painter.dispose();
      final anchor = candidate.anchor;
      final origins = [
        Offset(
          anchor.dx - labelSize.width / 2,
          anchor.dy - labelSize.height - 16,
        ),
        Offset(anchor.dx - labelSize.width / 2, anchor.dy + 16),
        Offset(anchor.dx + 16, anchor.dy - labelSize.height / 2),
        Offset(
          anchor.dx - labelSize.width - 16,
          anchor.dy - labelSize.height / 2,
        ),
      ];
      Rect? placement;
      for (final origin in origins) {
        final rect = origin & labelSize;
        if (!allowed.contains(rect.topLeft) ||
            !allowed.contains(rect.bottomRight) ||
            occupied.any((other) => other.overlaps(rect.inflate(4)))) {
          continue;
        }
        placement = rect;
        break;
      }
      if (placement == null) continue;
      occupied.add(placement);
      labels.add(
        Positioned.fromRect(
          rect: placement,
          child: Container(
            key: Key('world-map-label-${candidate.countryId}'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: ElevenwardColors.ink.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ElevenwardColors.line, width: .5),
            ),
            child: Text(
              candidate.name,
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ClipRect(child: Stack(children: labels)),
      ),
    );
  }
}

final class _MapLabelGeometry {
  const _MapLabelGeometry({
    required this.country,
    required this.anchor,
    required this.bounds,
    required this.area,
  });

  final CountryDefinition country;
  final Offset anchor;
  final Rect bounds;
  final double area;
}

final class _MapLabelCandidate {
  const _MapLabelCandidate({
    required this.countryId,
    required this.name,
    required this.anchor,
    required this.area,
    required this.priority,
  });

  final String countryId;
  final String name;
  final Offset anchor;
  final double area;
  final int priority;
}

double _ringArea(List<Offset> ring) {
  var area = 0.0;
  for (var index = 0; index < ring.length; index++) {
    final a = ring[index];
    final b = ring[(index + 1) % ring.length];
    area += a.dx * b.dy - b.dx * a.dy;
  }
  return area / 2;
}

Offset _labelAnchor(WorldMapFeature feature, List<Offset> ring, Rect bounds) {
  var x = 0.0;
  var y = 0.0;
  final area = _ringArea(ring);
  for (var index = 0; index < ring.length; index++) {
    final a = ring[index];
    final b = ring[(index + 1) % ring.length];
    final cross = a.dx * b.dy - b.dx * a.dy;
    x += (a.dx + b.dx) * cross;
    y += (a.dy + b.dy) * cross;
  }
  final centroid = area.abs() < .0000001
      ? bounds.center
      : Offset(x / (6 * area), y / (6 * area));
  if (feature.contains(centroid)) return centroid;
  if (feature.contains(bounds.center)) return bounds.center;
  // Concave outlines and archipelagos can place their mathematical centroid in
  // water. Prefer an interior point near the largest landmass's center.
  Offset? interior;
  var closest = double.infinity;
  for (var row = 1; row < 8; row++) {
    for (var column = 1; column < 8; column++) {
      final point = Offset(
        bounds.left + bounds.width * column / 8,
        bounds.top + bounds.height * row / 8,
      );
      final distance = (point - bounds.center).distanceSquared;
      if (distance < closest && feature.contains(point)) {
        interior = point;
        closest = distance;
      }
    }
  }
  return interior ?? ring.first;
}

String _mapCopy(String locale, String key) =>
    (const <String, Map<String, String>>{
      'zoomIn': {
        'en': 'Zoom in',
        'es': 'Acercar',
        'pt-BR': 'Aproximar',
        'fr': 'Agrandir',
      },
      'zoomOut': {
        'en': 'Zoom out',
        'es': 'Alejar',
        'pt-BR': 'Afastar',
        'fr': 'Réduire',
      },
    })[key]?[locale] ??
    key;

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
          style: TextStyle(
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
