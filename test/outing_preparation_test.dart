import 'package:flutter_test/flutter_test.dart';
import 'package:mungcation/models/app_data.dart';
import 'package:mungcation/models/saved_place.dart';
import 'package:mungcation/services/app_controller.dart';
import 'additional_features_test.dart' show savedFixture;
import 'controller_test.dart' show MemoryRepository;

void main() {
  test(
    'failed saves and invalid checklist values never replace saved preparation',
    () async {
      final repository = MemoryRepository();
      final app = AppController(repository);
      await app.load();
      await app.savePlacePreparation(savedFixture(), {'water'});
      repository.fail = true;
      await expectLater(
        app.savePlacePreparation(savedFixture(), {'leash'}),
        throwsException,
      );
      expect(app.data.savedPlaces['park']!.preparation, {'water'});
      expect(
        await app.savePlacePreparation(savedFixture(), {'invented'}),
        false,
      );
      app.dispose();
    },
  );
  test(
    'preparation survives backup serialization and editing private notes',
    () async {
      final app = AppController(MemoryRepository());
      await app.load();
      await app.savePlaceNote(
        savedFixture(),
        '입구 전화 확인',
        PetAccess.outdoorOnly,
      );
      await app.savePlacePreparation(savedFixture(), {'water', 'leash'});
      await app.savePlaceNote(savedFixture(), '새 메모', PetAccess.allowed);
      final restored = AppData.fromJson(app.data.toJson());
      final saved = restored.savedPlaces['park']!;
      expect(saved.preparation, {'water', 'leash'});
      expect(saved.preparedAt, isNotNull);
      expect(saved.note, '새 메모');
      expect(saved.access, PetAccess.allowed);
      expect(saved.place.admission, isNull);
      app.dispose();
    },
  );
  test(
    'legacy favorites remain readable and unknown checklist keys are rejected',
    () {
      final raw = SavedPlace(place: savedFixture()).toJson();
      raw.remove('preparation');
      raw.remove('preparedAt');
      expect(SavedPlace.fromJson(raw).preparation, isEmpty);
      expect(
        () => SavedPlace.fromJson({
          ...raw,
          'preparation': ['invented'],
        }),
        throwsFormatException,
      );
    },
  );
}
