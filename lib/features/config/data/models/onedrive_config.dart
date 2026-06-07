import '../../../../core/encryption/config_encryptor.dart';

/// Microsoft OneDrive OAuth state.
class OneDriveConfig {
  final String accessToken; // plaintext in memory, encrypted in storage
  final String refreshToken; // plaintext in memory, encrypted in storage
  final DateTime? expiresAt;
  final String displayName;
  final String account;
  final bool? lastTestSucceeded;

  const OneDriveConfig({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.displayName,
    required this.account,
    this.lastTestSucceeded,
  });

  factory OneDriveConfig.empty() => const OneDriveConfig(
    accessToken: '',
    refreshToken: '',
    expiresAt: null,
    displayName: '',
    account: '',
  );

  bool get isConnected => refreshToken.isNotEmpty || accessToken.isNotEmpty;

  bool get hasUsableAccessToken {
    final expiry = expiresAt;
    if (accessToken.isEmpty || expiry == null) return false;
    return expiry.isAfter(DateTime.now().add(const Duration(minutes: 2)));
  }

  OneDriveConfig copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    String? displayName,
    String? account,
    bool? lastTestSucceeded,
    bool clearLastTest = false,
  }) {
    return OneDriveConfig(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      displayName: displayName ?? this.displayName,
      account: account ?? this.account,
      lastTestSucceeded: clearLastTest
          ? null
          : (lastTestSucceeded ?? this.lastTestSucceeded),
    );
  }

  Map<String, dynamic> toJson(ConfigEncryptor encryptor) => {
    'accessToken': encryptor.encrypt(accessToken),
    'refreshToken': encryptor.encrypt(refreshToken),
    'expiresAt': expiresAt?.toIso8601String(),
    'displayName': displayName,
    'account': account,
    'lastTestSucceeded': lastTestSucceeded,
  };

  factory OneDriveConfig.fromJson(
    Map<String, dynamic> json,
    ConfigEncryptor encryptor,
  ) {
    return OneDriveConfig(
      accessToken: _decryptField(json['accessToken'], encryptor),
      refreshToken: _decryptField(json['refreshToken'], encryptor),
      expiresAt: _parseDate(json['expiresAt']),
      displayName: json['displayName'] as String? ?? '',
      account: json['account'] as String? ?? '',
      lastTestSucceeded: json['lastTestSucceeded'] as bool?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
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
      other is OneDriveConfig &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          expiresAt == other.expiresAt &&
          displayName == other.displayName &&
          account == other.account &&
          lastTestSucceeded == other.lastTestSucceeded;

  @override
  int get hashCode => Object.hash(
    accessToken,
    refreshToken,
    expiresAt,
    displayName,
    account,
    lastTestSucceeded,
  );
}
