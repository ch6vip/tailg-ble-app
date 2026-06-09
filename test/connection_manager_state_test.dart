import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/ble/constants.dart';

void main() {
  test(
    'ConnectionManager clears published bike state on runtime reset',
    () async {
      final manager = ConnectionManager();
      final events = <BikeState?>[];
      final sub = manager.bikeStateStream.listen(events.add);
      addTearDown(() async {
        await sub.cancel();
        manager.dispose();
      });

      const state = BikeState(isLocked: true, isPowerOn: false);
      manager.publishBikeStateForTest(state);
      await Future<void>.delayed(Duration.zero);

      expect(manager.latestBikeState, state);
      expect(events, [state]);

      manager.resetCharacteristicsForTest();
      await Future<void>.delayed(Duration.zero);

      expect(manager.latestBikeState, isNull);
      expect(events, [state, null]);
    },
  );
}
