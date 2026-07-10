import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/status_badge.dart';

void main() {
  testWidgets('status badge exposes its default state to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadge(type: StatusBadgeType.armed)),
        ),
      );

      expect(find.bySemanticsLabel('车辆状态：已设防'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('status badge exposes every default label to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(type: StatusBadgeType.armed),
                StatusBadge(type: StatusBadgeType.idle),
                StatusBadge(type: StatusBadgeType.connected),
                StatusBadge(type: StatusBadgeType.online),
                StatusBadge(type: StatusBadgeType.offline),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('车辆状态：已设防'), findsOneWidget);
      expect(find.bySemanticsLabel('车辆状态：未通电'), findsOneWidget);
      expect(find.bySemanticsLabel('车辆状态：已连接'), findsOneWidget);
      expect(find.bySemanticsLabel('车辆状态：在线'), findsOneWidget);
      expect(find.bySemanticsLabel('车辆状态：离线'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('status badge exposes custom label to semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              type: StatusBadgeType.online,
              label: '云端在线',
              compact: true,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('车辆状态：云端在线'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
