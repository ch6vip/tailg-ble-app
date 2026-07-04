class MapTileConfig {
  static const tiandituToken = String.fromEnvironment('TIANDITU_TOKEN');

  static bool get hasTiandituToken => tiandituToken.trim().isNotEmpty;

  static String get baseUrlTemplate {
    if (hasTiandituToken) {
      return 'https://t{s}.tianditu.gov.cn/DataServer'
          '?T=vec_w&x={x}&y={y}&l={z}&tk=$tiandituToken';
    }
    return 'https://webrd0{s}.is.autonavi.com/appmaptile'
        '?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';
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
    return const ['1', '2', '3', '4'];
  }

  static String get providerLabel => hasTiandituToken ? '天地图' : '高德地图';
}
