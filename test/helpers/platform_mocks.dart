import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final clipboardWrites = <String>[];

void mockClipboardWrites() {
  clipboardWrites.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments;
          if (arguments is Map) {
            clipboardWrites.add(arguments['text']?.toString() ?? '');
          }
          return null;
        }
        return null;
      });
}

void clearPlatformChannelMock() {
  clipboardWrites.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null);
}
