import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void resetMockPreferences() {
  SharedPreferences.setMockInitialValues({});
}

void resetMockStorage() {
  resetMockPreferences();
  FlutterSecureStorage.setMockInitialValues({});
}
