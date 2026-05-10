import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lightsend/app.dart';
import 'package:lightsend/core/storage/local_storage.dart';

import 'package:lightsend/features/config/presentation/providers/config_providers.dart';

/// In-memory storage for tests.
class InMemoryStorage implements LocalStorage {
  final _store = <String, String>{};

  @override
  Future<String?> getString(String key) async => _store[key];

  @override
  Future<void> setString(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }
}

void main() {
  testWidgets('App renders config page', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(InMemoryStorage()),
        ],
        child: const LightSendApp(),
      ),
    );

    // Allow async initialization to complete
    await tester.pumpAndSettle();

    // Should render the app title
    expect(find.text('轻传 LightSend'), findsOneWidget);
  });
}
