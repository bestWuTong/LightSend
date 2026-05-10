// LightSend Configuration Module — Public API
//
// This barrel file exports the public API of the config module.
// Other feature modules MUST only import from this file, never from
// internal subdirectories (data/, services/, presentation/).
//
// ## Exports:
// - Models: ConfigModel, WebdavConfig, DownloadPathConfig
// - Providers: configProvider, configRepositoryProvider, webdavTestProvider
// - Services: WebdavService, WebdavTestResult

// Data models
export 'data/models/config_model.dart';
export 'data/models/webdav_config.dart';
export 'data/models/webdav_profile.dart';
export 'data/models/download_path_config.dart';

// Public providers
export 'presentation/providers/config_providers.dart'
    show configProvider, configRepositoryProvider, localStorageProvider;
export 'presentation/providers/webdav_test_provider.dart'
    show webdavTestProvider;

// Services (for DI/testing overrides)
export 'services/webdav_service.dart' show WebdavService, WebdavTestResult;
