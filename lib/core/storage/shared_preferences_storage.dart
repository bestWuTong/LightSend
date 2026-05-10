import 'package:shared_preferences/shared_preferences.dart';

import 'local_storage.dart';

/// SharedPreferences-backed implementation of [LocalStorage].
class SharedPreferencesStorage implements LocalStorage {
  final SharedPreferences _prefs;

  const SharedPreferencesStorage(this._prefs);

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
