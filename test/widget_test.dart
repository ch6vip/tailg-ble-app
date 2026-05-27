import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const TailgBleApp());
    expect(find.text('未绑定车辆'), findsOneWidget);
    expect(find.text('扫描'), findsOneWidget);
    expect(find.text('爱车'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
