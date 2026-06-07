import '../constants/app_constants.dart';

class RemoteFileNameHelper {
  RemoteFileNameHelper._();

  static String remoteFileNameForUpload(String displayName) {
    if (displayName.endsWith(AppConstants.remoteFileSuffix) ||
        displayName.endsWith(AppConstants.remoteTextSuffix)) {
      return displayName;
    }
    return '$displayName${AppConstants.remoteFileSuffix}';
  }

  static String remoteTextFileNameForUpload(String displayName) {
    if (displayName.endsWith(AppConstants.remoteTextSuffix)) {
      return displayName;
    }
    return '$displayName${AppConstants.remoteTextSuffix}';
  }

  static String displayName(String remoteName) {
    if (remoteName.endsWith(AppConstants.remoteFileSuffix)) {
      return remoteName.substring(
        0,
        remoteName.length - AppConstants.remoteFileSuffix.length,
      );
    }
    if (remoteName.endsWith(AppConstants.remoteTextSuffix)) {
      return remoteName.substring(
        0,
        remoteName.length - AppConstants.remoteTextSuffix.length,
      );
    }
    return remoteName;
  }

  static bool isManagedRemoteName(String remoteName) {
    return remoteName.endsWith(AppConstants.remoteFileSuffix) ||
        remoteName.endsWith(AppConstants.remoteTextSuffix);
  }

  static bool isRemoteTextFileName(String remoteName) {
    return remoteName.startsWith(AppConstants.textFilePrefix) &&
        remoteName.endsWith(AppConstants.remoteTextSuffix);
  }

  static String duplicateDisplayName(String displayName) {
    final dot = displayName.lastIndexOf('.');
    final name = dot > 0 ? displayName.substring(0, dot) : displayName;
    final ext = dot > 0 ? displayName.substring(dot) : '';
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${name}_$ts$ext';
  }
}
