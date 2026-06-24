part of 'control_page.dart';

class _HomeQuickSection extends StatefulWidget {
  const _HomeQuickSection();

  @override
  State<_HomeQuickSection> createState() => _HomeQuickSectionState();
}

class _HomeQuickSectionState extends State<_HomeQuickSection> {
  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 4),
          _SvcListCard(
            icon: Icons.location_on,
            iconBgColor: AppColors.accentSky.withValues(alpha: 0.14),
            iconColor: AppColors.accentSky,
            title: '车辆定位',
            subtitle: '查看车辆实时位置与导航',
            value: null,
            onTap: () => _open(context, const LocationPage()),
          ),
          const SizedBox(height: 10),
          _SvcListCard(
            icon: Icons.battery_charging_full_outlined,
            iconBgColor: AppColors.accentAmber.withValues(alpha: 0.14),
            iconColor: AppColors.accentAmber,
            title: '电池详情',
            subtitle: 'BMS 电压 · 温度 · 循环次数',
            value: '健康 96%',
            onTap: () => _open(context, const BatteryDetailsPage()),
          ),
          const SizedBox(height: 10),
          _SvcListCard(
            icon: Icons.route_outlined,
            iconBgColor: AppColors.accentViolet.withValues(alpha: 0.14),
            iconColor: AppColors.accentViolet,
            title: '骑行记录',
            subtitle: '轨迹回放 · 里程统计',
            value: null,
            onTap: () => _open(
              context,
              const LocationPage(initialTab: LocationInitialTab.travel),
            ),
          ),
        ],
      ),
    );
  }
}

// ── v8 Service Card ──────────────────────────────────────────────

class _SvcListCard extends StatelessWidget {
  const _SvcListCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppShadows.svcCardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 21, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF98A1AE),
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  value!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF98A1AE)),
          ],
        ),
      ),
    );
  }
}

// Reusable editable list row (used by main_controls part).
class _EditableListRow extends StatelessWidget {
  const _EditableListRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.visible,
    this.lockOff = false,
    this.dragIndex,
    this.onVisibleChanged,
    this.onReorder,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool visible;
  final bool lockOff;
  final int? dragIndex;
  final ValueChanged<bool>? onVisibleChanged;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: AppTextStyles.itemTitle)),
        if (onVisibleChanged != null)
          IconButton(
            icon: Icon(
              visible ? Icons.visibility : Icons.visibility_off,
              size: 20,
            ),
            color: visible ? AppColors.textSecondary : AppColors.textTertiary,
            onPressed: () => onVisibleChanged?.call(!visible),
          ),
        if (onReorder != null && dragIndex != null)
          ReorderableDragStartListener(
            index: dragIndex!,
            child: const Icon(Icons.drag_handle, color: AppColors.textTertiary),
          ),
      ],
    );
  }
}

// ── v8 All-Functions Bottom Sheet ────────────────────────────────

enum _FunctionAction { navigate, toggle }

Future<void> showAllFunctionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _V8AllFunctionsSheet(),
  );
}

class _V8FunctionSpec {
  final IconData icon;
  final String label;
  final _FunctionAction action;
  final bool initialToggle;
  final WidgetBuilder? page;
  final bool badge;
  const _V8FunctionSpec({
    required this.icon,
    required this.label,
    required this.action,
    this.initialToggle = false,
    this.page,
    this.badge = false,
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
        action: _FunctionAction.toggle,
        initialToggle: true,
      ),
      _V8FunctionSpec(
        icon: Icons.volume_up,
        label: '寻车鸣笛',
        action: _FunctionAction.toggle,
      ),
      _V8FunctionSpec(
        icon: Icons.inventory_2_outlined,
        label: '开座桶',
        action: _FunctionAction.toggle,
      ),
      _V8FunctionSpec(
        icon: Icons.power_settings_new,
        label: '远程启动',
        action: _FunctionAction.toggle,
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
  const _V8AllFunctionsSheet();
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
    Navigator.push(context, MaterialPageRoute(builder: page));
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.84;
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.circular(16),
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
                                if (item.action == _FunctionAction.toggle) {
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
                  color: active ? AppColors.energySoft : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active
                        ? const Color(0x5200C896)
                        : AppColors.hairline,
                  ),
                  boxShadow: active ? null : AppShadows.fnIconShadow,
                ),
                child: Icon(
                  spec.icon,
                  size: 23,
                  color: active ? AppColors.primaryDark : AppColors.textPrimary,
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
            ],
          ),
          const SizedBox(height: 6),
          Text(
            spec.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.primaryDark : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
