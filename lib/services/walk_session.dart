import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../models/walk_data.dart';
import 'app_controller.dart';
import 'location_source.dart';

enum WalkStatus { idle, locating, recording, paused, saving }

class WalkSession extends ChangeNotifier with WidgetsBindingObserver {
  final AppController app;
  final LocationSource source;
  final DateTime Function() now;
  WalkSession(this.app, {LocationSource? source, DateTime Function()? now})
    : source = source ?? DeviceLocation(),
      now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
  }
  WalkStatus status = WalkStatus.idle;
  String? error;
  GeoSample? current;
  WalkDraft? _draft;
  List<GeoSample> _samples = [];
  List<Visit> _visits = [];
  final Map<String, DateTime> _dwell = {};
  List<PlaceInfo> places = [];
  StreamSubscription<GeoSample>? _subscription;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int _savedSeconds = 0;
  bool _break = true,
      _disposed = false,
      _checkpointing = false,
      _finishing = false;
  DateTime? _lastVisitFix;
  DateTime? _lastCheckpoint;
  List<GeoSample> get samples => List.unmodifiable(_samples);
  List<Visit> get visits => List.unmodifiable(_visits);
  int get seconds => _savedSeconds + _clock.elapsed.inSeconds;
  double get meters => trackDistance(_samples);
  bool get hasWalk => _draft != null;
  bool get isRecording => status == WalkStatus.recording;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  void recover() {
    final draft = app.data.draft;
    if (draft == null || _draft != null) return;
    _draft = draft;
    _samples = [...draft.samples];
    _visits = [...draft.visits];
    _savedSeconds = draft.seconds;
    status = WalkStatus.paused;
    _break = true;
    changed();
  }

  Future<bool> locate() async {
    if (status == WalkStatus.locating || status == WalkStatus.saving) {
      return false;
    }
    error = null;
    try {
      final sample = await source.prepare(background: false);
      if (_disposed) return false;
      if (sample.valid &&
          !sample.mocked &&
          now().difference(sample.time).abs() <= const Duration(seconds: 30)) {
        current = sample;
      } else {
        throw const LocationFailure('최신 실제 위치를 받지 못했어요. 모의 위치는 사용하지 않아요.');
      }
    } catch (e) {
      error = _message(e);
    }
    changed();
    return error == null && current != null;
  }

  Future<bool> start() async {
    if (status != WalkStatus.idle) return false;
    status = WalkStatus.locating;
    error = null;
    changed();
    try {
      final fix = await source.prepare(background: app.data.backgroundLocation);
      if (_disposed) return false;
      _draft = WalkDraft(
        id: 'walk-${now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}',
        startedAt: now(),
        seconds: 0,
        samples: [],
        visits: [],
      );
      _samples = [];
      _visits = [];
      _dwell.clear();
      _savedSeconds = 0;
      _clock.reset();
      _break = true;
      try {
        if (!await app.checkpoint(snapshot()))
          throw StateError('save unavailable');
      } catch (_) {
        throw const LocationFailure('산책 시작을 저장하지 못했어요. 저장 공간을 확인해 주세요.');
      }
      _begin(fix);
      return true;
    } catch (e) {
      _clock.stop();
      _timer?.cancel();
      await _subscription?.cancel();
      _draft = null;
      status = WalkStatus.idle;
      error = _message(e);
      changed();
      return false;
    }
  }

  void _begin(GeoSample fix) {
    status = WalkStatus.recording;
    _clock.start();
    accept(fix);
    _subscription = source
        .watch(background: app.data.backgroundLocation)
        .listen(
          accept,
          onError: (Object e) {
            error = _message(e);
            unawaited(pause());
          },
          onDone: () {
            if (!_disposed && isRecording) {
              error = '위치 연결이 종료되어 산책을 일시정지했어요.';
              unawaited(pause());
            }
          },
        );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      changed();
      if (_lastCheckpoint == null ||
          now().difference(_lastCheckpoint!).inSeconds >= 10)
        unawaited(checkpoint());
    });
    changed();
  }

  Future<void> resume() async {
    if (status != WalkStatus.paused) return;
    status = WalkStatus.locating;
    error = null;
    changed();
    try {
      final fix = await source.prepare(background: app.data.backgroundLocation);
      if (_disposed) return;
      _break = true;
      _begin(fix);
    } catch (e) {
      _clock.stop();
      _timer?.cancel();
      await _subscription?.cancel();
      _subscription = null;
      status = WalkStatus.paused;
      error = _message(e);
      changed();
    }
  }

  Future<void> pause() async {
    if (status != WalkStatus.recording) return;
    _clock.stop();
    _timer?.cancel();
    status = WalkStatus.paused;
    await _subscription?.cancel();
    _subscription = null;
    _break = true;
    _dwell.clear();
    changed();
    await checkpoint();
  }

  WalkDraft snapshot() => WalkDraft(
    id: _draft!.id,
    startedAt: _draft!.startedAt,
    seconds: seconds,
    samples: _samples,
    visits: _visits,
  );
  Future<void> checkpoint() async {
    if (_draft == null || _checkpointing) return;
    _checkpointing = true;
    try {
      if (await app.checkpoint(snapshot()))
        _lastCheckpoint = now();
      else
        error = '산책 기록 저장을 기다리고 있어요.';
    } catch (_) {
      error = '자동 저장에 실패했어요. 저장 공간을 확인하고 다시 시도해 주세요.';
    } finally {
      _checkpointing = false;
      changed();
    }
  }

  bool accept(GeoSample fix) {
    if (status != WalkStatus.recording) return false;
    if (!fix.valid ||
        fix.mocked ||
        fix.accuracy > 35 ||
        now().difference(fix.time).abs() > const Duration(seconds: 20)) {
      _dwell.clear();
      _lastVisitFix = null;
      error = '정확한 실제 위치를 기다리고 있어요. 모의 위치·오차가 큰 위치는 기록하지 않아요.';
      changed();
      return false;
    }
    final previous = _samples.lastOrNull;
    if (previous != null && !_break) {
      final dt = fix.time.difference(previous.time).inMilliseconds / 1000;
      if (dt <= 0) return false;
      final distance = distanceBetween(previous, fix);
      if (dt <= 90 && distance / dt > 4.5) {
        _dwell.clear();
        _lastVisitFix = null;
        error = '큰 위치 변화가 감지되어 해당 지점은 제외했어요.';
        changed();
        return false;
      }
      if (dt <= 90 &&
          distance < math.max(5, (fix.accuracy + previous.accuracy) * .35)) {
        current = fix;
        error = null;
        _evaluateVisits(fix);
        changed();
        return false;
      }
      if (dt > 90) _break = true;
    }
    final sample = _break ? fix.withBreak() : fix;
    _samples.add(sample);
    _break = false;
    current = fix;
    error = null;
    _evaluateVisits(fix);
    changed();
    return true;
  }

  void _evaluateVisits(GeoSample fix) {
    if (fix.accuracy > 20) {
      _dwell.clear();
      _lastVisitFix = null;
      return;
    }
    if (_lastVisitFix != null &&
        fix.time.difference(_lastVisitFix!).inSeconds > 25)
      _dwell.clear();
    _lastVisitFix = fix.time;
    for (final place in places.where((p) => p.rewardEligible)) {
      if (_visits.any((v) => v.id == place.id) ||
          app.data.rewardedPlaces[place.id] == RewardPolicy.day(now()))
        continue;
      if (distanceBetween(fix, place.location) + fix.accuracy <= 60) {
        final since = _dwell.putIfAbsent(place.id, () => fix.time);
        if (fix.time.difference(since) >= const Duration(seconds: 10))
          _visits.add(Visit(place.id, place.name, fix.time, RewardPolicy.park));
      } else {
        _dwell.remove(place.id);
      }
    }
  }

  Future<WalkRecord?> finish() async {
    if (_draft == null ||
        _finishing ||
        status == WalkStatus.saving ||
        status == WalkStatus.locating)
      return null;
    _finishing = true;
    if (isRecording) await pause();
    status = WalkStatus.saving;
    error = null;
    changed();
    try {
      final result = await app.finishWalk(snapshot(), now());
      if (result != null) {
        _clear();
        _finishing = false;
        return result;
      }
      status = WalkStatus.paused;
      error = '저장하지 못했어요. 다시 종료해 주세요.';
    } catch (_) {
      status = WalkStatus.paused;
      error = '산책 결과를 저장하지 못했어요. 다시 시도해 주세요.';
    }
    _finishing = false;
    changed();
    return null;
  }

  Future<void> discard() async {
    if (_finishing || status == WalkStatus.locating || _draft == null) return;
    if (isRecording) await pause();
    if (await app.discardDraft()) _clear();
  }

  void _clear() {
    _draft = null;
    _samples = [];
    _visits = [];
    _savedSeconds = 0;
    _clock.stop();
    _clock.reset();
    _dwell.clear();
    _lastVisitFix = null;
    status = WalkStatus.idle;
    changed();
  }

  String _message(Object e) => e is LocationFailure
      ? e.message
      : '위치를 가져오지 못했어요. 권한과 네트워크를 확인하고 다시 시도해 주세요.';
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (!app.data.backgroundLocation) {
        unawaited(pause());
      } else {
        unawaited(checkpoint());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _subscription?.cancel();
    _clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
