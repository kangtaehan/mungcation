import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_data.dart';

abstract interface class AppRepository {
  Future<AppData> load();
  Future<void> save(AppData data);
}

class LocalRepository implements AppRepository {
  final Directory? directory;
  LocalRepository({this.directory});
  static const key = 'mungcation.app.v1';
  Future<File> get file async {
    final dir = directory ?? await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/mungcation.json');
  }

  @override
  Future<AppData> load() async {
    final target = await file;
    if (await target.exists())
      return AppData.fromJson(
        jsonDecode(await target.readAsString()) as Map<String, dynamic>,
      );
    if (directory != null) return AppData();
    final prefs = SharedPreferencesAsync();
    final legacy = await prefs.getString(key);
    final data = legacy == null
        ? AppData()
        : AppData.fromJson(jsonDecode(legacy) as Map<String, dynamic>);
    if (legacy != null) {
      await save(data);
      await prefs.remove(key);
    }
    return data;
  }

  @override
  Future<void> save(AppData data) async {
    final target = await file;
    final temporary = File('${target.path}.pending');
    try {
      await temporary.writeAsString(jsonEncode(data.toJson()), flush: true);
      await temporary.rename(target.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }
}
