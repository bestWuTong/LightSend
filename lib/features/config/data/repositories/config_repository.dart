import 'dart:convert';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/encryption/config_encryptor.dart';
import '../../../../core/storage/local_storage.dart';
import '../models/config_model.dart';

/// Persists and loads [ConfigModel] via [LocalStorage].
class ConfigRepository {
  final LocalStorage _storage;
  final ConfigEncryptor _encryptor;

  ConfigRepository(this._storage, this._encryptor);

  /// Loads config from storage. Returns [ConfigModel.defaults] when no config
  /// exists or when the stored data is corrupted.
  Future<ConfigModel> loadConfig() async {
    final raw = await _storage.getString(AppConstants.storageKeyConfig);
    if (raw == null) return ConfigModel.defaults();

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ConfigModel.fromJson(json, _encryptor);
    } catch (_) {
      // Corrupted data — reset to defaults (will be overwritten on next save).
      return ConfigModel.defaults();
    }
  }

  /// Saves [config] to persistent storage.
  Future<void> saveConfig(ConfigModel config) async {
    final json = jsonEncode(config.toJson(_encryptor));
    await _storage.setString(AppConstants.storageKeyConfig, json);
  }

  /// Removes all stored config, resetting to defaults.
  Future<void> clearConfig() async {
    await _storage.remove(AppConstants.storageKeyConfig);
  }
}
