/// Official `BleConnectService.judgeDeviceDistance` RSSI → metres model.
///
/// ```
/// distance = 10 ^ ( (|avgRssi| - rssiA) / (rssiFactor * 10) )
/// ```
/// Defaults match decompiled field initialisers:
/// - [defaultRssiA] = 52.1949
/// - [defaultRssiFactor] = 4.6241
/// - [defaultMinDistanceM] = 2.0  (approach → unlock)
/// - [defaultMaxDistanceM] = 3.0  (leave → lock)
library;

import 'dart:math' as math;

const defaultRssiA = 52.1949;
const defaultRssiFactor = 4.6241;
const defaultMinDistanceM = 2.0;
const defaultMaxDistanceM = 3.0;

/// Rolling window size used by the official service before estimating.
const rssiSampleWindow = 10;

/// Poll interval matching `Thread.sleep(200)` in `startReadRssi`.
const rssiPollInterval = Duration(milliseconds: 200);

double estimateDistanceFromRssiSamples(
  Iterable<int> rssiSamples, {
  double rssiA = defaultRssiA,
  double rssiFactor = defaultRssiFactor,
}) {
  final samples = rssiSamples.toList(growable: false);
  if (samples.isEmpty) {
    throw ArgumentError('rssiSamples must not be empty');
  }
  final avg = samples.fold<int>(0, (sum, v) => sum + v) / samples.length;
  final absAvg = avg.abs();
  return math.pow(10.0, (absAvg - rssiA) / (rssiFactor * 10.0)).toDouble();
}

enum RssiProximityAction {
  /// distance ≤ min → unlock / power on
  approachUnlock,

  /// distance ≥ max → lock / power off
  leaveLock,

  /// between thresholds — hold
  hold,
}

RssiProximityAction classifyDistance(
  double distanceM, {
  double minDistanceM = defaultMinDistanceM,
  double maxDistanceM = defaultMaxDistanceM,
}) {
  if (distanceM <= minDistanceM) return RssiProximityAction.approachUnlock;
  if (distanceM >= maxDistanceM) return RssiProximityAction.leaveLock;
  return RssiProximityAction.hold;
}

/// Official task latch (`mRssiTaskState`): avoid re-firing until opposite side.
enum RssiTaskState { idle, pending, poweredOn, locked }

/// Decide whether a classified action may fire given the last completed state.
bool shouldFireRssiAction(RssiProximityAction action, RssiTaskState state) {
  return switch (action) {
    RssiProximityAction.approachUnlock =>
      state == RssiTaskState.idle || state == RssiTaskState.locked,
    RssiProximityAction.leaveLock =>
      state == RssiTaskState.idle || state == RssiTaskState.poweredOn,
    RssiProximityAction.hold => false,
  };
}
