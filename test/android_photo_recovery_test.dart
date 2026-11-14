import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mungcation/services/media_store.dart';
import 'additional_features_test.dart' show picture;

class RecoveredPicker extends ImagePicker {
  LostDataResponse response;
  RecoveredPicker(this.response);
  @override
  Future<LostDataResponse> retrieveLostData() async => response;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'interrupted Android photo selection recovers a durable validated image',
    () async {
      final root = await Directory.systemTemp.createTemp('photo-recovery-');
      final bytes = await picture();
      final picker = RecoveredPicker(
        LostDataResponse(
          files: [XFile.fromData(bytes)],
          type: RetrieveType.image,
        ),
      );
      final media = MediaStore(root: root, picker: picker);
      try {
        final name = await media.recoverLostPhoto();
        expect(name, isNotNull);
        expect(await (await media.resolve(name!)).readAsBytes(), bytes);
        picker.response = LostDataResponse.empty();
        expect(await media.recoverLostPhoto(), isNull);
        picker.response = LostDataResponse(
          files: [XFile.fromData(bytes)],
          type: RetrieveType.video,
        );
        expect(await media.recoverLostPhoto(), isNull);
        picker.response = LostDataResponse(
          exception: PlatformException(code: 'lost'),
        );
        await expectLater(
          media.recoverLostPhoto(),
          throwsA(isA<PlatformException>()),
        );
        picker.response = LostDataResponse(
          files: [
            XFile.fromData(Uint8List.fromList([1, 2, 3])),
          ],
          type: RetrieveType.image,
        );
        await expectLater(media.recoverLostPhoto(), throwsFormatException);
        expect(await (await media.directory).list().length, 1);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
