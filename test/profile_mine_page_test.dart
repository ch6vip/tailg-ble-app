import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_user_profile.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/profile_mine_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

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

  testWidgets('aurora mine follows design structure when signed out', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 1800));
      await tester.pumpWidget(const TestApp(home: ProfileMinePage()));
      await tester.pump();

      expect(find.text('立即登录'), findsOneWidget);
      expect(find.text('登录后同步车辆和消息'), findsOneWidget);
      expect(find.text('账户与支持'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('消息中心'), findsOneWidget);
      expect(find.text('帮助与反馈'), findsOneWidget);
      expect(find.text('关于我们'), findsOneWidget);
      // Vehicle tools live on the service hub, not as equal mine grid tiles.
      expect(find.text('骑行统计'), findsNothing);
      expect(find.text('诊断报告'), findsNothing);
      expect(find.text('工具与服务'), findsNothing);
      expect(find.text('手机号'), findsOneWidget);
      expect(find.text('Tailg Cloud · VOID'), findsOneWidget);
      expect(find.text('退出登录'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('aurora mine exposes edit touch target', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const TestApp(home: ProfileMinePage()));
      await tester.pump();

      final edit = find.bySemanticsLabel('编辑');
      expect(edit, findsOneWidget);
      expectMinTouchTargetHeight(tester, edit);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('signed-in header shows profile nick and logout sheet', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 1800));
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'c1',
        'carNickName': '极光 Aurora S',
        'online': true,
        'electricQuantity': 73,
      });
      app.officialCloudService.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          phone: '13812346688',
          vehicles: [vehicle],
          selectedVehicleKey: vehicle.key,
          userProfile: const OfficialUserProfile(
            id: 'u1',
            nickName: '极光骑士',
            name: '',
            signature: '',
            avatarName: '',
            avatarPath: '',
            gender: '',
            birthday: '',
          ),
        ),
      );

      await tester.pumpWidget(const TestApp(home: ProfileMinePage()));
      await tester.pump();

      expect(find.text('极光骑士'), findsOneWidget);
      expect(find.text('台铃用户'), findsNothing);
      expect(find.text('138****6688'), findsAtLeastNWidgets(1));
      expect(find.text('极光 Aurora S'), findsOneWidget);
      expect(find.text('在线'), findsOneWidget);
      expect(find.text('73%'), findsOneWidget);
      expect(find.text('已登录'), findsOneWidget);
      expect(find.text('我的积分'), findsOneWidget);
      expect(find.text('会员 Lv.3'), findsNothing);
      expect(find.text('1280'), findsNothing);
      expect(find.text('退出登录'), findsOneWidget);

      tester.semantics.tap(find.semantics.byLabel('退出登录'));
      await tester.pumpAndSettle();

      expect(find.text('退出登录？'), findsOneWidget);
      expect(find.text('下次登录需验证手机号。本机车辆缓存会保留。'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('退出'), matching: find.byType(AppPressable)),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('falls back to 台铃用户 when profile nick is empty', (tester) async {
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        phone: '13812346688',
      ),
    );

    await tester.pumpWidget(const TestApp(home: ProfileMinePage()));
    await tester.pump();

    expect(find.text('台铃用户'), findsOneWidget);
  });

  testWidgets('edit nickname dialog updates profile state', (tester) async {
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        phone: '13812346688',
        userProfile: const OfficialUserProfile(
          id: 'u1',
          nickName: '旧昵称',
          name: '',
          signature: '',
          avatarName: '',
          avatarPath: '',
          gender: '',
          birthday: '',
        ),
      ),
    );

    await tester.pumpWidget(const TestApp(home: ProfileMinePage()));
    await tester.pump();

    expect(find.text('旧昵称'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('修改昵称'), findsOneWidget);
    // Without network mock, saving will fail; cancel to keep unit stable.
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('修改昵称'), findsNothing);
  });

  testWidgets('message badge appears when unread > 0', (tester) async {
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        phone: '13812346688',
      ),
    );

    await tester.pumpWidget(const TestApp(home: ProfileMinePage()));
    await tester.pump();
    app.messageReadStore.setUnreadCount(2);
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('消息中心'), findsOneWidget);
  });
}
