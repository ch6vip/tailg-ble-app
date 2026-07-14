import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/clipboard_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String?> clipboard;

  setUp(() {
    clipboard = <String, String?>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.getData':
              final text = clipboard['text'];
              if (text == null) return null;
              return <String, dynamic>{'text': text};
            case 'Clipboard.setData':
              final args = call.arguments;
              if (args is Map) {
                clipboard['text'] = args['text'] as String?;
              }
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('readClipboardText trims and treats blank as missing', () async {
    clipboard['text'] = '  token-value  ';
    expect(await readClipboardText(), 'token-value');

    clipboard['text'] = '   ';
    expect(await readClipboardText(), isNull);

    clipboard.remove('text');
    expect(await readClipboardText(), isNull);
  });

  test('writeClipboardText stores plain text', () async {
    await writeClipboardText('saved-token');
    expect(clipboard['text'], 'saved-token');
    expect(await readClipboardText(), 'saved-token');
  });
}
