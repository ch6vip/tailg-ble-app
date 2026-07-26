import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/network_availability_service.dart';

void main() {
  test('network availability rejects none-only connectivity', () async {
    final service = NetworkAvailabilityService(
      checkConnectivity: () async => [ConnectivityResult.none],
      connectivityChanges: const Stream.empty(),
    );

    expect(await service.checkNow(), isFalse);
    expect(
      NetworkAvailabilityService.hasNetwork([ConnectivityResult.wifi]),
      isTrue,
    );
  });

  test('network availability exposes distinct platform link states', () async {
    final service = NetworkAvailabilityService(
      checkConnectivity: () async => [ConnectivityResult.mobile],
      connectivityChanges: Stream.fromIterable([
        [ConnectivityResult.wifi],
        [ConnectivityResult.none],
      ]),
    );

    expect(await service.checkNow(), isTrue);
    expect(await service.changes.toList(), [isTrue, isFalse]);
  });

  test('network probe failure preserves the caller fallback', () async {
    final service = NetworkAvailabilityService(
      checkConnectivity: () async => throw StateError('plugin unavailable'),
      connectivityChanges: const Stream.empty(),
    );

    expect(await service.checkNow(fallback: false), isFalse);
    expect(await service.checkNow(fallback: true), isTrue);
  });
}
