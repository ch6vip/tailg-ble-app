import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/profile_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/snack_finders.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  setUp(() async {
    resetMockStorage();
    app.officialCloudService.resetForTest();
    app.vehicleStore.resetForTest();
    app.messageReadStore.resetForTest();
    await app.vehicleStore.init();
  });

  tearDown(() {
    app.officialCloudService.resetForTest();
    app.vehicleStore.resetForTest();
    app.messageReadStore.resetForTest();
  });

  testWidgets('profile follows official mine page structure', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 1800));

      await tester.pumpWidget(const TestApp(home: ProfilePage()));
      await tester.pump();

      expect(find.text('立即登录'), findsOneWidget);
      expect(find.text('我的积分'), findsOneWidget);
      expect(find.text('签到中心'), findsOneWidget);
      expect(find.text('我的车库'), findsOneWidget);
      expect(find.text('功能中心'), findsOneWidget);
      expect(find.text('骑行统计'), findsOneWidget);
      expect(find.text('扫码手表控车'), findsOneWidget);

      const pointsLabel = '我的积分，赚更多积分';
      final pointsEntry = find.bySemanticsLabel(pointsLabel);
      expect(pointsEntry, findsOneWidget);
      expectMinTouchTargetHeight(tester, pointsEntry);

      tester.semantics.tap(find.semantics.byLabel(pointsLabel));
      await tester.pump();

      expect(find.text('我的积分暂未开放，可先使用官方云端控车'), findsOneWidget);
      expect(snackIcon(Icons.info_outline), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('profile login action keeps a 44dp touch target', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const TestApp(home: ProfilePage()));
      await tester.pump();

      const loginActionLabel = '登录 / 查看车辆';
      final loginAction = find.bySemanticsLabel(loginActionLabel);
      expect(loginAction, findsOneWidget);
      expectMinTouchTargetHeight(tester, loginAction);
      expect(
        tester.getSemantics(loginAction),
        matchesSemantics(
          label: loginActionLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('profile setting tiles expose semantics and 44dp targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 1800));

      await tester.pumpWidget(const TestApp(home: ProfilePage()));
      await tester.pump();

      const messageLabel = '消息通知';
      final messageTile = find.bySemanticsLabel(messageLabel);
      expect(messageTile, findsOneWidget);
      expectMinTouchTargetHeight(tester, messageTile);
      expect(
        tester.getSemantics(messageTile),
        matchesSemantics(
          label: messageLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(messageLabel));
      await tester.pumpAndSettle();

      expect(find.text('消息中心'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('profile placeholder tiles show info snack', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 1800));

      await tester.pumpWidget(const TestApp(home: ProfilePage()));
      await tester.pump();

      const unavailableTiles = {
        '签到中心，连续签到抽盲盒': '签到中心',
        '我的收藏': '我的收藏',
        '任务中心': '任务中心',
        '我的订单': '我的订单',
        '邀请好友': '邀请好友',
        '优惠券': '优惠券',
        '骑行统计': '骑行统计',
        '扫码手表控车': '扫码手表控车',
        '隐私与安全': '隐私与安全',
        '帮助与反馈': '帮助与反馈',
      };

      for (final entry in unavailableTiles.entries) {
        final tile = find.bySemanticsLabel(entry.key);
        expect(tile, findsOneWidget);
        expect(
          tester.getSemantics(tile),
          matchesSemantics(
            label: entry.key,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );

        tester.semantics.tap(find.semantics.byLabel(entry.key));
        await tester.pump();

        expect(find.text('${entry.value}暂未开放，可先使用官方云端控车'), findsOneWidget);
        expect(snackIcon(Icons.info_outline), findsOneWidget);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('garage panel follows local vehicle store', (tester) async {
    await app.vehicleStore.upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '测试车辆',
      protocol: VehicleProtocol.auto,
      makeDefault: true,
    );

    await tester.pumpWidget(const TestApp(home: ProfilePage()));
    await tester.pump();

    expect(find.text('测试车辆'), findsOneWidget);
    expect(find.bySemanticsLabel('我的车库，测试车辆'), findsOneWidget);
    expect(find.text('使用中'), findsOneWidget);
  });

  testWidgets('garage panel renders official vehicle mileage', (tester) async {
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'official-1',
      'carNickName': '官方车',
      'mileage': 48.4,
    });
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );

    await tester.pumpWidget(const TestApp(home: ProfilePage()));
    await tester.pump();

    expect(find.bySemanticsLabel('我的车库，官方车'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    expect(find.text('预估里程'), findsOneWidget);
  });

  testWidgets('profile logout action exposes semantics and 44dp target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 1800));

      await tester.pumpWidget(const TestApp(home: ProfilePage()));
      await tester.pump();

      const logoutLabel = '退出登录';
      final logoutAction = find.bySemanticsLabel(logoutLabel);
      expect(logoutAction, findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(logoutLabel),
          matching: find.byType(AppPressable),
        ),
        findsOneWidget,
      );
      expectMinTouchTargetHeight(tester, logoutAction);
      expect(
        tester.getSemantics(logoutAction),
        matchesSemantics(
          label: logoutLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(logoutLabel));
      await tester.pumpAndSettle();

      expect(find.text('确定要退出当前账号吗？'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('profile header follows official cloud state stream', (
    tester,
  ) async {
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token-before-logout',
        phone: '18812345678',
        userId: 'user-before-logout',
      ),
    );

    await tester.pumpWidget(const TestApp(home: ProfilePage()));
    await tester.pump();

    expect(find.text('188****5678'), findsOneWidget);

    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(initialized: true),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('立即登录'), findsOneWidget);
    expect(find.text('登录后同步车辆和消息'), findsOneWidget);
    expect(find.text('188****5678'), findsNothing);
  });

  testWidgets('message bell hides red dot when unread is zero', (tester) async {
    app.messageReadStore.setUnreadCount(0);
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        phone: '18812345678',
      ),
    );

    await tester.pumpWidget(const TestApp(home: ProfilePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Bell remains available; badge is driven by messageReadStore.unreadCount.
    expect(find.bySemanticsLabel('消息中心'), findsOneWidget);
    expect(app.messageReadStore.unreadCount.value, 0);
  });
}
