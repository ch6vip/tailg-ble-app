import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/clipboard_text.dart';

import 'helpers/platform_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(mockClipboardWrites);
  tearDown(clearPlatformChannelMock);

  test('readClipboardText trims and treats blank as missing', () async {
    clipboardData['text'] = '  token-value  ';
    expect(await readClipboardText(), 'token-value');

    clipboardData['text'] = '   ';
    expect(await readClipboardText(), isNull);

    clipboardData.remove('text');
    expect(await readClipboardText(), isNull);
  });

  test('writeClipboardText stores plain text', () async {
    await writeClipboardText('saved-token');
    expect(clipboardData['text'], 'saved-token');
    expect(clipboardWrites, contains('saved-token'));
    expect(await readClipboardText(), 'saved-token');
  });
}
