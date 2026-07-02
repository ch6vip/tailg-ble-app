import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocationPage routes vehicle and cloud streams through notifiers', () {
    final source = File('lib/pages/location_page.dart').readAsStringSync();
    final vehiclesListener = _listenerBlock(
      source,
      'vehicleStore.vehiclesStream.listen',
    );
    final cloudListener = _listenerBlock(
      source,
      'officialCloudService.stateStream.listen',
    );

    expect(source, contains('ValueNotifier<OfficialCloudState>'));
    expect(source, contains('ValueNotifier<List<VehicleProfile>>'));
    expect(source, isNot(contains('setState(() {})')));

    expect(vehiclesListener, contains('_vehiclesNotifier.value = v'));
    expect(vehiclesListener, isNot(contains('setState')));
    expect(cloudListener, contains('_cloudStateNotifier.value = c'));
    expect(cloudListener, isNot(contains('setState')));
  });

  test('LocationPage keeps map tab isolated behind RepaintBoundary', () {
    final source = File('lib/pages/location_page.dart').readAsStringSync();

    expect(
      RegExp(r'RepaintBoundary\(\s*child:\s*_MapTab\(').hasMatch(source),
      isTrue,
      reason:
          'The map tab should stay behind RepaintBoundary so parent rebuilds '
          'do not repaint FlutterMap.',
    );
  });
}

String _listenerBlock(String source, String listenerStart) {
  final start = source.indexOf(listenerStart);
  expect(start, isNot(-1), reason: 'Missing $listenerStart');

  final end = source.indexOf('});', start);
  expect(end, isNot(-1), reason: 'Missing end of $listenerStart block');

  return source.substring(start, end + 3);
}
