import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart';

void main() {
  testWidgets('App renders scan page', (WidgetTester tester) async {
    await tester.pumpWidget(const TailgBleApp());
    expect(find.text('Tailg BLE 扫描'), findsOneWidget);
  });
}
