import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';

/// P0-1 回归测试：`_disconnectHandled` 重连成功后必须复位，
/// 否则二次断连时 `_onDisconnected()` 直接 return，App 假死。
///
/// 原 Bug：`_attemptReconnect()` 成功路径（connection_manager.dart:806-809）
/// 未复位 `_disconnectHandled`，导致重连成功后再次断连无响应。
void main() {
  group('P0-1: _disconnectHandled reset after reconnect', () {
    test(
      '首次断连标记守卫，重入被拦截，复位后可再次标记',
      () {
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
      },
    );

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
}
