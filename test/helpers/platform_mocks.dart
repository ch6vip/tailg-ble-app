import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

final clipboardWrites = <String>[];
final clipboardData = <String, String?>{};
final geolocatorMethodCalls = <String>[];

const _geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

/// Mocks platform clipboard get/set for tests.
///
/// Written values are appended to [clipboardWrites] and stored in
/// [clipboardData] under the `'text'` key for read-back assertions.
void mockClipboardWrites() {
  clipboardWrites.clear();
  clipboardData.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'Clipboard.getData':
            final text = clipboardData['text'];
            if (text == null) return null;
            return <String, dynamic>{'text': text};
          case 'Clipboard.setData':
            final arguments = call.arguments;
            if (arguments is Map) {
              final text = arguments['text']?.toString();
              clipboardData['text'] = text;
              clipboardWrites.add(text ?? '');
            }
            return null;
          default:
            return null;
        }
      });
}

void mockGeolocator({
  required bool serviceEnabled,
  LocationPermission checkedPermission = LocationPermission.whileInUse,
  LocationPermission requestedPermission = LocationPermission.whileInUse,
  Map<String, Object?> currentPosition = const {
    'latitude': 31.2304,
    'longitude': 121.4737,
    'accuracy': 8.5,
  },
}) {
  geolocatorMethodCalls.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_geolocatorChannel, (call) async {
        geolocatorMethodCalls.add(call.method);
        return switch (call.method) {
          'isLocationServiceEnabled' => serviceEnabled,
          'checkPermission' => _permissionCode(checkedPermission),
          'requestPermission' => _permissionCode(requestedPermission),
          'getCurrentPosition' => currentPosition,
          _ => null,
        };
      });
}

void clearPlatformChannelMock() {
  clipboardWrites.clear();
  clipboardData.clear();
  geolocatorMethodCalls.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_geolocatorChannel, null);
}

int _permissionCode(LocationPermission permission) {
  return switch (permission) {
    LocationPermission.denied => 0,
    LocationPermission.deniedForever => 1,
    LocationPermission.whileInUse => 2,
    LocationPermission.always => 3,
    LocationPermission.unableToDetermine => throw ArgumentError.value(
      permission,
      'permission',
      'The native method channel cannot represent this web-only value.',
    ),
  };
}
