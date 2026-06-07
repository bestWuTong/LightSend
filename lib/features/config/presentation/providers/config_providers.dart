import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/encryption/config_encryptor.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/utils/path_utils.dart';
import '../../../onedrive/services/onedrive_auth_service.dart';
import '../../../onedrive/services/onedrive_file_service.dart';
import '../../../upload/services/sendto_service.dart';
import '../../data/models/cloud_profile.dart';
import '../../data/models/cloud_storage_type.dart';
import '../../data/models/config_model.dart';
import '../../data/models/download_path_config.dart';
import '../../data/models/onedrive_config.dart';
import '../../data/models/webdav_config.dart';
import '../../data/repositories/config_repository.dart';
import '../../services/webdav_service.dart';

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

final oneDriveAuthServiceProvider = Provider<OneDriveAuthService>(
  (ref) => OneDriveAuthService(),
);

final oneDriveFileServiceProvider = Provider<OneDriveFileService>(
  (ref) => OneDriveFileService(ref.watch(oneDriveAuthServiceProvider)),
);

final sendtoServiceProvider = Provider<SendtoService>((ref) => SendtoService());

final configProvider =
    StateNotifierProvider<ConfigNotifier, AsyncValue<ConfigModel>>((ref) {
      return ConfigNotifier(ref);
    });

class ConfigNotifier extends StateNotifier<AsyncValue<ConfigModel>> {
  static const String _profilesExportType = 'lightsend.cloud_profiles';
  static const String _legacyWebdavProfilesExportType =
      'lightsend.webdav_profiles';

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

  Future<void> updateWebdavConfig(WebdavConfig webdav) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(
      webdav: webdav,
      cloudStorageType: CloudStorageType.webdav,
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
  }

  Future<void> updateOneDriveConfig(OneDriveConfig oneDrive) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(
      oneDrive: oneDrive,
      profiles: _updatedActiveOneDriveProfile(current, oneDrive),
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
  }

  Future<void> setCloudStorageType(CloudStorageType type) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(cloudStorageType: type);
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
  }

  Future<void> disconnectOneDrive() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final fallbackType = current.cloudStorageType == CloudStorageType.oneDrive
        ? CloudStorageType.webdav
        : current.cloudStorageType;
    final updated = current.copyWith(
      oneDrive: OneDriveConfig.empty(),
      cloudStorageType: fallbackType,
    );
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
    try {
      final defaultPath = await PathUtils.getDefaultDownloadPath();
      await updateDownloadPath(defaultPath, isDefault: true);
    } catch (_) {}
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

  Future<bool> saveWebdavProfile(
    String name, {
    String? profileId,
    WebdavConfig? config,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    final profiles = List<CloudProfile>.from(current.profiles);
    final id = profileId ?? const Uuid().v4();
    final cfg = config ?? current.webdav;

    if (profileId != null) {
      final idx = profiles.indexWhere((p) => p.id == profileId);
      if (idx < 0) return false;
      profiles[idx] = CloudProfile.webdav(
        id: profiles[idx].id,
        name: name,
        config: cfg,
        createdAt: profiles[idx].createdAt,
      );
    } else {
      profiles.add(
        CloudProfile.webdav(
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
      cloudStorageType: (isNewProfile || isActiveProfile)
          ? CloudStorageType.webdav
          : current.cloudStorageType,
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
    return true;
  }

  Future<bool> saveOneDriveProfile(
    String name, {
    String? profileId,
    OneDriveConfig? config,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    final profiles = List<CloudProfile>.from(current.profiles);
    final id = profileId ?? const Uuid().v4();
    final cfg = config ?? current.oneDrive;

    if (profileId != null) {
      final idx = profiles.indexWhere((p) => p.id == profileId);
      if (idx < 0) return false;
      profiles[idx] = CloudProfile.oneDrive(
        id: profiles[idx].id,
        name: name,
        config: cfg,
        createdAt: profiles[idx].createdAt,
      );
    } else {
      profiles.add(
        CloudProfile.oneDrive(
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
      oneDrive: (isNewProfile || isActiveProfile) ? cfg : current.oneDrive,
      cloudStorageType: (isNewProfile || isActiveProfile)
          ? CloudStorageType.oneDrive
          : current.cloudStorageType,
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
    return true;
  }

  Future<bool> saveProfile(
    String name, {
    String? profileId,
    WebdavConfig? config,
  }) {
    return saveWebdavProfile(name, profileId: profileId, config: config);
  }

  Future<bool> deleteProfile(String id) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    final profiles = current.profiles.where((p) => p.id != id).toList();
    final isActiveProfile = current.activeProfileId == id;
    final updated = current.copyWith(
      profiles: profiles,
      webdav: isActiveProfile ? WebdavConfig.empty() : current.webdav,
      oneDrive: isActiveProfile ? OneDriveConfig.empty() : current.oneDrive,
      cloudStorageType: isActiveProfile
          ? CloudStorageType.webdav
          : current.cloudStorageType,
      clearActiveProfile: isActiveProfile,
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
    return true;
  }

  String? exportProfiles(List<String> profileIds) {
    final current = state.valueOrNull;
    if (current == null || profileIds.isEmpty) return null;

    final selectedIds = profileIds.toSet();
    final profiles = current.profiles
        .where((profile) => selectedIds.contains(profile.id))
        .toList();
    if (profiles.isEmpty) return null;

    final encryptor = _ref.read(configEncryptorProvider);
    return const JsonEncoder.withIndent('  ').convert({
      'type': _profilesExportType,
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'profiles': profiles.map((profile) => profile.toJson(encryptor)).toList(),
    });
  }

  String? exportWebdavProfiles(List<String> profileIds) {
    return exportProfiles(profileIds);
  }

  Future<int> importProfiles(String rawConfig) async {
    final current = state.valueOrNull;
    if (current == null) return 0;

    final decoded = jsonDecode(rawConfig);
    final List<dynamic> rawProfiles;
    if (decoded is Map<String, dynamic>) {
      final type = decoded['type'];
      if (type != _profilesExportType &&
          type != _legacyWebdavProfilesExportType) {
        throw const FormatException('Unsupported cloud config export format');
      }
      rawProfiles = decoded['profiles'] as List<dynamic>? ?? const [];
    } else if (decoded is List<dynamic>) {
      rawProfiles = decoded;
    } else {
      throw const FormatException('Invalid cloud config export format');
    }

    if (rawProfiles.isEmpty) {
      throw const FormatException('No cloud profiles found');
    }

    final encryptor = _ref.read(configEncryptorProvider);
    final uuid = const Uuid();
    final importedProfiles = <CloudProfile>[];

    for (final rawProfile in rawProfiles) {
      if (rawProfile is! Map<String, dynamic>) {
        throw const FormatException('Invalid cloud profile entry');
      }

      final profile = CloudProfile.fromJson(rawProfile, encryptor);
      if (!profile.isConfigured) {
        throw const FormatException('Invalid cloud profile config');
      }

      importedProfiles.add(_copyImportedProfile(profile, uuid.v4()));
    }

    final shouldActivateFirst =
        current.activeProfileId == null &&
        !current.webdav.isConfigured &&
        !current.oneDrive.isConnected;
    final first = importedProfiles.first;
    final updated = current.copyWith(
      profiles: [...current.profiles, ...importedProfiles],
      activeProfileId: shouldActivateFirst ? first.id : current.activeProfileId,
      webdav: shouldActivateFirst && first.type == CloudStorageType.webdav
          ? first.webdav
          : current.webdav,
      oneDrive: shouldActivateFirst && first.type == CloudStorageType.oneDrive
          ? first.oneDrive
          : current.oneDrive,
      cloudStorageType: shouldActivateFirst
          ? first.type
          : current.cloudStorageType,
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
    return importedProfiles.length;
  }

  Future<int> importWebdavProfiles(String rawConfig) {
    return importProfiles(rawConfig);
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

  Future<bool> activateProfile(String id) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    final profile = current.profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => throw StateError('Profile not found: $id'),
    );

    final updated = current.copyWith(
      webdav: profile.type == CloudStorageType.webdav
          ? profile.webdav
          : current.webdav,
      oneDrive: profile.type == CloudStorageType.oneDrive
          ? profile.oneDrive
          : current.oneDrive,
      activeProfileId: id,
      cloudStorageType: profile.type,
    );
    state = AsyncValue.data(updated);
    await _ref.read(configRepositoryProvider).saveConfig(updated);
    return true;
  }

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

  List<CloudProfile> _updatedActiveOneDriveProfile(
    ConfigModel current,
    OneDriveConfig oneDrive,
  ) {
    final activeProfileId = current.activeProfileId;
    if (activeProfileId == null ||
        current.cloudStorageType != CloudStorageType.oneDrive) {
      return current.profiles;
    }

    return current.profiles.map((profile) {
      if (profile.id != activeProfileId ||
          profile.type != CloudStorageType.oneDrive) {
        return profile;
      }
      return profile.copyWith(oneDrive: oneDrive);
    }).toList();
  }

  CloudProfile _copyImportedProfile(CloudProfile profile, String id) {
    switch (profile.type) {
      case CloudStorageType.webdav:
        return CloudProfile.webdav(
          id: id,
          name: profile.name,
          config: profile.webdav.copyWith(clearLastTest: true),
          createdAt: DateTime.now(),
        );
      case CloudStorageType.oneDrive:
        return CloudProfile.oneDrive(
          id: id,
          name: profile.name,
          config: profile.oneDrive.copyWith(clearLastTest: true),
          createdAt: DateTime.now(),
        );
    }
  }
}
