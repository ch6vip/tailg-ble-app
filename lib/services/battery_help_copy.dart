/// Official battery help copy from decompiled strings
/// (`tv_battery_cycle_help_*` / score help).
abstract final class BatteryHelpCopy {
  static const cycleTitle = '关于循环次数';
  static const scoreTitle = '关于电池评分';

  static const cycleSections = <({String title, String body})>[
    (title: '1、什么是电池循环次数？', body: '电池循环次数是电池充放电周期的一种计算方式，将电池每完成60%的充放电计为一次循环。'),
    (
      title: '2、电池循环次数≠充电次数',
      body:
          '一次循环意味着完成电池60%电量的充放电，但不一定意味着进行一次充电。一次循环可通过一次充电完成，也可以分多次充电来完成。例如：您可能一天使用了电池30%的电量，然后将其充满电，第二天同样如此，则会计作一次充电循环，而非两次。',
    ),
    (
      title: '3、了解电池循环次数的意义',
      body:
          '电池的充电循环次数是有上限的，达到最大循环次数后电池性能会明显降低，续航能力缩短。为了获得电池最佳性能和车辆续航，请在达到最大循环次数时更换电池。',
    ),
  ];

  static const scoreSections = <({String title, String body})>[
    (
      title: '1、什么是电池评分？',
      body: '电池评分综合反映电池健康状态，数值越高通常表示电池状态越好。评分由官方云端根据电池上报数据计算。',
    ),
    (title: '2、评分与续航', body: '评分下降时，续航能力可能缩短。请避免长期过放/过充，并在低温环境下合理使用。'),
    (title: '3、何时关注评分', body: '若评分明显下降或与官方 App 不一致，可先下拉刷新电池信息；仍异常请通过官方服务渠道检修。'),
  ];

  static const correctBatteryTitle = '更正电池';
  static const correctBatteryBody =
      '「更正电池」用于确认/更换车辆绑定的电池规格（官方 batterySetUp / 规格选择流程）。\n\n'
      '当前版本已支持查看电池信息与刷新同步；完整更正流程（规格列表、确认提交）将按官方接口继续补齐。\n\n'
      '请先下拉刷新获取最新数据。涉及校准、更换请前往官方服务渠道。';

  static const swapServiceTitle = '换电服务';
  static const swapServiceBody =
      '官方「换电服务」属于独立业务线（站点/订单/绑定），不在当前云端控车复刻范围内。\n\n'
      '本页仅展示电池状态；如需换电，请使用官方台铃智能 App。';
}
