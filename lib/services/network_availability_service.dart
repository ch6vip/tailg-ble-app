import 'package:connectivity_plus/connectivity_plus.dart';

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();

/// Fast link-state probe matching the official app's pre-command network gate.
///
/// Connectivity errors fail open: the MQTT/HTTP layers still provide the
/// authoritative transport error, while a plugin failure must not disable BLE.
class NetworkAvailabilityService {
  NetworkAvailabilityService({
    required ConnectivityCheck checkConnectivity,
    required Stream<List<ConnectivityResult>> connectivityChanges,
  }) : _checkConnectivity = checkConnectivity,
       _connectivityChanges = connectivityChanges;

  factory NetworkAvailabilityService.platform() {
    final connectivity = Connectivity();
    return NetworkAvailabilityService(
      checkConnectivity: connectivity.checkConnectivity,
      connectivityChanges: connectivity.onConnectivityChanged,
    );
  }

  final ConnectivityCheck _checkConnectivity;
  final Stream<List<ConnectivityResult>> _connectivityChanges;

  Future<bool> checkNow({bool fallback = true}) async {
    try {
      return hasNetwork(await _checkConnectivity());
    } on Object {
      return fallback;
    }
  }

  Stream<bool> get changes async* {
    try {
      await for (final results in _connectivityChanges) {
        yield hasNetwork(results);
      }
    } on Object {
      // Keep the last known state when the platform event channel is missing.
    }
  }

  static bool hasNetwork(Iterable<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
