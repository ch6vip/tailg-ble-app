part of 'control_page.dart';

class _HomeQuickSection extends StatefulWidget {
  const _HomeQuickSection();

  @override
  State<_HomeQuickSection> createState() => _HomeQuickSectionState();
}

class _HomeQuickSectionState extends State<_HomeQuickSection> {
  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _OfficialMapCard(onTap: () => _open(context, const LocationPage())),
          const SizedBox(height: 10),
          _OfficialNavProjectionCard(
            onTap: () => _open(context, const LocationPage()),
          ),
          const SizedBox(height: 10),
          _OfficialHistoryCard(
            todayCount: logService.byCategory(LogCategory.operation).length,
            onTap: () => _open(
              context,
              const LocationPage(initialTab: LocationInitialTab.travel),
            ),
          ),
          const SizedBox(height: 10),
          _OfficialGpsBanner(
            onTap: () => _open(context, const OfficialCloudPage()),
          ),
          const SizedBox(height: 10),
          _OfficialSettingsCard(
            onVehicleSetting: () => _open(context, const VehicleSettingsPage()),
            onFence: () => _open(
              context,
              const LocationPage(initialTab: LocationInitialTab.fence),
            ),
            onShare: () => _open(context, const ShareBikePage()),
          ),
          const SizedBox(height: 10),
          _OfficialImageBanner(
            asset: 'assets/official_tailg/iv_add_sound_effects_set_qgj.webp',
            semanticsLabel: 'QGJ音效设置',
            onTap: () => _open(context, const QgjSoundEffectsPage()),
          ),
          const SizedBox(height: 10),
          _OfficialNfcCard(onTap: () => _open(context, const NfcKeyPage())),
        ],
      ),
    );
  }
}

// ── Official Control Lower Area ───────────────────────────────────

class _OfficialCardSurface extends StatelessWidget {
  const _OfficialCardSurface({
    required this.child,
    this.height,
    this.onTap,
    this.semanticLabel,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double? height;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F1F1F).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    if (onTap == null) return card;
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: semanticLabel,
      semanticsButton: true,
      semanticsEnabled: true,
      child: card,
    );
  }
}

class _OfficialMapCard extends StatelessWidget {
  const _OfficialMapCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 260,
      onTap: onTap,
      semanticLabel: '车辆定位',
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '车辆定位',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _OfficialArrow(),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            '定位车辆  防盗通知  导航找车',
            style: TextStyle(fontSize: 13, color: AppColors.officialTextMuted),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/official_tailg/iv_control_map_bg.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE7E8EF),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.map_outlined,
                        color: AppColors.officialTextMuted,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x0F000000)),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.location_on,
                    size: 34,
                    color: AppColors.brandRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialNavProjectionCard extends StatelessWidget {
  const _OfficialNavProjectionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      onTap: onTap,
      semanticLabel: '导航投屏',
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.navigation_outlined,
              color: AppColors.brandRed,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '导航投屏',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '车辆仪表切换到地图页 查看导航',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.officialTextMuted,
                  ),
                ),
              ],
            ),
          ),
          _OfficialArrow(),
        ],
      ),
    );
  }
}

class _OfficialHistoryCard extends StatelessWidget {
  const _OfficialHistoryCard({required this.todayCount, required this.onTap});

  final int todayCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 100,
      onTap: onTap,
      semanticLabel: '历史轨迹',
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 84,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD7B3).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/official_tailg/iv_control_histroy_bg.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.route_outlined, color: AppColors.brandRed),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        '历史轨迹',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _OfficialArrow(),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '今日骑行记录',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.officialTextMuted,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      todayCount.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF060606),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      '条',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.officialTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialGpsBanner extends StatelessWidget {
  const _OfficialGpsBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialImageBanner(
      asset: 'assets/official_tailg/iv_add_intelligence_control.png',
      semanticsLabel: '可添加GPS',
      onTap: onTap,
      fallback: _GpsFallback(),
    );
  }
}

class _OfficialImageBanner extends StatelessWidget {
  const _OfficialImageBanner({
    required this.asset,
    required this.semanticsLabel,
    required this.onTap,
    this.fallback,
  });

  final String asset;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: semanticsLabel,
      semanticsButton: true,
      semanticsEnabled: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          asset,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          errorBuilder: (_, __, ___) =>
              fallback ??
              Container(
                height: 100,
                color: AppColors.surface,
                alignment: Alignment.center,
                child: Text(semanticsLabel),
              ),
        ),
      ),
    );
  }
}

class _GpsFallback extends StatelessWidget {
  const _GpsFallback();

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 132,
      padding: const EdgeInsets.only(left: 130, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            '可添加GPS',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '可定位 防盗通知 远程控车等',
            style: TextStyle(fontSize: 14, color: AppColors.officialTextMuted),
          ),
        ],
      ),
    );
  }
}

class _OfficialSettingsCard extends StatelessWidget {
  const _OfficialSettingsCard({
    required this.onVehicleSetting,
    required this.onFence,
    required this.onShare,
  });

  final VoidCallback onVehicleSetting;
  final VoidCallback onFence;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 158,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '功能设置',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _OfficialSettingAction(
                    asset: 'assets/official_tailg/iv_control_setting_set.png',
                    label: '车辆设置',
                    onTap: onVehicleSetting,
                  ),
                ),
                Expanded(
                  child: _OfficialSettingAction(
                    asset: 'assets/official_tailg/iv_control_setting_el.png',
                    label: '电子围栏',
                    onTap: onFence,
                  ),
                ),
                Expanded(
                  child: _OfficialSettingAction(
                    asset: 'assets/official_tailg/iv_control_setting_share.png',
                    label: '分享用车',
                    onTap: onShare,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialSettingAction extends StatelessWidget {
  const _OfficialSettingAction({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsEnabled: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            asset,
            width: 38,
            height: 38,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.settings_outlined, color: AppColors.brandRed),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.officialTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialNfcCard extends StatelessWidget {
  const _OfficialNfcCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 132,
      onTap: onTap,
      semanticLabel: 'NFC钥匙',
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Image.asset(
            'assets/official_tailg/ic_control_nfc.png',
            width: 88,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.nfc, size: 46, color: AppColors.brandRed),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'NFC钥匙',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _OfficialArrow(),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  '刷卡骑行新体验',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.officialTextMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: const [_NfcNote('手机如何添加'), _NfcNote('智能手表如何添加')],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NfcNote extends StatelessWidget {
  const _NfcNote(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEFF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF1F1DF1)),
      ),
    );
  }
}

class _OfficialArrow extends StatelessWidget {
  const _OfficialArrow();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/official_tailg/ic_right_go.png',
      width: 14,
      height: 14,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.chevron_right,
        size: 18,
        color: AppColors.officialTextMuted,
      ),
    );
  }
}

// ── v8 All-Functions Bottom Sheet ────────────────────────────────

enum _FunctionAction { navigate, toggle, command }

Future<void> showAllFunctionsSheet(
  BuildContext context, {
  Future<void> Function(CommandCode cmd)? onControlCommand,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _V8AllFunctionsSheet(onControlCommand: onControlCommand),
  );
}

class _V8FunctionSpec {
  final IconData icon;
  final String label;
  final _FunctionAction action;
  final bool initialToggle;
  final WidgetBuilder? page;
  final bool badge;
  final CommandCode? command;
  const _V8FunctionSpec({
    required this.icon,
    required this.label,
    required this.action,
    this.initialToggle = false,
    this.page,
    this.badge = false,
    this.command,
  });
}

class _V8FunctionGroup {
  final String title;
  final List<_V8FunctionSpec> items;
  const _V8FunctionGroup({required this.title, required this.items});
}

List<_V8FunctionGroup> get _v8FnGroups => [
  _V8FunctionGroup(
    title: '车辆控制',
    items: [
      _V8FunctionSpec(
        icon: Icons.security,
        label: '一键设防',
        action: _FunctionAction.command,
        command: CommandCode.lock,
        initialToggle: true,
      ),
      _V8FunctionSpec(
        icon: Icons.volume_up,
        label: '寻车鸣笛',
        action: _FunctionAction.command,
        command: CommandCode.find,
      ),
      _V8FunctionSpec(
        icon: Icons.inventory_2_outlined,
        label: '开座桶',
        action: _FunctionAction.command,
        command: CommandCode.openSeat,
      ),
      _V8FunctionSpec(
        icon: Icons.power_settings_new,
        label: '远程启动',
        action: _FunctionAction.command,
        command: CommandCode.powerOn,
      ),
    ],
  ),
  _V8FunctionGroup(
    title: '骑行设置',
    items: [
      _V8FunctionSpec(
        icon: Icons.speed,
        label: '定速巡航',
        action: _FunctionAction.toggle,
        initialToggle: true,
      ),
      _V8FunctionSpec(
        icon: Icons.energy_savings_leaf,
        label: '能量回收',
        action: _FunctionAction.toggle,
        initialToggle: true,
      ),
      _V8FunctionSpec(
        icon: Icons.undo,
        label: '倒车辅助',
        action: _FunctionAction.toggle,
      ),
      _V8FunctionSpec(
        icon: Icons.hiking,
        label: '坡道驻车',
        action: _FunctionAction.toggle,
        initialToggle: true,
      ),
    ],
  ),
  _V8FunctionGroup(
    title: '灯光 & 提示',
    items: [
      _V8FunctionSpec(
        icon: Icons.wb_sunny,
        label: '自动大灯',
        action: _FunctionAction.toggle,
        initialToggle: true,
      ),
      _V8FunctionSpec(
        icon: Icons.lightbulb_outline,
        label: '氛围灯',
        action: _FunctionAction.toggle,
        initialToggle: true,
      ),
      _V8FunctionSpec(
        icon: Icons.notifications_outlined,
        label: '转向提示音',
        action: _FunctionAction.toggle,
        initialToggle: true,
      ),
      _V8FunctionSpec(
        icon: Icons.battery_alert,
        label: '低电提醒',
        action: _FunctionAction.toggle,
        initialToggle: true,
      ),
    ],
  ),
  _V8FunctionGroup(
    title: '维护 & 更多',
    items: [
      _V8FunctionSpec(
        icon: Icons.system_update_outlined,
        label: '固件升级',
        action: _FunctionAction.navigate,
        badge: true,
        page: (_) => const OtaPrecheckPage(),
      ),
      _V8FunctionSpec(
        icon: Icons.assignment_outlined,
        label: '保养记录',
        action: _FunctionAction.navigate,
        page: (_) => const QgjSoundEffectsPage(),
      ),
      _V8FunctionSpec(
        icon: Icons.warning_amber_outlined,
        label: '故障诊断',
        action: _FunctionAction.navigate,
        page: (_) => const DiagnosticPage(),
      ),
      _V8FunctionSpec(
        icon: Icons.settings_outlined,
        label: '车辆设置',
        action: _FunctionAction.navigate,
        page: (_) => const VehicleSettingsPage(),
      ),
    ],
  ),
];

class _V8AllFunctionsSheet extends StatefulWidget {
  const _V8AllFunctionsSheet({this.onControlCommand});
  final Future<void> Function(CommandCode cmd)? onControlCommand;

  @override
  State<_V8AllFunctionsSheet> createState() => _V8AllFunctionsSheetState();
}

class _V8AllFunctionsSheetState extends State<_V8AllFunctionsSheet> {
  final Map<String, bool> _toggles = {};
  final _groups = _v8FnGroups;

  @override
  void initState() {
    super.initState();
    for (final g in _groups) {
      for (final item in g.items) {
        _toggles[item.label] = item.initialToggle;
      }
    }
  }

  void _onToggle(String label, bool value) {
    HapticFeedback.selectionClick();
    setState(() => _toggles[label] = value);
  }

  void _onNavigate(BuildContext context, WidgetBuilder page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute<void>(builder: page));
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.84;
    void closeSheet() => Navigator.pop(context);
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: AppColors.pageBgBot,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: AppShadows.sheetShadow,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grip
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.card3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
              child: Row(
                children: [
                  const Text(
                    '全部功能',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  AppPressable(
                    onTap: closeSheet,
                    haptic: false,
                    semanticsLabel: '关闭全部功能',
                    semanticsButton: true,
                    semanticsEnabled: true,
                    semanticsContainer: true,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Groups
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: _groups.length,
                itemBuilder: (context, gi) {
                  final group = _groups[gi];
                  return Padding(
                    padding: EdgeInsets.only(top: gi == 0 ? 0 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.82,
                              ),
                          itemCount: group.items.length,
                          itemBuilder: (context, fi) {
                            final item = group.items[fi];
                            final active = _toggles[item.label] ?? false;
                            return _FnTile(
                              spec: item,
                              active: active,
                              onTap: () {
                                if (item.action == _FunctionAction.command &&
                                    item.command != null) {
                                  widget.onControlCommand?.call(item.command!);
                                  setState(
                                    () => _toggles[item.label] = !active,
                                  );
                                } else if (item.action ==
                                    _FunctionAction.toggle) {
                                  _onToggle(item.label, !active);
                                } else {
                                  _onNavigate(context, item.page!);
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FnTile extends StatelessWidget {
  const _FnTile({
    required this.spec,
    required this.active,
    required this.onTap,
  });
  final _V8FunctionSpec spec;
  final bool active;
  final VoidCallback onTap;

  /// Toggle items without a backing BLE command are UI-only placeholders.
  bool get _isPlaceholderToggle =>
      spec.action == _FunctionAction.toggle && spec.command == null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _isPlaceholderToggle
                      ? AppColors.surfaceContainerLow
                      : active
                      ? AppColors.energySoft
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isPlaceholderToggle
                        ? AppColors.outlineVariant
                        : active
                        ? const Color(0x5200C896)
                        : AppColors.hairline,
                  ),
                  boxShadow: active || _isPlaceholderToggle
                      ? null
                      : AppShadows.fnIconShadow,
                ),
                child: Icon(
                  spec.icon,
                  size: 23,
                  color: _isPlaceholderToggle
                      ? AppColors.textTertiary
                      : active
                      ? AppColors.primaryDark
                      : AppColors.textPrimary,
                ),
              ),
              if (spec.badge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.energyRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              // Placeholder badge for toggle items not yet wired to BLE
              if (_isPlaceholderToggle)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Tooltip(
                    message: '功能开发中，暂不可用',
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.outlineVariant,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 9,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            spec.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isPlaceholderToggle
                  ? AppColors.textTertiary
                  : active
                  ? AppColors.primaryDark
                  : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
