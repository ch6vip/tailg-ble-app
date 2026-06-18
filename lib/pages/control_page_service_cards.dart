part of 'control_page.dart';

/// A single home-screen shortcut definition. [id] is stable and persisted; the
/// rest (icon/label/accent/page) lives here so the catalog can evolve without a
/// storage migration. Every entry maps to an existing page route only — no
/// BLE/control commands are involved.
class _QuickShortcutSpec {
  final String id;
  final IconData icon;
  final String label;
  final Color accent;
  final WidgetBuilder page;

  const _QuickShortcutSpec({
    required this.id,
    required this.icon,
    required this.label,
    required this.accent,
    required this.page,
  });
}

/// Full catalog of home shortcuts in default order (first 4 match the 方案C
/// mockup; the rest live on the second page of the scroller).
List<_QuickShortcutSpec> get _quickShortcutCatalog => [
  _QuickShortcutSpec(
    id: 'location',
    icon: Icons.location_on,
    label: '位置',
    accent: AppColors.danger,
    page: (_) => const LocationPage(),
  ),
  _QuickShortcutSpec(
    id: 'settings',
    icon: Icons.settings_outlined,
    label: '设置',
    accent: AppColors.accentTeal,
    page: (_) => const VehicleSettingsPage(),
  ),
  _QuickShortcutSpec(
    id: 'fence',
    icon: Icons.fence,
    label: '围栏',
    accent: _serviceAccentViolet,
    page: (_) => const LocationPage(initialTab: LocationInitialTab.fence),
  ),
  _QuickShortcutSpec(
    id: 'sound',
    icon: Icons.music_note,
    label: '音效',
    accent: _serviceAccentAmber,
    page: (_) => const QgjSoundEffectsPage(),
  ),
  _QuickShortcutSpec(
    id: 'share',
    icon: Icons.ios_share,
    label: '分享用车',
    accent: _serviceAccentViolet,
    page: (_) => const ShareBikePage(),
  ),
  _QuickShortcutSpec(
    id: 'nfc',
    icon: Icons.nfc,
    label: 'NFC钥匙',
    accent: AppColors.accentTeal,
    page: (_) => const NfcKeyPage(),
  ),
  _QuickShortcutSpec(
    id: 'travel',
    icon: Icons.route_outlined,
    label: '骑行记录',
    accent: _serviceAccentAmber,
    page: (_) => const LocationPage(initialTab: LocationInitialTab.travel),
  ),
];

class _HomeQuickSection extends StatefulWidget {
  const _HomeQuickSection();

  @override
  State<_HomeQuickSection> createState() => _HomeQuickSectionState();
}

class _HomeQuickSectionState extends State<_HomeQuickSection> {
  QuickShortcutsConfig _config = const QuickShortcutsConfig();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final cfg = await ReplicaFeatureStore().loadQuickShortcutsConfig();
    if (!mounted) return;
    setState(() => _config = cfg);
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  /// Catalog entries ordered per saved config, with any catalog ids missing
  /// from the saved order appended (in catalog order) so newly added shortcuts
  /// still surface after an app update.
  List<_QuickShortcutSpec> _orderedSpecs() {
    final byId = {for (final s in _quickShortcutCatalog) s.id: s};
    final result = <_QuickShortcutSpec>[];
    for (final id in _config.order) {
      final spec = byId.remove(id);
      if (spec != null) result.add(spec);
    }
    for (final s in _quickShortcutCatalog) {
      if (byId.containsKey(s.id)) result.add(s);
    }
    return result;
  }

  Future<void> _editShortcuts(BuildContext context) async {
    final updated = await Navigator.push<QuickShortcutsConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => _QuickShortcutsEditPage(
          specs: _orderedSpecs(),
          hidden: _config.hidden,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _config = updated);
    await ReplicaFeatureStore().saveQuickShortcutsConfig(updated);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _orderedSpecs()
        .where((spec) => !_config.hidden.contains(spec.id))
        .toList(growable: false);
    final items = [
      for (final spec in visible)
        _HomeQuickItem(
          icon: spec.icon,
          label: spec.label,
          accent: spec.accent,
          onTap: () => _open(context, spec.page(context)),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _FunctionSettingsCard(
            items: items,
            onLongPress: () => _editShortcuts(context),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<VehicleProfile>>(
            stream: vehicleStore.vehiclesStream,
            initialData: vehicleStore.vehicles,
            builder: (context, vehicleSnapshot) {
              final localVehicle = vehicleStore.defaultVehicle;
              return StreamBuilder<OfficialCloudState>(
                stream: officialCloudService.stateStream,
                initialData: officialCloudService.state,
                builder: (context, cloudSnapshot) {
                  final cloudState =
                      cloudSnapshot.data ?? officialCloudService.state;
                  final location = cloudState.vehicleLocation;
                  final locationText = location != null && location.hasData
                      ? (location.bleConnectAddress.isNotEmpty
                            ? location.bleConnectAddress
                            : '${location.bleConnectLat}, ${location.bleConnectLng}')
                      : localVehicle?.lastLocation?.coordinateText ?? '暂无车辆位置';
                  final locationTime =
                      location?.bleConnectTime.isNotEmpty == true
                      ? location!.bleConnectTime
                      : localVehicle?.lastLocation?.recordedAt
                                .toString()
                                .split('.')
                                .first ??
                            '待读取';
                  final travelCount = cloudState.travelDays.fold<int>(
                    0,
                    (sum, day) => sum + day.records.length,
                  );
                  final totalMileage = cloudState.travelDays
                      .map((day) => day.totalMileage)
                      .firstWhere(
                        (value) => value.isNotEmpty,
                        orElse: () => '',
                      );
                  final hasGps =
                      cloudState.selectedVehicle?.imeiGps.isNotEmpty == true;
                  final addGpsTitle = hasGps ? '智能控车' : '可添加GPS';
                  final addGpsSubtitle = hasGps
                      ? '远程定位 防盗通知 云端控车'
                      : '可定位 防盗通知 远程控车等';

                  return Column(
                    children: [
                      _VehicleLocationServiceCard(
                        address: locationText,
                        time: locationTime,
                        loading: cloudState.vehicleLocationLoading,
                        onTap: () => _open(context, const LocationPage()),
                      ),
                      const SizedBox(height: 12),
                      _OfficialServiceBannerCard(
                        icon: Icons.route_outlined,
                        title: '历史轨迹',
                        subtitle: travelCount > 0
                            ? '今日骑行记录 $travelCount 条'
                            : totalMileage.isNotEmpty
                            ? '累计轨迹 ${totalMileage}km'
                            : '今日骑行记录',
                        accent: _serviceAccentAmber,
                        onTap: () => _open(
                          context,
                          const LocationPage(
                            initialTab: LocationInitialTab.travel,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _OfficialServiceBannerCard(
                        icon: Icons.add_location_alt_outlined,
                        title: addGpsTitle,
                        subtitle: addGpsSubtitle,
                        accent: AppColors.accentTeal,
                        onTap: () => _open(context, const OfficialCloudPage()),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          _SoundEffectsServiceCard(
            onTap: () => _open(context, const QgjSoundEffectsPage()),
          ),
          const SizedBox(height: 12),
          _NfcServiceCard(onTap: () => _open(context, const NfcKeyPage())),
          const SizedBox(height: 12),
          const _BleRenewalServiceCard(),
          const SizedBox(height: 12),
          const _ChargingStationServiceCard(),
        ],
      ),
    );
  }
}

class _FunctionSettingsCard extends StatefulWidget {
  final List<_HomeQuickItem> items;
  final VoidCallback? onLongPress;

  const _FunctionSettingsCard({required this.items, this.onLongPress});

  @override
  State<_FunctionSettingsCard> createState() => _FunctionSettingsCardState();
}

class _FunctionSettingsCardState extends State<_FunctionSettingsCard> {
  static const _horizontalPadding = 16.0;
  static const _itemWidth = 86.0;
  static const _separatorWidth = 6.0;

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _itemsOverflow(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || widget.items.isEmpty) return false;
    final contentWidth =
        _horizontalPadding * 2 +
        widget.items.length * _itemWidth +
        math.max(0, widget.items.length - 1) * _separatorWidth;
    return contentWidth > constraints.maxWidth + 0.5;
  }

  double _scrollProgress() {
    if (!_scrollController.hasClients) return 0;
    final position = _scrollController.position;
    // The controller can be attached but not yet laid out (e.g. the very first
    // build of the AnimatedBuilder below), at which point maxScrollExtent /
    // pixels are still unset and reading them throws. Bail out until the
    // horizontal list has real content dimensions.
    if (!position.hasContentDimensions || !position.hasPixels) return 0;
    final maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0) return 0;
    return (position.pixels / maxExtent).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollable = _itemsOverflow(constraints);
        return Container(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
          decoration: _cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  children: [
                    const Text(
                      'SHORTCUTS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    if (widget.onLongPress != null)
                      InkWell(
                        onTap: widget.onLongPress,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.tune,
                                size: 14,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '编辑',
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: _separatorWidth),
                  itemBuilder: (context, index) => SizedBox(
                    width: _itemWidth,
                    child: _HomeQuickTile(
                      item: widget.items[index],
                      onLongPress: widget.onLongPress,
                    ),
                  ),
                ),
              ),
              if (!scrollable)
                const SizedBox(height: 10)
              else
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: AnimatedBuilder(
                    animation: _scrollController,
                    builder: (context, _) {
                      return Center(
                        child: SizedBox(
                          key: const Key('quickFunctionScrollIndicator'),
                          width: 60,
                          height: 4,
                          child: _ScrollPositionIndicator(
                            progress: _scrollProgress(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ScrollPositionIndicator extends StatelessWidget {
  final double progress;

  const _ScrollPositionIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    const trackWidth = 60.0;
    const thumbWidth = 30.0;
    final left = (trackWidth - thumbWidth) * progress;

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: ColoredBox(
        color: const Color(0xFFDFDFDF),
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: 0,
              bottom: 0,
              child: Container(
                width: thumbWidth,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeQuickItem {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _HomeQuickItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });
}

class _HomeQuickTile extends StatelessWidget {
  final _HomeQuickItem item;
  final VoidCallback? onLongPress;

  const _HomeQuickTile({required this.item, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: item.onTap,
      onLongPress: onLongPress,
      radius: AppRadii.card,
      background: Colors.transparent,
      pressedBackground: _officialPressedBg,
      shadow: false,
      child: SizedBox(
        height: 92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, size: AppIconSizes.lg, color: item.accent),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.smallText.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edit page for the home "SHORTCUTS" grid: drag to reorder, toggle to show or
/// hide each shortcut. Returns the updated [QuickShortcutsConfig] (or null when
/// dismissed). No control/BLE logic — only which navigation shortcuts appear.
class _QuickShortcutsEditPage extends StatefulWidget {
  final List<_QuickShortcutSpec> specs;
  final Set<String> hidden;

  const _QuickShortcutsEditPage({required this.specs, required this.hidden});

  @override
  State<_QuickShortcutsEditPage> createState() =>
      _QuickShortcutsEditPageState();
}

class _QuickShortcutsEditPageState extends State<_QuickShortcutsEditPage> {
  late List<_QuickShortcutSpec> _order;
  late Set<String> _hidden;

  @override
  void initState() {
    super.initState();
    _order = List.of(widget.specs);
    _hidden = Set.of(widget.hidden);
  }

  int get _visibleCount =>
      _order.where((spec) => !_hidden.contains(spec.id)).length;

  void _save() {
    Navigator.pop(
      context,
      QuickShortcutsConfig(
        order: _order.map((spec) => spec.id).toList(),
        hidden: _hidden,
      ),
    );
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
              actions: [TextButton(onPressed: _save, child: const Text('保存'))],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '拖动排序，开关控制是否在首页显示（至少保留 1 个）',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                physics: const BouncingScrollPhysics(),
                itemCount: _order.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _order.removeAt(oldIndex);
                    _order.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final spec = _order[index];
                  final visible = !_hidden.contains(spec.id);
                  // Don't let the user hide the last visible shortcut, so the
                  // home grid (and its edit entry) never becomes empty.
                  final lockOff = visible && _visibleCount <= 1;
                  return Padding(
                    key: ValueKey(spec.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EditableListRow(
                      icon: spec.icon,
                      label: spec.label,
                      accent: spec.accent,
                      visible: visible,
                      lockOff: lockOff,
                      dragIndex: index,
                      onVisibleChanged: (value) {
                        setState(() {
                          if (value) {
                            _hidden.remove(spec.id);
                          } else {
                            _hidden.add(spec.id);
                          }
                        });
                      },
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

class _EditableListRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool visible;
  final bool lockOff;
  final int dragIndex;
  final ValueChanged<bool> onVisibleChanged;

  const _EditableListRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.visible,
    required this.lockOff,
    required this.dragIndex,
    required this.onVisibleChanged,
  });

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 150);
    const curve = Curves.easeOutCubic;
    final effectiveOpacity = visible ? 1.0 : 0.52;
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: visible ? AppColors.surface : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: visible ? AppShadows.elevation1 : null,
      ),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: effectiveOpacity,
            duration: duration,
            curve: curve,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: visible ? 0.1 : 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: AppIconSizes.md, color: accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: duration,
              curve: curve,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: visible ? AppColors.textPrimary : AppColors.textTertiary,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          Switch(value: visible, onChanged: lockOff ? null : onVisibleChanged),
          ReorderableDragStartListener(
            index: dragIndex,
            child: const SizedBox(
              width: 34,
              height: 40,
              child: Icon(Icons.drag_handle, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleLocationServiceCard extends StatelessWidget {
  final String address;
  final String time;
  final bool loading;
  final VoidCallback onTap;

  const _VehicleLocationServiceCard({
    required this.address,
    required this.time,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ServiceCardHeader(
                  title: '车辆定位',
                  trailing: loading ? '刷新中' : time,
                ),
                const SizedBox(height: 8),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionLabelStrong,
                ),
                const SizedBox(height: 12),
                const Expanded(child: _MiniMapPreview()),
              ],
            ),
            if (loading)
              const Positioned(
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfficialServiceBannerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _OfficialServiceBannerCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      child: SizedBox(
        height: 92,
        child: Stack(
          children: [
            Positioned.fill(
              child: _SweepHighlight(color: accent.withValues(alpha: 0.2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _ServiceIconBox(icon: icon, color: accent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ServiceTitle(title),
                        const SizedBox(height: 7),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: AppIconSizes.md,
                    color: AppColors.textTertiary,
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

class _SoundEffectsServiceCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SoundEffectsServiceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      child: SizedBox(
        height: 92,
        child: Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SoundWavePainter(color: _serviceAccentAmber),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const _ServiceIconBox(
                    icon: Icons.graphic_eq,
                    color: _serviceAccentAmber,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _ServiceTitle('音效设置'),
                        const SizedBox(height: 7),
                        Text(
                          'QGJ 个性化提示音',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: AppIconSizes.md,
                    color: AppColors.textTertiary,
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

class _NfcServiceCard extends StatelessWidget {
  final VoidCallback onTap;

  const _NfcServiceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _ServiceIconBox(
              icon: Icons.nfc,
              color: _serviceAccentViolet,
              size: 58,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ServiceTitle('NFC钥匙'),
                  const SizedBox(height: 6),
                  const Text(
                    '刷卡骑行新体验',
                    style: AppTextStyles.sectionLabelStrong,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: const [
                      _MiniHelpChip('手机如何添加'),
                      _MiniHelpChip('智能手表如何添加'),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _BleRenewalServiceCard extends StatelessWidget {
  const _BleRenewalServiceCard();

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      enabled: false,
      onTap: () {},
      background: AppColors.surfaceContainerLow,
      pressedBackground: _officialPressedBg,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _ServiceIconBox(
              icon: Icons.bluetooth_audio,
              color: AppColors.textTertiary,
              size: 48,
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ServiceTitle('蓝牙续费'),
                  SizedBox(height: 7),
                  Text(
                    '官方权益服务暂未开放',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionLabelStrong,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                '暂未开放',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargingStationServiceCard extends StatelessWidget {
  const _ChargingStationServiceCard();

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      enabled: false,
      onTap: () {},
      background: _phoneControlItemBg,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ServiceCardHeader(
              title: '台铃充电站',
              trailing: '暂未开放',
              showChevron: false,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _phoneControlItemBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const _ServiceIconBox(
                      icon: Icons.ev_station,
                      color: AppColors.textTertiary,
                      size: 58,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '最近充电站',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.itemTitle.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '官方站点与交易接口暂未接入',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.sectionLabelStrong,
                          ),
                        ],
                      ),
                    ),
                    const _UnavailableBadge(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCardHeader extends StatelessWidget {
  final String title;
  final String trailing;
  final bool showChevron;

  const _ServiceCardHeader({
    required this.title,
    required this.trailing,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ServiceTitle(title)),
        const SizedBox(width: 10),
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  trailing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _serviceMutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (showChevron)
                const Icon(
                  Icons.chevron_right,
                  size: AppIconSizes.md,
                  color: _serviceMutedText,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceTitle extends StatelessWidget {
  final String text;

  const _ServiceTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.cardTitle,
    );
  }
}

class _ServiceIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _ServiceIconBox({
    required this.icon,
    required this.color,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}

class _MiniHelpChip extends StatelessWidget {
  final String text;

  const _MiniHelpChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF1F1DF1),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OfficialPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final Color background;
  final Color pressedBackground;
  final double radius;
  final bool shadow;

  const _OfficialPressable({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.background = AppColors.surface,
    this.pressedBackground = _officialPressedBg,
    this.radius = AppRadii.card,
    this.shadow = true,
  });

  @override
  State<_OfficialPressable> createState() => _OfficialPressableState();
}

class _OfficialPressableState extends State<_OfficialPressable> {
  static const _motionDuration = Duration(milliseconds: 150);
  static const _motionCurve = Curves.easeOutCubic;

  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.enabled,
      enabled: widget.enabled,
      child: AnimatedScale(
        duration: _motionDuration,
        curve: _motionCurve,
        scale: widget.enabled && _pressed ? 0.98 : 1,
        child: AnimatedContainer(
          duration: _motionDuration,
          curve: _motionCurve,
          decoration: BoxDecoration(
            color: widget.enabled && _pressed
                ? widget.pressedBackground
                : widget.background,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: widget.shadow ? AppShadows.elevation1 : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(widget.radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              splashColor: AppColors.primary.withValues(alpha: 0.06),
              highlightColor: Colors.black.withValues(alpha: 0.025),
              onTap: widget.enabled
                  ? () {
                      _setPressed(false);
                      HapticFeedback.mediumImpact();
                      widget.onTap();
                    }
                  : null,
              onLongPress: widget.enabled && widget.onLongPress != null
                  ? () {
                      _setPressed(false);
                      HapticFeedback.mediumImpact();
                      widget.onLongPress!();
                    }
                  : null,
              onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
              onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
              onTapCancel: widget.enabled ? () => _setPressed(false) : null,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailableBadge extends StatelessWidget {
  const _UnavailableBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _serviceCardBorder,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '筹备中',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniMapPreview extends StatelessWidget {
  const _MiniMapPreview();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: _MiniMapPainter())),
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.location_on_outlined,
                  color: AppColors.brandRed,
                  size: AppIconSizes.lg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
