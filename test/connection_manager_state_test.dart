import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/ble/constants.dart';

void main() {
  test('heartbeat initial delay uses a cancellable timer', () {
    final source = File('lib/ble/connection_manager.dart').readAsStringSync();

    expect(
      source,
      contains(
        '_heartbeatInitialTimer = Timer(BleTimings.heartbeatInitialDelay',
      ),
    );
    expect(
      source,
      isNot(contains('Future.delayed(BleTimings.heartbeatInitialDelay')),
    );
    expect(source, contains('_heartbeatInitialTimer?.cancel()'));
  });

  test(
    'GATT queue uses priority buckets instead of resorting pending work',
    () {
      final source = File('lib/ble/connection_manager.dart').readAsStringSync();

      expect(source, contains('_gattPendingByPriority'));
      expect(source, contains('_takeNextGattOperation()'));
      expect(source, isNot(contains('_gattPending.sort')));
    },
  );

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

  test('disconnect completes pending QGJ operations immediately', () async {
    final manager = ConnectionManager();
    addTearDown(manager.dispose);

    final commandAck = manager.createPendingCommandAckForTest();
    final response = manager.createPendingQgjResponseForTest(
      QgjCommandIds.lightSensorGet,
    );
    final responseExpectation = expectLater(
      response,
      throwsA(isA<StateError>()),
    );

    await manager.disconnect();

    await expectLater(commandAck, completion(isFalse));
    await responseExpectation;
  });

  testWidgets('ready watchdog disconnects stale connected state', (
    tester,
  ) async {
    final manager = ConnectionManager();
    addTearDown(manager.dispose);

    manager.enterConnectedForTest();
    expect(manager.state, ConnectionState.connected);
    expect(manager.readyWatchdogActiveForTest, isTrue);

    await tester.pump(
      BleTimings.readyHandshakeTimeout - const Duration(milliseconds: 1),
    );
    expect(manager.state, ConnectionState.connected);
    expect(manager.readyWatchdogActiveForTest, isTrue);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(manager.state, ConnectionState.disconnected);
    expect(manager.readyWatchdogActiveForTest, isFalse);
    expect(manager.disconnectHandledForTest, isTrue);
  });

  testWidgets('ready watchdog is disarmed after ready transition', (
    tester,
  ) async {
    final manager = ConnectionManager();
    addTearDown(manager.dispose);

    manager.enterConnectedForTest();
    expect(manager.readyWatchdogActiveForTest, isTrue);

    manager.enterReadyForTest();
    expect(manager.state, ConnectionState.ready);
    expect(manager.readyWatchdogActiveForTest, isFalse);

    await tester.pump(BleTimings.readyHandshakeTimeout);
    await tester.pump();

    expect(manager.state, ConnectionState.ready);
    expect(manager.disconnectHandledForTest, isFalse);
  });

  test(
    'GATT queue runs high priority work before low priority pending work',
    () async {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);

      final releaseFirst = Completer<void>();
      final order = <String>[];

      final first = manager.runGattOperation(() async {
        order.add('first');
        await releaseFirst.future;
        return 'first';
      });
      final low = manager.runGattOperation(() async {
        order.add('low');
        return 'low';
      }, priority: GattOperationPriority.low);
      final high = manager.runGattOperation(() async {
        order.add('high');
        return 'high';
      }, priority: GattOperationPriority.high);

      await Future<void>.delayed(Duration.zero);
      expect(order, ['first']);

      releaseFirst.complete();

      await expectLater(first, completion('first'));
      await expectLater(high, completion('high'));
      await expectLater(low, completion('low'));
      expect(order, ['first', 'high', 'low']);
    },
  );

  test('dispose completes pending QGJ operations immediately', () async {
    final manager = ConnectionManager();

    final commandAck = manager.createPendingCommandAckForTest();
    final response = manager.createPendingQgjResponseForTest(
      QgjCommandIds.lightSensorGet,
    );
    final responseExpectation = expectLater(
      response,
      throwsA(isA<StateError>()),
    );

    manager.dispose();

    await expectLater(commandAck, completion(isFalse));
    await responseExpectation;
  });

  test('dispose is idempotent and ignores later state publications', () {
    final manager = ConnectionManager();

    manager.dispose();

    expect(manager.dispose, returnsNormally);
    expect(
      () => manager.publishBikeStateForTest(
        const BikeState(isLocked: true, isPowerOn: true),
      ),
      returnsNormally,
    );
    expect(manager.resetCharacteristicsForTest, returnsNormally);
  });
}
