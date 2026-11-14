import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/services/app_controller.dart';
import 'package:mungcation/services/local_repository.dart';

class MemoryRepository implements AppRepository {
  String? raw;
  bool fail = false;
  MemoryRepository([AppData? initial]) {
    if (initial != null) raw = jsonEncode(initial.toJson());
  }
  @override
  Future<AppData> load() async => raw == null
      ? AppData()
      : AppData.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
  @override
  Future<void> save(AppData data) async {
    if (fail) throw Exception('disk');
    raw = jsonEncode(data.toJson());
  }
}

void main() {
  test(
    'insufficient balance and duplicate purchases cannot debit twice',
    () async {
      final c = AppController(MemoryRepository(AppData(coins: 50)));
      await c.load();
      expect(await c.purchase('crown', '왕관', 100), false);
      expect(c.data.coins, 50);
      expect(await c.purchase('cap', '모자', 50), true);
      expect(c.data.coins, 0);
      await c.purchase('cap', '모자', 50);
      expect(c.data.coins, 0);
      expect(c.data.wallet.length, 2);
    },
  );
  test(
    'profile, wallet, equipment and demo records survive a new controller',
    () async {
      final repo = MemoryRepository();
      final c = AppController(repo);
      await c.load();
      await c.commit(
        c.data.copyWith(
          pet: const PetProfile(name: '몽이', breed: '닥스훈트', age: 3, weight: 5.2),
        ),
      );
      await c.finishDemo(90, {'park'}, 30);
      await c.purchase('cap', '모자', 50);
      final restored = AppController(repo);
      await restored.load();
      expect(restored.data.pet!.name, '몽이');
      expect(restored.data.coins, 20);
      expect(restored.data.equipped, 'cap');
      expect(restored.data.walks.single.visits, ['park']);
      expect(restored.data.wallet.length, 3);
      await restored.commit(
        restored.data.copyWith(equipped: 'none', walks: []),
      );
      final next = AppController(repo);
      await next.load();
      expect(next.data.equipped, 'none');
      expect(next.data.walks, isEmpty);
      expect(next.data.owned, contains('cap'));
    },
  );
  test('failed writes leave points and ownership intact', () async {
    final repo = MemoryRepository(AppData(coins: 100));
    final c = AppController(repo);
    await c.load();
    repo.fail = true;
    await expectLater(c.purchase('cap', '모자', 50), throwsException);
    expect(c.data.coins, 100);
    expect(c.data.owned, isEmpty);
    expect(c.busy, false);
  });
  test('corrupt data is not silently overwritten', () async {
    final repo = MemoryRepository()..raw = 'invalid';
    final c = AppController(repo);
    await c.load();
    expect(c.error, isNotNull);
    expect(await c.commit(AppData()), false);
    expect(repo.raw, 'invalid');
  });
}
