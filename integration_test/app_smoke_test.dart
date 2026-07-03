import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tailg_ble_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup fallback renders in integration test harness', (
    tester,
  ) async {
    await tester.pumpWidget(
      app.StartupErrorApp(
        error: StateError('integration smoke'),
        stackTrace: StackTrace.fromString('stack line 1'),
      ),
    );

    expect(find.text('启动失败'), findsOneWidget);
    expect(find.text('应用初始化失败，请重启应用或查看日志。'), findsOneWidget);
    expect(find.textContaining('integration smoke'), findsOneWidget);
  });
}
