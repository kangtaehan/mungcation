import 'android_walk_map.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/walk_data.dart';

class WalkMap extends StatefulWidget {
  final List<GeoSample> samples, route;
  final List<PlaceInfo> places;
  final GeoSample? current;
  final ValueChanged<String>? onPlace;
  final int centerRequest;
  final bool fit, enabled;
  const WalkMap({
    super.key,
    this.samples = const [],
    this.route = const [],
    this.places = const [],
    this.current,
    this.onPlace,
    this.centerRequest = 0,
    this.fit = false,
    this.enabled = true,
  });
  @override
  State<WalkMap> createState() => _WalkMapState();
}

class _WalkMapState extends State<WalkMap> {
  MethodChannel? channel;
  String? error;
  bool get supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  Map<String, dynamic> payload({bool center = false, bool fit = false}) {
    final segments = <List<Map<String, dynamic>>>[];
    var segment = <Map<String, dynamic>>[];
    final footprints = <Map<String, dynamic>>[];
    GeoSample? last;
    for (final sample in widget.samples) {
      if (sample.breakBefore && segment.isNotEmpty) {
        segments.add(segment);
        segment = [];
        last = null;
      }
      segment.add(sample.toJson());
      if (last == null || distanceBetween(last, sample) >= 20) {
        footprints.add(sample.toJson());
        last = sample;
      }
    }
    if (segment.isNotEmpty) segments.add(segment);
    return {
      'segments': segments,
      'route': widget.route.map((e) => e.toJson()).toList(),
      'footprints': footprints.length > 400
          ? footprints.sublist(footprints.length - 400)
          : footprints,
      'places': widget.places.map((e) => e.toMap()).toList(),
      'current': widget.current?.toJson(),
      'center': center,
      'fit': widget.fit || fit,
    };
  }

  @override
  void didUpdateWidget(WalkMap old) {
    super.didUpdateWidget(old);
    final newRoute = old.route != widget.route && widget.route.isNotEmpty;
    final newPlaces = old.places != widget.places && widget.places.isNotEmpty;
    if (old.samples.length != widget.samples.length ||
        old.samples.lastOrNull?.time != widget.samples.lastOrNull?.time ||
        old.current?.time != widget.current?.time ||
        newRoute ||
        newPlaces ||
        old.route.isNotEmpty != widget.route.isNotEmpty ||
        old.places.isNotEmpty != widget.places.isNotEmpty ||
        old.centerRequest != widget.centerRequest) {
      send(
        center: old.centerRequest != widget.centerRequest,
        fit: newRoute || newPlaces,
      );
    }
  }

  Future<void> send({bool center = false, bool fit = false}) async {
    if (channel == null) return;
    try {
      await channel!.invokeMethod<void>(
        'update',
        payload(center: center, fit: fit),
      );
      if (error != null && mounted) setState(() => error = null);
    } catch (_) {
      if (mounted) setState(() => error = '지도를 갱신하지 못했어요. 화면을 다시 열어 주세요.');
    }
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled)
      return const ColoredBox(
        color: Color(0xFFE8F0E7),
        child: Center(child: Icon(Icons.map_outlined)),
      );
    if (kIsWeb || Platform.isAndroid)
      return AndroidWalkMap(
        samples: widget.samples,
        route: widget.route,
        places: widget.places,
        current: widget.current,
        onPlace: widget.onPlace,
        centerRequest: widget.centerRequest,
        fit: widget.fit,
      );
    if (!supported)
      return const ColoredBox(
        color: Color(0xFFE8F0E7),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              '실제 지도는 Android 또는 iPhone에서 사용할 수 있어요.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    return Stack(
      children: [
        Positioned.fill(
          child: UiKitView(
            viewType: 'mungcation/map',
            creationParams: payload(
              fit:
                  widget.fit ||
                  widget.route.isNotEmpty ||
                  widget.places.isNotEmpty,
            ),
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (id) {
              channel = MethodChannel('mungcation/map/$id');
              channel!.setMethodCallHandler((call) async {
                if (call.method == 'selectPlace')
                  widget.onPlace?.call(call.arguments as String);
              });
              send();
            },
          ),
        ),
        if (error != null)
          Align(
            alignment: Alignment.topCenter,
            child: Material(color: Colors.white, child: Text(error!)),
          ),
      ],
    );
  }
}
