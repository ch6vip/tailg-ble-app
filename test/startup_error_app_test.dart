import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;

void main() {
  testWidgets('startup errors render a fallback app instead of blank screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      app.StartupErrorApp(
        error: StateError('prefs init failed'),
        stackTrace: StackTrace.fromString('stack line 1\nstack line 2'),
      ),
    );

    expect(find.text('启动失败'), findsOneWidget);
    expect(find.text('应用初始化失败，请重启应用或查看日志。'), findsOneWidget);
    expect(find.textContaining('prefs init failed'), findsOneWidget);
    expect(find.textContaining('stack line 1'), findsOneWidget);
  });
}
