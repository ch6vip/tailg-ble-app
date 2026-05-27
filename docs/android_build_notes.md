# Android 构建说明

## Kotlin incremental cache warning

在 Windows 上执行 `flutter build apk --debug` 时，可能出现 Kotlin daemon/incremental cache warning，典型信息包含：

- `Could not close incremental caches`
- `this and base files have different roots`
- 路径同时包含项目盘符和 Pub Cache 盘符

如果命令最终显示 `Built build\app\outputs\flutter-apk\app-debug.apk` 且退出码为 0，APK 已成功产出。这个 warning 通常与 Windows 跨盘增量编译缓存有关，不代表 APK 构建失败。

建议处理顺序：

1. 先重新执行一次构建，确认是否偶发。
2. 如持续出现，执行 `flutter clean` 后重新 `flutter pub get` 和构建。
3. 如仍持续影响本地开发，再考虑临时关闭 Kotlin incremental 编译或调整 Pub Cache/项目到同一盘符。

当前项目不默认关闭 Kotlin incremental 编译，避免牺牲日常构建速度。
