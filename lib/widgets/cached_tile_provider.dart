import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// 带磁盘缓存的 flutter_map 瓦片提供器：用 [CachedNetworkImageProvider]
/// 替代默认的纯内存网络瓦片，切页/重启后命中磁盘缓存，省流量并加快二次加载。
class CachedTileProvider extends TileProvider {
  CachedTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: headers,
    );
  }
}
