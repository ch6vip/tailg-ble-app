import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

final clipboardWrites = <String>[];
final geolocatorMethodCalls = <String>[];

const _geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

void mockClipboardWrites() {
  clipboardWrites.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments;
          if (arguments is Map) {
            clipboardWrites.add(arguments['text']?.toString() ?? '');
          }
          return null;
        }
        return null;
      });
}

void mockGeolocator({
  required bool serviceEnabled,
  LocationPermission checkedPermission = LocationPermission.whileInUse,
  LocationPermission requestedPermission = LocationPermission.whileInUse,
}) {
  geolocatorMethodCalls.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_geolocatorChannel, (call) async {
        geolocatorMethodCalls.add(call.method);
        return switch (call.method) {
          'isLocationServiceEnabled' => serviceEnabled,
          'checkPermission' => _permissionCode(checkedPermission),
          'requestPermission' => _permissionCode(requestedPermission),
          _ => null,
        };
      });
}

void clearPlatformChannelMock() {
  clipboardWrites.clear();
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
