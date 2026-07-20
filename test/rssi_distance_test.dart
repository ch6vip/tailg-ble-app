import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/rssi_distance.dart';
import 'package:tailg_ble_app/services/induction_mode_service.dart';

void main() {
  group('RSSI distance model (official BleConnectService)', () {
    test('estimateDistanceFromRssiSamples uses log-distance path-loss', () {
      // 10 identical samples of -60 dBm with defaults.
      final d = estimateDistanceFromRssiSamples(List.filled(10, -60));
      expect(d, greaterThan(0));
      // Stronger signal → shorter distance.
      final near = estimateDistanceFromRssiSamples(List.filled(10, -45));
      final far = estimateDistanceFromRssiSamples(List.filled(10, -80));
      expect(near, lessThan(far));
    });

    test('classifyDistance thresholds match official min=2 max=3', () {
      expect(classifyDistance(1.5), RssiProximityAction.approachUnlock);
      expect(classifyDistance(2.0), RssiProximityAction.approachUnlock);
      expect(classifyDistance(2.5), RssiProximityAction.hold);
      expect(classifyDistance(3.0), RssiProximityAction.leaveLock);
      expect(classifyDistance(5.0), RssiProximityAction.leaveLock);
    });

    test('shouldFireRssiAction respects official task latch', () {
      expect(
        shouldFireRssiAction(
          RssiProximityAction.approachUnlock,
          RssiTaskState.idle,
        ),
        isTrue,
      );
      expect(
        shouldFireRssiAction(
          RssiProximityAction.approachUnlock,
          RssiTaskState.locked,
        ),
        isTrue,
      );
      expect(
        shouldFireRssiAction(
          RssiProximityAction.approachUnlock,
          RssiTaskState.poweredOn,
        ),
        isFalse,
      );
      expect(
        shouldFireRssiAction(
          RssiProximityAction.leaveLock,
          RssiTaskState.poweredOn,
        ),
        isTrue,
      );
      expect(
        shouldFireRssiAction(
          RssiProximityAction.leaveLock,
          RssiTaskState.locked,
        ),
        isFalse,
      );
      expect(
        shouldFireRssiAction(RssiProximityAction.hold, RssiTaskState.idle),
        isFalse,
      );
    });
  });

  group('Induction stack routing', () {
    test('modelType → stack table matches ControlFragment families', () {
      expect(InductionModeService.stackForModelType(8), InductionStack.qgj);
      expect(InductionModeService.stackForModelType(283), InductionStack.qgj);
      expect(InductionModeService.stackForModelType(3), InductionStack.tlink);
      expect(InductionModeService.stackForModelType(10), InductionStack.tlink);
      expect(InductionModeService.stackForModelType(14), InductionStack.tlink);
      expect(InductionModeService.stackForModelType(401), InductionStack.tlink);
      expect(InductionModeService.stackForModelType(1), InductionStack.rssi);
      expect(InductionModeService.stackForModelType(2), InductionStack.none);
      expect(InductionModeService.stackForModelType(null), InductionStack.none);
    });
  });
}
