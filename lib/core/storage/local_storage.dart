/// Abstract key-value storage interface.
///
/// Enables swapping SharedPreferences for InMemoryStorage in tests.
abstract class LocalStorage {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);

  const LocalStorage();
}
