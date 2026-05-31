import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lightsend/core/storage/local_storage.dart';
import 'package:lightsend/features/config/data/models/config_model.dart';
import 'package:lightsend/features/config/data/models/webdav_config.dart';
import 'package:lightsend/features/config/presentation/providers/config_providers.dart';

class InMemoryStorage implements LocalStorage {
  final store = <String, String>{};

  @override
  Future<String?> getString(String key) async => store[key];

  @override
  Future<void> setString(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    store.remove(key);
  }
}

void main() {
  test('deleting active WebDAV profile clears active config', () async {
    final container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(InMemoryStorage())],
    );
    addTearDown(container.dispose);

    await _waitForConfig(container);

    final notifier = container.read(configProvider.notifier);
    final saved = await notifier.saveProfile(
      'Test WebDAV',
      config: const WebdavConfig(
        url: 'https://example.com/dav/',
        account: 'user@example.com',
        password: 'secret',
      ),
    );
    expect(saved, isTrue);

    final activeProfileId = container
        .read(configProvider)
        .valueOrNull
        ?.activeProfileId;
    expect(activeProfileId, isNotNull);

    final deleted = await notifier.deleteProfile(activeProfileId!);
    expect(deleted, isTrue);

    final config = container.read(configProvider).valueOrNull!;
    expect(config.profiles, isEmpty);
    expect(config.activeProfileId, isNull);
    expect(config.webdav.isConfigured, isFalse);
    expect(config.webdav.url, isEmpty);
    expect(config.webdav.account, isEmpty);
    expect(config.webdav.password, isEmpty);
  });
}

Future<ConfigModel> _waitForConfig(ProviderContainer container) async {
  final current = container.read(configProvider).valueOrNull;
  if (current != null) return current;

  final completer = Completer<ConfigModel>();
  final subscription = container.listen(configProvider, (_, next) {
    final config = next.valueOrNull;
    if (config != null && !completer.isCompleted) {
      completer.complete(config);
    }
  }, fireImmediately: true);

  final config = await completer.future.timeout(const Duration(seconds: 5));
  subscription.close();
  return config;
}
