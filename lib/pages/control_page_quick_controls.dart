part of 'control_page.dart';

class _QuickControlSpec {
  final String id;
  final String label;
  final IconData icon;
  final CommandCode? command;
  final WidgetBuilder? pageBuilder;

  const _QuickControlSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.command,
    this.pageBuilder,
  });
}

List<_QuickControlSpec> get _quickControlSpecs => [
  _QuickControlSpec(
    id: 'soundEffects',
    label: '声音设置',
    icon: Icons.graphic_eq,
    pageBuilder: (_) => const QgjSoundEffectsPage(),
  ),
  _QuickControlSpec(
    id: 'share',
    label: '分享用车',
    icon: Icons.ios_share,
    pageBuilder: (_) => const ShareBikePage(),
  ),
  _QuickControlSpec(
    id: 'fence',
    label: '电子围栏',
    icon: Icons.location_searching,
    pageBuilder: (_) =>
        const LocationPage(initialTab: LocationInitialTab.fence),
  ),
  _QuickControlSpec(
    id: 'nfc',
    label: 'NFC钥匙',
    icon: Icons.nfc,
    pageBuilder: (_) => const NfcKeyPage(),
  ),
  _QuickControlSpec(
    id: 'rideRecord',
    label: '骑行记录',
    icon: Icons.route_outlined,
    pageBuilder: (_) => const RideRecordPage(),
  ),
  const _QuickControlSpec(
    id: 'seat',
    label: '坐垫锁',
    icon: Icons.event_seat_outlined,
    command: CommandCode.openSeat,
  ),
  const _QuickControlSpec(
    id: 'find',
    label: '寻车',
    icon: Icons.volume_up_outlined,
    command: CommandCode.find,
  ),
];

class QuickControlEditPage extends StatefulWidget {
  final QuickControlConfig initialConfig;

  const QuickControlEditPage({super.key, required this.initialConfig});

  @override
  State<QuickControlEditPage> createState() => _QuickControlEditPageState();
}

class _QuickControlEditPageState extends State<QuickControlEditPage> {
  late String _firstActionId;
  late String _secondActionId;

  @override
  void initState() {
    super.initState();
    _firstActionId = widget.initialConfig.firstActionId;
    _secondActionId = widget.initialConfig.secondActionId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '快捷功能设置',
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    QuickControlConfig(
                      firstActionId: _firstActionId,
                      secondActionId: _secondActionId,
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _QuickEditSection(
                    title: '快捷功能1',
                    subtitle: '点击选择快捷功能',
                    selectedId: _firstActionId,
                    specs: _quickControlSpecs
                        .where((spec) => spec.command == null)
                        .toList(growable: false),
                    onSelected: (id) => setState(() => _firstActionId = id),
                  ),
                  _QuickEditSection(
                    title: '快捷功能2',
                    subtitle: '建议放置电子坐垫锁',
                    selectedId: _secondActionId,
                    specs: _quickControlSpecs
                        .where(
                          (spec) =>
                              spec.id == 'seat' ||
                              spec.id == 'find' ||
                              spec.command == null,
                        )
                        .toList(growable: false),
                    onSelected: (id) => setState(() => _secondActionId = id),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      '* 车辆命令仅使用已验证的本地 BLE 控车命令；页面入口不会写入车辆。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickEditSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String selectedId;
  final List<_QuickControlSpec> specs;
  final ValueChanged<String> onSelected;

  const _QuickEditSection({
    required this.title,
    required this.subtitle,
    required this.selectedId,
    required this.specs,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '（$subtitle）',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: specs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, index) {
              final spec = specs[index];
              final selected = spec.id == selectedId;
              return _QuickEditOption(
                spec: spec,
                selected: selected,
                onTap: () => onSelected(spec.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickEditOption extends StatelessWidget {
  final _QuickControlSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _QuickEditOption({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 150);
    const curve = Curves.easeOutCubic;
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(spec.icon, color: color, size: 24),
                      const SizedBox(width: 10),
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          curve: curve,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                          child: Text(
                            spec.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: AnimatedScale(
                    duration: duration,
                    curve: curve,
                    scale: selected ? 1 : 0.6,
                    child: AnimatedOpacity(
                      duration: duration,
                      curve: curve,
                      opacity: selected ? 1 : 0,
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
