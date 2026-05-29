class MapTileConfig {
  static const tiandituToken = String.fromEnvironment('TIANDITU_TOKEN');

  static bool get hasTiandituToken => tiandituToken.trim().isNotEmpty;

  static String get baseUrlTemplate {
    if (hasTiandituToken) {
      return 'https://t{s}.tianditu.gov.cn/DataServer'
          '?T=vec_w&x={x}&y={y}&l={z}&tk=$tiandituToken';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  static String? get annotationUrlTemplate {
    if (!hasTiandituToken) return null;
    return 'https://t{s}.tianditu.gov.cn/DataServer'
        '?T=cva_w&x={x}&y={y}&l={z}&tk=$tiandituToken';
  }

  static List<String> get subdomains {
    if (hasTiandituToken) {
      return const ['0', '1', '2', '3', '4', '5', '6', '7'];
    }
    return const [];
  }

  static String get providerLabel => hasTiandituToken ? '天地图' : 'OSM';
}
