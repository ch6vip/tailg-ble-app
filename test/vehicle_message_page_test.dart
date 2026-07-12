import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/official_cloud_page.dart';
import 'package:tailg_ble_app/pages/vehicle_message_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/snack_finders.dart';
import 'helpers/source_scan.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  test(
    'VehicleMessagePage uses official cloud refresh instead of log mapping',
    () {
      final source = readSource('lib/pages/vehicle_message_page.dart');

      expect(source, contains('refreshMessages'));
      expect(source, isNot(contains('_mapEntry')));
      expect(source, isNot(contains('setState(() {})')));
    },
  );

  test('message bootstrap contains failures and stops after disposal', () {
    final source = readSource('lib/pages/vehicle_message_page.dart');
    final bootstrapStart = source.indexOf('Future<void> _bootstrap()');
    final bootstrapEnd = source.indexOf(
      '  void _syncFromCloudState()',
      bootstrapStart,
    );

    expect(bootstrapStart, greaterThanOrEqualTo(0));
    expect(bootstrapEnd, greaterThan(bootstrapStart));
    final bootstrap = source.substring(bootstrapStart, bootstrapEnd);

    expect(source, contains('_bootstrap().catchError((Object error)'));
    expect(source, contains('OfficialCloudRedactor.errorMessage(error)'));
    expect(
      bootstrap,
      contains('await _loadMessageState();\n    if (!mounted) return;'),
    );
  });

  test('official message models parse vehicle and system records', () {
    final vehicle = OfficialCloudMessage.vehicle({
      'msgId': 'm-1',
      'title': '车辆移动告警',
      'content': '检测到异常移动',
      'sendTime': '2026-07-11 10:20:30',
      'messageCode': 'CAR_WARNING',
      'carId': 'car-1',
    });
    final system = OfficialCloudMessage.system({
      'sysMessageRecordId': 's-1',
      'title': '系统维护通知',
      'content': '今晚 0 点维护',
      'sendTime': '2026-07-11T09:00:00',
      'messageCode': 'APP_UPDATE',
      'url': 'https://example.com',
    });

    expect(vehicle.id, 'vehicle:m-1');
    expect(vehicle.category, OfficialCloudMessageCategory.vehicle);
    expect(vehicle.time.year, 2026);
    expect(system.id, 'system:s-1');
    expect(system.category, OfficialCloudMessageCategory.system);
    expect(system.url, 'https://example.com');
  });

  test('official message parser reads paged records payload', () {
    final source = readSource('lib/services/official_cloud_data_parser.dart');
    expect(source, contains('vehicleMessages'));
    expect(source, contains('systemMessages'));
    expect(source, contains("_pageRecords"));
  });

  setUp(() {
    resetMockPreferences();
    app.officialCloudService.resetForTest();
  });

  tearDown(() {
    app.officialCloudService.resetForTest();
  });

  testWidgets('unsigned page prompts login for official messages', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('请先登录官方账号'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);

    await tester.tap(find.text('去登录'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficialCloudPage), findsOneWidget);
  });

  testWidgets('signed-in page renders official cloud messages', (tester) async {
    setTestViewSize(tester, const Size(430, 1400));
    final vehicleMessage = OfficialCloudMessage.vehicle({
      'msgId': 'vm-1',
      'title': '车辆移动告警',
      'content': '检测到异常移动',
      'sendTime': '2026-07-11 12:00:00',
    });
    final systemMessage = OfficialCloudMessage.system({
      'sysMessageRecordId': 'sm-1',
      'title': '系统维护通知',
      'content': '今晚维护',
      'sendTime': '2026-07-11 11:00:00',
    });
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'uid-1',
        phone: '18812345678',
        vehicleMessages: [vehicleMessage],
        systemMessages: [systemMessage],
      ),
    );

    await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('车辆移动告警'), findsOneWidget);
    expect(find.text('系统维护通知'), findsOneWidget);
    expect(find.text('请先登录官方账号'), findsNothing);
  });

  testWidgets('custom tabs keep 44dp touch targets', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      app.officialCloudService.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          userId: 'uid-1',
        ),
      );
      await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final systemTab = find.ancestor(
        of: find.text('系统消息'),
        matching: find.byType(AppPressable),
      );
      expect(systemTab, findsOneWidget);
      expectMinTouchTargetHeight(tester, systemTab);

      const allLabel = '全部';
      expect(
        tester.getSemantics(find.bySemanticsLabel(allLabel)),
        matchesSemantics(
          label: allLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('clearing messages removes vehicle and system records', (
    tester,
  ) async {
    final vehicleMessage = OfficialCloudMessage.vehicle({
      'msgId': 'vm-clear',
      'title': '车辆移动告警',
      'content': '检测到异常移动',
      'sendTime': '2026-07-11 12:00:00',
    });
    final systemMessage = OfficialCloudMessage.system({
      'sysMessageRecordId': 'sm-clear',
      'title': '系统维护通知',
      'content': '今晚维护',
      'sendTime': '2026-07-11 11:00:00',
    });
    app.officialCloudService.deleteMessagesOverride = () async {};
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'uid-1',
        vehicleMessages: [vehicleMessage],
        systemMessages: [systemMessage],
      ),
    );

    await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('车辆移动告警'), findsOneWidget);
    expect(find.text('系统维护通知'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('已清空 2 条消息'), findsOneWidget);
    expect(snackIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('车辆移动告警'), findsNothing);
    expect(find.text('系统维护通知'), findsNothing);
    expect(app.officialCloudService.state.vehicleMessages, isEmpty);
    expect(app.officialCloudService.state.systemMessages, isEmpty);
  });

  testWidgets('server-side clear failure keeps existing messages', (
    tester,
  ) async {
    final vehicleMessage = OfficialCloudMessage.vehicle({
      'msgId': 'vm-failed-clear',
      'title': '车辆移动告警',
      'content': '检测到异常移动',
      'sendTime': '2026-07-11 12:00:00',
    });
    app.officialCloudService.deleteMessagesOverride = () async {
      throw const OfficialCloudApiException('服务端清空失败');
    };
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'uid-1',
        vehicleMessages: [vehicleMessage],
      ),
    );

    await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('服务端清空失败'), findsOneWidget);
    expect(find.text('车辆移动告警'), findsOneWidget);
    expect(app.officialCloudService.state.vehicleMessages, hasLength(1));
  });

  testWidgets('message rows expose semantics and open detail sheet', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final vehicleMessage = OfficialCloudMessage.vehicle({
        'msgId': 'vm-detail',
        'title': '车辆移动告警',
        'content': '检测到异常移动',
        'sendTime': '2026-07-11 12:00:00',
      });
      app.officialCloudService.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          userId: 'uid-1',
          vehicleMessages: [vehicleMessage],
        ),
      );

      await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      const messageLabel = '车辆移动告警，检测到异常移动，设备消息，未读';
      final messageRow = find.bySemanticsLabel(messageLabel);
      expect(messageRow, findsOneWidget);
      expect(
        tester.getSemantics(messageRow),
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

      expect(find.text('知道了'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
