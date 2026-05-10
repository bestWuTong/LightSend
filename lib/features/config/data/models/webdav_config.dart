import '../../../../core/encryption/config_encryptor.dart';

/// WebDAV connection configuration.
class WebdavConfig {
  final String url;
  final String account;
  final String password; // plaintext in memory, encrypted in storage
  final bool? lastTestSucceeded;

  const WebdavConfig({
    required this.url,
    required this.account,
    required this.password,
    this.lastTestSucceeded,
  });

  factory WebdavConfig.empty() => const WebdavConfig(
        url: '',
        account: '',
        password: '',
      );

  bool get isConfigured =>
      url.isNotEmpty && account.isNotEmpty && password.isNotEmpty;

  WebdavConfig copyWith({
    String? url,
    String? account,
    String? password,
    bool? lastTestSucceeded,
    bool clearLastTest = false,
  }) {
    return WebdavConfig(
      url: url ?? this.url,
      account: account ?? this.account,
      password: password ?? this.password,
      lastTestSucceeded:
          clearLastTest ? null : (lastTestSucceeded ?? this.lastTestSucceeded),
    );
  }

  Map<String, dynamic> toJson(ConfigEncryptor encryptor) => {
        'url': url,
        'account': account,
        'password': encryptor.encrypt(password),
        'lastTestSucceeded': lastTestSucceeded,
      };

  factory WebdavConfig.fromJson(
      Map<String, dynamic> json, ConfigEncryptor encryptor) {
    return WebdavConfig(
      url: json['url'] as String? ?? '',
      account: json['account'] as String? ?? '',
      password: _decryptField(json['password'], encryptor),
      lastTestSucceeded: json['lastTestSucceeded'] as bool?,
    );
  }

  static String _decryptField(dynamic value, ConfigEncryptor encryptor) {
    if (value == null) return '';
    try {
      return encryptor.decrypt(value as String);
    } catch (_) {
      return '';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebdavConfig &&
          url == other.url &&
          account == other.account &&
          password == other.password &&
          lastTestSucceeded == other.lastTestSucceeded;

  @override
  int get hashCode => Object.hash(url, account, password, lastTestSucceeded);
}
