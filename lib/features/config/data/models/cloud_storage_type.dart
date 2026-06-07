/// Cloud storage backend selected for transfers.
enum CloudStorageType {
  webdav,
  oneDrive;

  String get storageValue {
    switch (this) {
      case CloudStorageType.webdav:
        return 'webdav';
      case CloudStorageType.oneDrive:
        return 'onedrive';
    }
  }

  static CloudStorageType fromStorageValue(String? value) {
    switch (value) {
      case 'onedrive':
        return CloudStorageType.oneDrive;
      case 'webdav':
      default:
        return CloudStorageType.webdav;
    }
  }
}
