import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/encryption/config_encryptor.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/utils/path_utils.dart';
import '../../../upload/services/sendto_service.dart';
import '../../data/models/config_model.dart';
import '../../data/models/download_path_config.dart';
import '../../data/models/webdav_config.dart';
import '../../data/models/webdav_profile.dart';
import '../../data/repositories/config_repository.dart';
import '../../services/webdav_service.dart';

// ─── Core infrastructure providers ───────────────────────────────────────────

final localStorageProvider = Provider<LocalStorage>((ref) {
  throw UnimplementedError(
    'localStorageProvider must be overridden in main.dart',
  );
});

final configEncryptorProvider = Provider<ConfigEncryptor>((ref) {
  return ConfigEncryptor(salt: 'lightsend.config.v1.${AppConstants.appName}');
});

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return ConfigRepository(
    ref.watch(localStorageProvider),
    ref.watch(configEncryptorProvider),
  );
});

final webdavServiceProvider = Provider<WebdavService>((ref) => WebdavService());

final sendtoServiceProvider = Provider<SendtoService>((ref) => SendtoService());

// ─── Public config state ─────────────────────────────────────────────────────

final configProvider =
    StateNotifierProvider<ConfigNotifier, AsyncValue<ConfigModel>>((ref) {
      return ConfigNotifier(ref);
    });

class ConfigNotifier extends StateNotifier<AsyncValue<ConfigModel>> {
  final Ref _ref;

  ConfigNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final repository = _ref.read(configRepositoryProvider);
      var config = await repository.loadConfig();

      if (config.downloadPath.path.isEmpty) {
        final defaultPath = await PathUtils.getDefaultDownloadPath();
        config = config.copyWith(
          downloadPath: DownloadPathConfig(path: defaultPath, isDefault: true),
        );
        await repository.saveConfig(config);
      }

      state = AsyncValue.data(config);
    } catch (e, st) {
      debugPrint('[LightSend] Config init error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  // ─── Mutation methods ────────────────────────────────────────────────────

  Future<void> updateWebdavConfig(WebdavConfig webdav) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(webdav: webdav);
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
  }

  Future<void> updateDownloadPath(String path, {bool isDefault = false}) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(
      downloadPath: DownloadPathConfig(path: path, isDefault: isDefault),
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
  }

  Future<void> resetWebdavConfig() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(webdav: WebdavConfig.empty());
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
  }

  Future<void> resetDownloadPath() async {
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      final defaultPath = await PathUtils.getDefaultDownloadPath();
      await updateDownloadPath(defaultPath, isDefault: true);
    } catch (_) {}
  }

  Future<void> setUseCustomFont(bool value) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(useCustomFont: value);
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
  }

  Future<bool> setSendToMenuEnabled(bool value) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    final service = _ref.read(sendtoServiceProvider);
    final success = value
        ? await service.register()
        : await service.unregister();

    if (success) {
      final updated = current.copyWith(sendToMenuEnabled: value);
      state = AsyncValue.data(updated);
      await _ref.read(configRepositoryProvider).saveConfig(updated);
    }

    return success;
  }

  // ─── Profile management ──────────────────────────────────────────────────

  /// Saves a WebDAV config as a named profile.
  /// If [profileId] is provided, updates an existing profile instead of creating.
  /// [config] overrides the current active config (used when editing via dialog).
  Future<bool> saveProfile(
    String name, {
    String? profileId,
    WebdavConfig? config,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    final profiles = List<WebdavProfile>.from(current.profiles);
    final id = profileId ?? const Uuid().v4();
    final cfg = config ?? current.webdav;

    if (profileId != null) {
      // Update existing profile
      final idx = profiles.indexWhere((p) => p.id == profileId);
      if (idx < 0) return false;
      profiles[idx] = profiles[idx].copyWith(name: name, config: cfg);
    } else {
      // Create new profile
      profiles.add(
        WebdavProfile(
          id: id,
          name: name,
          config: cfg,
          createdAt: DateTime.now(),
        ),
      );
    }

    final isNewProfile = profileId == null;
    final isActiveProfile = current.activeProfileId == profileId;
    final updated = current.copyWith(
      profiles: profiles,
      activeProfileId: isNewProfile ? id : current.activeProfileId,
      webdav: (isNewProfile || isActiveProfile) ? cfg : current.webdav,
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
    return true;
  }

  Future<bool> deleteProfile(String id) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    final profiles = current.profiles.where((p) => p.id != id).toList();
    final isActiveProfile = current.activeProfileId == id;
    final updated = current.copyWith(
      profiles: profiles,
      clearActiveProfile: isActiveProfile,
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
    return true;
  }

  Future<bool> renameProfile(String id, String newName) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    final profiles = current.profiles.map((p) {
      return p.id == id ? p.copyWith(name: newName) : p;
    }).toList();

    final updated = current.copyWith(profiles: profiles);
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
    return true;
  }

  /// Switches to a saved profile, copying its config to the active WebDAV config.
  Future<bool> activateProfile(String id) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    final profile = current.profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => throw StateError('Profile not found: $id'),
    );

    final updated = current.copyWith(
      webdav: profile.config,
      activeProfileId: id,
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
    return true;
  }

  // ─── Theme ──────────────────────────────────────────────────────────────

  Future<void> setSeedColor(int color) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(seedColor: color);
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
  }

  Future<void> setThemeMode(String mode) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(themeMode: mode);
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    await _init();
  }
}
