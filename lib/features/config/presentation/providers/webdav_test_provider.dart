import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/webdav_config.dart';
import '../../services/webdav_service.dart';
import 'config_providers.dart';

/// Connection test provider, keyed by [WebdavConfig].
///
/// Refires automatically when the config values change, discarding
/// the previous test result.
final webdavTestProvider =
    FutureProvider.family<WebdavTestResult, WebdavConfig>((ref, config) async {
  final service = ref.watch(webdavServiceProvider);
  return service.testConnection(config);
});
