import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

class AndroidWalkMap extends StatefulWidget {
  final List<GeoSample> samples, route;
  final List<PlaceInfo> places;
  final GeoSample? current;
  final ValueChanged<String>? onPlace;
  final int centerRequest;
  final bool fit;
  final AndroidMapConfiguration? configuration;
  final TileProvider? tileProvider;
  const AndroidWalkMap({
    super.key,
    this.samples = const [],
    this.route = const [],
    this.places = const [],
    this.current,
    this.onPlace,
    this.centerRequest = 0,
    this.fit = false,
    this.configuration,
    this.tileProvider,
  });
  @override
  State<AndroidWalkMap> createState() => _AndroidWalkMapState();
}

class _AndroidWalkMapState extends State<AndroidWalkMap> {
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
      controller.move(point(widget.current!), 16);
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
              initialZoom: widget.current == null && points.isEmpty ? 6 : 16,
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
                      color: Colors.blue,
                      strokeWidth: 4,
                      pattern: StrokePattern.dashed(segments: [8, 5]),
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
                  for (final place in widget.places.where(
                    (p) => p.location.valid,
                  ))
                    Marker(
                      point: point(place.location),
                      width: 110,
                      height: 56,
                      child: GestureDetector(
                        onTap: () => widget.onPlace?.call(place.id),
                        child: Semantics(
                          label:
                              '${place.name}, ${place.rewardEligible ? '공원 방문 최대 30포인트' : '장소 상세'}',
                          button: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4D8),
                                  border: Border.all(color: forest, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x55205C40),
                                      offset: Offset(3, 3),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    place.rewardEligible ? '+30P' : place.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: forest,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Icon(
                                place.rewardEligible ? Icons.park : Icons.pets,
                                color: forest,
                                size: 25,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (widget.current?.valid == true)
                    Marker(
                      point: point(widget.current!),
                      width: 34,
                      height: 34,
                      child: Semantics(
                        label: '마지막으로 받은 위치',
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFFFF4D8),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x66000000),
                                offset: Offset(2, 3),
                              ),
                            ],
                          ),
                          child: CustomPaint(painter: PixelDogMarkerPainter()),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: PixelMapTexturePainter()),
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
