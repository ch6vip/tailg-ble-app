# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_blue_plus
-keep class com.lib.flutter_blue_plus.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# geolocator
-keep class com.baseflow.geolocator.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# OkHttp (if used by cloud API)
-dontwarn okhttp3.**
-dontwarn okio.**
