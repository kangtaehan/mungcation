import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_data.dart';
import 'local_repository.dart';

class WebRepository implements AppRepository {
  static const key = 'mungcation.web.app.v1';
  final SharedPreferencesAsync preferences;

  WebRepository({SharedPreferencesAsync? preferences})
    : preferences = preferences ?? SharedPreferencesAsync();

  @override
  Future<AppData> load() async {
    final raw = await preferences.getString(key);
    if (raw != null) {
      return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    final initial = AppData(
      pet: const PetProfile(
        name: '몽이',
        breed: '비글',
        age: 3,
        weight: 10,
        size: '중형견',
        temperament: '활발함',
      ),
      furniture: const {
        'plant': [0.1, 0.55],
        'ball': [0.68, 0.68],
      },
    );
    await save(initial);
    return initial;
  }

  @override
  Future<void> save(AppData data) =>
      preferences.setString(key, jsonEncode(data.toJson()));
}
