import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/korea.dart';
import '../core/ui.dart';
import '../models/walk_data.dart';
import '../services/android_map_configuration.dart';
import '../services/android_map_service.dart';

class TrackOverlays {
  final List<List<GeoSample>> segments;
  final List<GeoSample> footprints;
  const TrackOverlays(this.segments, this.footprints);
}

TrackOverlays trackOverlays(List<GeoSample> samples) {
  final segments = <List<GeoSample>>[], paws = <GeoSample>[];
  var current = <GeoSample>[];
  GeoSample? lastPaw;
  for (final point in samples) {
    if (!point.valid || point.breakBefore) {
      if (current.isNotEmpty) segments.add(current);
      current = [];
      lastPaw = null;
    }
    if (!point.valid) continue;
    current.add(point);
    if (lastPaw == null || distanceBetween(lastPaw, point) >= 20) {
      paws.add(point);
      lastPaw = point;
    }
  }
  if (current.isNotEmpty) segments.add(current);
  return TrackOverlays(
    segments,
    paws.length > 400 ? paws.sublist(paws.length - 400) : paws,
  );
}

List<GeoSample> spacedRoutePaws(
  List<GeoSample> samples, {
  double spacing = 80,
  int limit = 120,
}) {
  final valid = samples.where((sample) => sample.valid).toList();
  if (valid.isEmpty) return const [];
  final paws = <GeoSample>[valid.first];
  var last = valid.first;
  for (final sample in valid.skip(1)) {
    if (distanceBetween(last, sample) < spacing) continue;
    paws.add(sample);
    last = sample;
    if (paws.length >= limit) break;
  }
  return paws;
}

class AndroidWalkMap extends StatefulWidget {
  final List<GeoSample> samples, route;
  final List<PlaceInfo> places;
  final Map<String, String> placeLabels;
  final GeoSample? current;
  final ValueChanged<String>? onPlace;
  final int centerRequest;
  final bool fit;
  final Color routeColor;
  final AndroidMapConfiguration? configuration;
  final TileProvider? tileProvider;
  const AndroidWalkMap({
    super.key,
    this.samples = const [],
    this.route = const [],
    this.places = const [],
    this.placeLabels = const {},
    this.current,
    this.onPlace,
    this.centerRequest = 0,
    this.fit = false,
    this.routeColor = const Color(0xFF28734E),
    this.configuration,
    this.tileProvider,
  });
  @override
  State<AndroidWalkMap> createState() => _AndroidWalkMapState();
}

class _AndroidWalkMapState extends State<AndroidWalkMap> {
  static const nearbyZoom = 17.0;
  static final koreaMapBounds = LatLngBounds(
    const LatLng(koreaSouth, koreaWest),
    const LatLng(koreaNorth, koreaEast),
  );
  final controller = MapController();
  late final AndroidMapConfiguration configuration =
      widget.configuration ?? AndroidMapConfiguration.instance;
  bool ready = false, tileError = false;
  int retry = 0;
  @override
  void initState() {
    super.initState();
    if (widget.tileProvider == null)
      BuiltInMapCachingProvider.getOrCreateInstance(
        maxCacheSize: 64 * 1024 * 1024,
      );
  }

  LatLng point(GeoSample p) => LatLng(p.latitude, p.longitude);
  List<LatLng> get boundsPoints => widget.route.isNotEmpty
      ? widget.route.where((p) => p.valid).map(point).toList()
      : widget.samples.isNotEmpty
      ? widget.samples.where((p) => p.valid).map(point).toList()
      : [
          if (widget.current?.valid == true) point(widget.current!),
          ...widget.places
              .where((p) => p.location.valid)
              .map((p) => point(p.location)),
        ];
  void fit({bool center = false}) {
    if (!ready || !mounted) return;
    if (center && widget.current?.valid == true) {
      controller.move(point(widget.current!), nearbyZoom);
      return;
    }
    final points = boundsPoints;
    if (points.length > 1) {
      controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(35),
          maxZoom: 18,
        ),
      );
    } else if (points.length == 1) {
      controller.move(points.single, 16);
    }
  }

  void zoom(double change) {
    if (!ready) return;
    controller.move(
      controller.camera.center,
      (controller.camera.zoom + change).clamp(3, 19).toDouble(),
    );
  }

  @override
  void didUpdateWidget(AndroidWalkMap old) {
    super.didUpdateWidget(old);
    if (old.centerRequest != widget.centerRequest)
      fit(center: true);
    else if ((old.route != widget.route && widget.route.isNotEmpty) ||
        (old.places != widget.places && widget.places.isNotEmpty))
      fit();
    else if (old.current == null && widget.current != null)
      fit(center: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> open(String url) async {
    try {
      await AndroidMapService.openLink(url);
    } catch (_) {
      if (mounted) feedback(context, '링크를 열지 못했어요.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: configuration,
    builder: (context, _) {
      final config = configuration.value,
          overlays = trackOverlays(widget.samples),
          routePaws = spacedRoutePaws(widget.route),
          points = boundsPoints;
      final start = widget.current?.valid == true
          ? point(widget.current!)
          : points.isNotEmpty
          ? points.first
          : const LatLng(36.4, 127.8);
      return Stack(
        children: [
          FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: start,
              initialZoom: widget.current?.valid == true
                  ? nearbyZoom
                  : points.isEmpty
                  ? 6
                  : 16,
              minZoom: 6,
              maxZoom: 19,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: koreaMapBounds,
              ),
              initialCameraFit: widget.fit && points.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(35),
                      maxZoom: 18,
                    )
                  : null,
              onMapReady: () {
                ready = true;
              },
            ),
            children: [
              TileLayer(
                key: ValueKey('${config.tiles}-$retry'),
                urlTemplate: config.tiles,
                userAgentPackageName: 'com.mungcation.mungcation',
                maxNativeZoom: 19,
                tileProvider: widget.tileProvider,
                keepBuffer: 0,
                panBuffer: 0,
                errorTileCallback: (tile, error, stack) {
                  if (!tileError)
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => tileError = true);
                    });
                },
              ),
              PolylineLayer(
                polylines: [
                  for (final segment in overlays.segments.where(
                    (s) => s.length > 1,
                  ))
                    Polyline(
                      points: segment.map(point).toList(),
                      color: forest,
                      strokeWidth: 5,
                    ),
                  if (widget.route.length > 1)
                    Polyline(
                      points: widget.route
                          .where((p) => p.valid)
                          .map(point)
                          .toList(),
                      color: const Color(0xFFFFF1D2),
                      strokeWidth: 9,
                    ),
                  if (widget.route.length > 1)
                    Polyline(
                      points: widget.route
                          .where((p) => p.valid)
                          .map(point)
                          .toList(),
                      color: widget.routeColor,
                      strokeWidth: 5,
                      pattern: StrokePattern.dashed(segments: [10, 4]),
                    ),
                ],
              ),
              MarkerLayer(
                rotate: true,
                markers: [
                  for (final paw in overlays.footprints)
                    Marker(
                      point: point(paw),
                      width: 20,
                      height: 20,
                      child: const IgnorePointer(
                        child: Icon(
                          Icons.pets,
                          size: 17,
                          color: Color(0xFFB8794E),
                        ),
                      ),
                    ),
                  for (final paw in routePaws)
                    Marker(
                      point: point(paw),
                      width: 18,
                      height: 18,
                      child: const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xCCFFF8E9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.pets, size: 12, color: forest),
                        ),
                      ),
                    ),
                  for (final place in widget.places.where(
                    (p) => p.location.valid,
                  ))
                    Marker(
                      point: point(place.location),
                      width: 126,
                      height: 82,
                      child: GestureDetector(
                        onTap: () => widget.onPlace?.call(place.id),
                        child: Semantics(
                          label:
                              '${place.name}, ${place.rewardEligible ? '공원 방문 최대 30포인트' : '장소 상세'}',
                          button: true,
                          child: PixelPlaceMarker(
                            place: place,
                            subtitle: widget.placeLabels[place.id],
                          ),
                        ),
                      ),
                    ),
                  if (widget.current?.valid == true)
                    Marker(
                      point: point(widget.current!),
                      width: 48,
                      height: 48,
                      child: Semantics(
                        label: '마지막으로 받은 위치',
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(widget.current!.time),
                          tween: Tween(begin: .82, end: 1),
                          duration: const Duration(milliseconds: 550),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFFFF4D8),
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white, width: 3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x66205C40),
                                  offset: Offset(3, 4),
                                ),
                              ],
                            ),
                            child: CustomPaint(
                              painter: PixelDogMarkerPainter(),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Positioned(
            top: 12,
            left: 12,
            child: IgnorePointer(child: MungcationMapBadge()),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: PixelMapControls(
              onZoomIn: () => zoom(1),
              onZoomOut: () => zoom(-1),
              onCenter: () => fit(center: widget.current?.valid == true),
            ),
          ),
          if (tileError)
            Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: const Color(0xFFFFF4DF),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '지도 타일을 불러오지 못했어요.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          tileError = false;
                          retry++;
                        }),
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.white.withValues(alpha: .95),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                children: [
                  InkWell(
                    onTap: () => open(config.attributionUrl),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 3,
                      ),
                      child: Text(
                        config.attribution,
                        style: const TextStyle(fontSize: 10, color: ink),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () =>
                        open('https://www.openstreetmap.org/fixthemap'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 7, horizontal: 3),
                      child: Text(
                        '지도 수정 안내',
                        style: TextStyle(fontSize: 10, color: ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

enum PixelPlaceKind { park, cafe, hospital, stay, restaurant, pet }

PixelPlaceKind pixelPlaceKind(PlaceInfo place) {
  final value = '${place.category} ${place.name}'.toLowerCase();
  if (place.rewardEligible || value.contains('공원') || value.contains('park')) {
    return PixelPlaceKind.park;
  }
  if (value.contains('병원') || value.contains('동물') || value.contains('vet')) {
    return PixelPlaceKind.hospital;
  }
  if (value.contains('숙소') ||
      value.contains('호텔') ||
      value.contains('펜션') ||
      value.contains('stay')) {
    return PixelPlaceKind.stay;
  }
  if (value.contains('카페') || value.contains('cafe')) {
    return PixelPlaceKind.cafe;
  }
  if (value.contains('식당') ||
      value.contains('음식') ||
      value.contains('restaurant')) {
    return PixelPlaceKind.restaurant;
  }
  return PixelPlaceKind.pet;
}

class PixelPlaceMarker extends StatelessWidget {
  final PlaceInfo place;
  final String? subtitle;
  const PixelPlaceMarker({super.key, required this.place, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final kind = pixelPlaceKind(place);
    final (icon, color) = switch (kind) {
      PixelPlaceKind.park => (Icons.park, const Color(0xFF28734E)),
      PixelPlaceKind.cafe => (Icons.local_cafe, const Color(0xFFB8794E)),
      PixelPlaceKind.hospital => (
        Icons.local_hospital,
        const Color(0xFFD65F5F),
      ),
      PixelPlaceKind.stay => (Icons.bed, const Color(0xFF6B6FA9)),
      PixelPlaceKind.restaurant => (Icons.restaurant, const Color(0xFFD8893B)),
      PixelPlaceKind.pet => (Icons.pets, forest),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 122),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: color.withValues(alpha: .35)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                place.rewardEligible ? '${place.name} · +30P' : place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF5F625E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.white, width: 3),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ],
    );
  }
}

class MungcationMapBadge extends StatelessWidget {
  const MungcationMapBadge({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xF2FFFFFF),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets, size: 16, color: forest),
          SizedBox(width: 5),
          Text(
            '멍케이션 지도',
            style: TextStyle(
              color: forest,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

class PixelMapControls extends StatelessWidget {
  final VoidCallback onZoomIn, onZoomOut, onCenter;
  const PixelMapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCenter,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      PixelMapButton(tooltip: '확대', icon: Icons.add, onPressed: onZoomIn),
      const SizedBox(height: 7),
      PixelMapButton(tooltip: '축소', icon: Icons.remove, onPressed: onZoomOut),
      const SizedBox(height: 7),
      PixelMapButton(
        tooltip: '현재 위치로 이동',
        icon: Icons.pets,
        onPressed: onCenter,
      ),
    ],
  );
}

class PixelMapButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  const PixelMapButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xF5FFFFFF),
    shape: const CircleBorder(),
    elevation: 2,
    shadowColor: const Color(0x33000000),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: forest, size: 20),
    ),
  );
}

class PixelDogMarkerPainter extends CustomPainter {
  const PixelDogMarkerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 8;
    final dark = Paint()..color = const Color(0xFF3D2B22);
    final fur = Paint()..color = const Color(0xFFC77A43);
    final cream = Paint()..color = const Color(0xFFFFD59B);
    void block(double x, double y, double w, double h, Paint paint) => canvas
        .drawRect(Rect.fromLTWH(x * unit, y * unit, w * unit, h * unit), paint);
    block(2, 2, 4, 4, dark);
    block(1, 2, 2, 3, dark);
    block(5, 2, 2, 3, dark);
    block(2.5, 2.5, 3, 3, fur);
    block(2.5, 4.5, 2, 1, cream);
    block(3, 3, .7, .7, dark);
    block(4.6, 3, .7, .7, dark);
    block(3.8, 4.1, .7, .7, dark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PixelMapTexturePainter extends CustomPainter {
  const PixelMapTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x11205C40)
      ..strokeWidth = 1;
    const step = 12.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
