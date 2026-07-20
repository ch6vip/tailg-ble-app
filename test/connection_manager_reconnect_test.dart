import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';

import 'helpers/source_scan.dart';

/// P0-1 回归测试：`_disconnectHandled` 重连成功后必须复位，
/// 否则二次断连时 `_onDisconnected()` 直接 return，App 假死。
///
/// 原 Bug：`_attemptReconnect()` 成功路径（connection_manager.dart:806-809）
/// 未复位 `_disconnectHandled`，导致重连成功后再次断连无响应。
void main() {
  group('P0-1: _disconnectHandled reset after reconnect', () {
    test('首次断连标记守卫，重入被拦截，复位后可再次标记', () {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);

      // 初始状态：未处理过断连
      expect(manager.disconnectHandledForTest, isFalse);

      // 首次断连：守卫返回 true，标志位置位
      expect(manager.markDisconnectHandledForTest(), isTrue);
      expect(manager.disconnectHandledForTest, isTrue);

      // 重入：守卫返回 false（已被处理过，拦截重入）
      expect(manager.markDisconnectHandledForTest(), isFalse);
      expect(manager.disconnectHandledForTest, isTrue);

      // 模拟重连成功：复位守卫（P0-1 修复点）
      manager.resetDisconnectHandledForTest();
      expect(manager.disconnectHandledForTest, isFalse);

      // 关键断言：二次断连应能再次触发处理
      expect(manager.markDisconnectHandledForTest(), isTrue);
      expect(manager.disconnectHandledForTest, isTrue);
    });

    test('重连成功路径复位后，允许多轮断连-重连循环', () {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);

      // 模拟 3 轮 断连 → 重连成功 → 断连
      for (int i = 0; i < 3; i++) {
        // 断连
        expect(
          manager.markDisconnectHandledForTest(),
          isTrue,
          reason: '第 ${i + 1} 轮：首次断连应返回 true',
        );
        // 重入被拦
        expect(
          manager.markDisconnectHandledForTest(),
          isFalse,
          reason: '第 ${i + 1} 轮：重入应被拦截',
        );
        // 重连成功 → 复位
        manager.resetDisconnectHandledForTest();
        expect(
          manager.disconnectHandledForTest,
          isFalse,
          reason: '第 ${i + 1} 轮：重连成功后应复位',
        );
      }
    });
  });

  group('reconnect race with successful LOGIN', () {
    test('attemptReconnect exit must not force-disconnect a ready session', () {
      final source = readSource('lib/ble/connection_manager.dart');
      final method = source.indexOf('Future<void> _attemptReconnect()');
      final exit = source.indexOf(
        '_setState(ConnectionState.disconnected);',
        method,
      );
      final guard = source.indexOf(
        'if (_state == ConnectionState.reconnecting)',
        method,
      );

      expect(method, greaterThanOrEqualTo(0));
      expect(guard, greaterThan(method));
      expect(exit, greaterThan(guard));
      expect(source, contains('重连结束（保留当前状态'));
      expect(source, contains('握手期断连，交由 connect() 处理'));
    });

    test('LOGIN cancels in-flight reconnect', () {
      final source = readSource('lib/ble/connection_manager.dart');
      final login = source.indexOf(
        'void _markProtocolLoggedIn(String credential)',
      );
      final cancel = source.indexOf('_reconnectCancelled = true;', login);
      final nextMethod = source.indexOf('void _clearProtocolLogin()', login);

      expect(login, greaterThanOrEqualTo(0));
      expect(cancel, greaterThan(login));
      expect(cancel, lessThan(nextMethod));
    });
  });

  group('MQTT SSL callback', () {
    test('uses Object-typed onBadCertificate to survive mqtt_client cast', () {
      final source = readSource('lib/services/official_mqtt_service.dart');
      expect(
        source,
        contains('bool _trustAllCertificates(Object certificate)'),
      );
      expect(
        source,
        contains('client.onBadCertificate = _trustAllCertificates'),
      );
      expect(source, isNot(contains('client.onBadCertificate = (_) => true')));
    });
  });
}
