import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void mockClipboardWrites() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      });
}

void clearPlatformChannelMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null);
}
