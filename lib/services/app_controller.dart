import '../models/saved_place.dart';
import 'package:flutter/foundation.dart';
import '../models/app_data.dart';
import '../models/walk_data.dart';
import '../models/catalog.dart';
import 'local_repository.dart';

class RewardPolicy {
  static const base = 20,
      park = 30,
      minSeconds = 60,
      minMeters = 100.0,
      dailyCap = 120,
      experience = 20;
  static String day(DateTime value) =>
      '${value.year}-${value.month}-${value.day}';
}

class AppController extends ChangeNotifier {
  final AppRepository repository;
  AppController(this.repository);
  AppData data = AppData();
  bool loading = true;
  int _writes = 0;
  bool get busy => _writes > 0;
  String? error;
  Future<void> _tail = Future.value();
  bool _disposed = false;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    changed();
    try {
      data = await repository.load();
    } catch (_) {
      error = '저장된 데이터를 읽지 못했어요. 다시 시도해 주세요.';
    }
    loading = false;
    changed();
  }

  Future<bool> update(AppData Function(AppData) change) => _write(change);
  Future<bool> restoreData(AppData replacement) {
    if (busy) return Future.value(false);
    return _write((current) {
      if (current.draft != null) throw StateError('진행 중인 산책이 있어요.');
      return replacement;
    }, recover: true);
  }

  Future<bool> _write(
    AppData Function(AppData) change, {
    bool recover = false,
  }) {
    if (loading || (error != null && !recover)) return Future.value(false);
    _writes++;
    changed();
    final action = _tail.then((_) async {
      final next = change(data);
      await repository.save(next);
      data = next;
      if (recover) error = null;
      return true;
    });
    _tail = action.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return action.whenComplete(() {
      _writes--;
      changed();
    });
  }

  Future<bool> commit(AppData next) =>
      busy ? Future.value(false) : update((_) => next);
  Future<bool> purchase(String id, String name, int price) async {
    final item = cosmetics.where((e) => e.id == id).firstOrNull;
    if (item == null ||
        item.price != price ||
        busy ||
        (!data.owned.contains(id) && data.level < item.minLevel))
      return false;
    if (!data.owned.contains(id) && data.coins < price) return false;
    return update((d) {
      final owned = d.owned.contains(id);
      final equipment = {...d.equipment}
        ..removeWhere((e) => slotFor(e) == slotFor(id))
        ..add(id);
      return d.copyWith(
        coins: owned ? d.coins : d.coins - price,
        owned: {...d.owned, id},
        equipment: equipment,
        wallet: owned
            ? d.wallet
            : [WalletEntry('$name 구매', -price, DateTime.now()), ...d.wallet],
      );
    });
  }

  Future<bool> toggleEquipment(String id) {
    if (!data.owned.contains(id)) return Future.value(false);
    return update((d) {
      final selected = {...d.equipment};
      if (!selected.remove(id)) {
        selected.removeWhere((e) => slotFor(e) == slotFor(id));
        selected.add(id);
      }
      return d.copyWith(equipment: selected);
    });
  }

  Future<bool> buyFurniture(String id) {
    final item = furnitureCatalog.where((e) => e.id == id).firstOrNull;
    if (item == null ||
        busy ||
        data.owned.contains(id) ||
        data.coins < item.price)
      return Future.value(false);
    return update(
      (d) => d.copyWith(
        coins: d.coins - item.price,
        owned: {...d.owned, id},
        furniture: {
          ...d.furniture,
          id: [.75, .65],
        },
        wallet: [
          WalletEntry('${item.name} 구매', -item.price, DateTime.now()),
          ...d.wallet,
        ],
      ),
    );
  }

  Future<bool> finishDemo(int seconds, Set<String> visits, int bonus) => update(
    (d) => d.copyWith(
      coins: d.coins + 20 + bonus,
      walks: [
        DemoWalk(DateTime.now(), seconds, 20 + bonus, visits.toList()),
        ...d.walks,
      ],
      wallet: [
        WalletEntry('산책 체험 보상 · 데모', 20 + bonus, DateTime.now()),
        ...d.wallet,
      ],
    ),
  );
  Future<bool> checkpoint(WalkDraft draft) =>
      update((d) => d.copyWith(draft: draft));
  Future<bool> discardDraft() => update((d) => d.copyWith(clearDraft: true));
  Future<WalkRecord?> finishWalk(WalkDraft draft, DateTime now) async {
    WalkRecord? result;
    await update((d) {
      final existing = d.realWalks.where((e) => e.id == draft.id).firstOrNull;
      if (existing != null) {
        result = existing;
        return d.copyWith(clearDraft: true);
      }
      final day = RewardPolicy.day(now),
          earned = d.dailyRewards[RewardPolicy.day(now)] ?? 0;
      final qualifying =
          draft.seconds >= RewardPolicy.minSeconds &&
          trackDistance(draft.samples) >= RewardPolicy.minMeters;
      var remaining = (RewardPolicy.dailyCap - earned).clamp(
        0,
        RewardPolicy.dailyCap,
      );
      final base = qualifying ? remaining.clamp(0, RewardPolicy.base) : 0;
      remaining -= base;
      final confirmed = <Visit>[];
      final ledger = {...d.rewardedPlaces};
      for (final visit in draft.visits) {
        if (!qualifying || remaining <= 0 || ledger[visit.id] == day) continue;
        final points = remaining.clamp(0, RewardPolicy.park);
        remaining -= points;
        ledger[visit.id] = day;
        confirmed.add(Visit(visit.id, visit.name, visit.time, points));
      }
      final points = base + confirmed.fold<int>(0, (a, b) => a + b.points),
          xp = qualifying && base > 0 ? RewardPolicy.experience : 0;
      final record = WalkRecord(
        id: draft.id,
        startedAt: draft.startedAt,
        endedAt: now,
        seconds: draft.seconds,
        points: points,
        xp: xp,
        samples: draft.samples,
        visits: confirmed,
      );
      result = record;
      return d.copyWith(
        coins: d.coins + points,
        xp: d.xp + xp,
        realWalks: [record, ...d.realWalks],
        clearDraft: true,
        rewardedPlaces: ledger,
        dailyRewards: {...d.dailyRewards, day: earned + points},
        wallet: points == 0
            ? d.wallet
            : [WalletEntry('산책 완료 · 앱 포인트', points, now), ...d.wallet],
      );
    });
    return result;
  }

  Future<bool> deleteWalk(String id) => update(
    (d) => d.copyWith(realWalks: d.realWalks.where((w) => w.id != id).toList()),
  );
  Future<bool> deleteAllLocationData() => update(
    (d) => d.copyWith(realWalks: [], clearDraft: true, rewardedPlaces: {}),
  );
  Future<bool> toggleSavedPlace(PlaceInfo place) => update((d) {
    final saved = {...d.savedPlaces};
    if (saved.containsKey(place.id)) {
      saved.remove(place.id);
    } else {
      saved[place.id] = SavedPlace(place: place);
    }
    return d.copyWith(savedPlaces: saved);
  });
  Future<bool> savePlaceNote(PlaceInfo place, String note, PetAccess access) {
    if (note.trim().length > 2000) return Future.value(false);
    return update(
      (d) => d.copyWith(
        savedPlaces: {
          ...d.savedPlaces,
          place.id: SavedPlace(
            place: place,
            note: note.trim(),
            access: access,
            notedAt: DateTime.now(),
          ),
        },
      ),
    );
  }
}
