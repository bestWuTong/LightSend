import 'package:flutter_test/flutter_test.dart';
import 'package:lightsend/core/utils/remote_file_name_helper.dart';

void main() {
  test('adds managed suffix for uploaded regular files', () {
    expect(
      RemoteFileNameHelper.remoteFileNameForUpload('test.apk'),
      'test.apk.lightsendfile',
    );
  });

  test('adds managed suffix for uploaded text messages', () {
    expect(
      RemoteFileNameHelper.remoteTextFileNameForUpload('text_123.txt'),
      'text_123.txt.lightsendtxt',
    );
  });

  test('strips managed suffixes for display and local download names', () {
    expect(
      RemoteFileNameHelper.displayName('test.exe.lightsendfile'),
      'test.exe',
    );
    expect(
      RemoteFileNameHelper.displayName('text_123.txt.lightsendtxt'),
      'text_123.txt',
    );
  });

  test('keeps old or unmanaged filenames unchanged', () {
    expect(RemoteFileNameHelper.displayName('test.apk'), 'test.apk');
    expect(
      RemoteFileNameHelper.displayName('text_123.lightsend.txt'),
      'text_123.lightsend.txt',
    );
    expect(
      RemoteFileNameHelper.isRemoteTextFileName('text_123.lightsend.txt'),
      isFalse,
    );
  });
}
