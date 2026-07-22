import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/ble/parser.dart';

import 'helpers/source_scan.dart';

void main() {
  test('heartbeat initial delay uses a cancellable timer', () {
    final source = readSource('lib/ble/connection_manager.dart');

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
      final source = readSource('lib/ble/connection_manager.dart');

      expect(source, contains('_gattPendingByPriority'));
      expect(source, contains('_takeNextGattOperation()'));
      expect(source, contains('BleTimings.gattOperationTimeout'));
      expect(source, isNot(contains('const Duration(seconds: 30)')));
      expect(source, isNot(contains('_gattPending.sort')));
    },
  );

  test('failed-connect recovery logs cleanup disconnect failures', () {
    final source = readSource('lib/ble/connection_manager.dart');

    expect(source, contains('连接失败恢复断开设备失败'));
    expect(source, isNot(contains('catch (_)')));
  });

  test(
    'ConnectionManager clears published bike state on runtime reset',
    () async {
      final manager = ConnectionManager();
      final events = <BikeState?>[];
      final sub = manager.bikeStateStream.listen(events.add);
      addTearDown(() async {
        await sub.cancel();
        await manager.dispose();
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

  test('QGJ command ACK waits on a local completer and clears it safely', () {
    final source = readSource('lib/ble/connection_manager.dart');

    expect(source, contains('final completer = Completer<bool>();'));
    expect(source, contains('return await completer.future.timeout'));
    expect(source, contains('if (identical(_cmdAckCompleter, completer))'));
  });

  test('QGJ command ACK replaces stale completers before waiting', () {
    final source = readSource('lib/ble/connection_manager.dart');
    final sendCommandStart = source.indexOf(
      'Future<bool> sendCommand(CommandCode cmd) async',
    );
    final previousCompleter = source.indexOf(
      'final previous = _cmdAckCompleter;',
      sendCommandStart,
    );
    final previousComplete = source.indexOf(
      'previous.complete(false);',
      previousCompleter,
    );
    final newCompleter = source.indexOf(
      'final completer = Completer<bool>();',
      previousComplete,
    );

    expect(sendCommandStart, greaterThanOrEqualTo(0));
    expect(previousCompleter, greaterThan(sendCommandStart));
    expect(previousComplete, greaterThan(previousCompleter));
    expect(newCompleter, greaterThan(previousComplete));
  });

  test('QGJ command ACK notifications ignore completed completers', () {
    final source = readSource('lib/ble/connection_manager.dart');

    expect(source, contains('final completer = _cmdAckCompleter;'));
    expect(
      source,
      contains('if (completer != null && !completer.isCompleted)'),
    );
    expect(source, contains('completer.complete(response.success);'));
  });

  test(
    'standard command ACK completes only for the matching command type',
    () async {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);

      final lockAck = manager.createPendingStandardCommandAckForTest('01');
      manager.handleStandardResponseForTest(
        const CommandResponse(
          '7803C20100',
          commandType: '01',
          statusCode: '00',
          success: true,
        ),
      );

      await expectLater(lockAck, completion(isTrue));
      expect(manager.latestBikeState?.isLocked, isTrue);
      expect(manager.latestBikeState?.isPowerOn, isFalse);
    },
  );

  test(
    'standard command failure is returned from the device response',
    () async {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);

      final powerAck = manager.createPendingStandardCommandAckForTest('06');
      manager.handleStandardResponseForTest(
        const CommandResponse(
          '7803C206FF',
          commandType: '06',
          statusCode: 'FF',
          success: false,
        ),
      );

      await expectLater(powerAck, completion(isFalse));
      expect(manager.latestBikeState, isNull);
    },
  );

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

  test('unexpected disconnect completes active GATT operation', () async {
    final manager = ConnectionManager();
    final operationStarted = Completer<void>();
    final releaseOperation = Completer<void>();
    addTearDown(manager.dispose);

    final active = manager.runGattOperation(() async {
      operationStarted.complete();
      await releaseOperation.future;
      return 'done';
    });
    await operationStarted.future;

    final activeError = active.then<Object?>(
      (_) => null,
      onError: (Object error, StackTrace stackTrace) => error,
    );

    await manager.handleDisconnectedForTest();
    await expectLater(
      activeError.timeout(const Duration(milliseconds: 50)),
      completion(isA<StateError>()),
    );

    releaseOperation.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'QGJ disconnect goes straight to disconnected without reconnecting',
    () async {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);

      // QGJ (电动车) cuts BLE off after 熄火/休眠. Official app does not
      // auto-reconnect QGJ; mirror that — no reconnecting state, no scan spam.
      // The helper binds a device so the reconnect branch is reachable; the
      // QGJ guard is the only reason we land on disconnected instead.
      manager.enterReadyForQgjWithDeviceForTest();
      expect(manager.state, ConnectionState.ready);

      await manager.handleDisconnectedForTest();

      expect(manager.state, ConnectionState.disconnected);
    },
  );

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

    await manager.dispose();

    await expectLater(commandAck, completion(isFalse));
    await responseExpectation;
  });

  test('dispose completes active GATT operation immediately', () async {
    final manager = ConnectionManager();
    final operationStarted = Completer<void>();
    final releaseOperation = Completer<void>();

    final active = manager.runGattOperation(() async {
      operationStarted.complete();
      await releaseOperation.future;
      return 'done';
    });

    await operationStarted.future;
    final activeExpectation = expectLater(
      active.timeout(const Duration(milliseconds: 50)),
      throwsStateError,
    );
    await manager.dispose();
    await activeExpectation;

    releaseOperation.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test('dispose is idempotent and ignores later state publications', () {
    final manager = ConnectionManager();

    unawaited(manager.dispose());

    expect(manager.dispose, returnsNormally);
    expect(
      () => manager.publishBikeStateForTest(
        const BikeState(isLocked: true, isPowerOn: true),
      ),
      returnsNormally,
    );
    expect(manager.resetCharacteristicsForTest, returnsNormally);
  });

  test('disposed manager rejects new GATT operations', () async {
    final manager = ConnectionManager();
    var called = false;

    await manager.dispose();

    await expectLater(
      manager.runGattOperation(() async {
        called = true;
        return 'should-not-run';
      }),
      throwsStateError,
    );
    expect(called, isFalse);
  });

  test('GATT cleanup clears active operation reference', () {
    final source = readSource('lib/ble/connection_manager.dart');
    final cleanupStart = source.indexOf(
      'void _completePendingGattOperations(Object error)',
    );
    final activeComplete = source.indexOf(
      'active.completer.completeError(error);',
      cleanupStart,
    );
    final clearActive = source.indexOf(
      '_activeGattOperation = null;',
      activeComplete,
    );
    final pendingLoop = source.indexOf(
      'for (final queue in _gattPendingByPriority.values)',
      cleanupStart,
    );

    expect(cleanupStart, greaterThanOrEqualTo(0));
    expect(activeComplete, greaterThan(cleanupStart));
    expect(clearActive, greaterThan(activeComplete));
    expect(clearActive, lessThan(pendingLoop));
  });
}
