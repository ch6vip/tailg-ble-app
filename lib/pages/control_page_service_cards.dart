part of 'control_page.dart';

class _HomeQuickSection extends StatelessWidget {
  const _HomeQuickSection();

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      // 第一屏 4 个快捷——匹配「方案C 极简高端」效果图
      _HomeQuickItem(
        icon: Icons.location_on,
        label: '位置',
        accent: AppColors.danger,
        onTap: () => _open(context, const LocationPage()),
      ),
      _HomeQuickItem(
        icon: Icons.settings,
        label: '设置',
        accent: AppColors.accentTeal,
        onTap: () => _open(context, const VehicleSettingsPage()),
      ),
      _HomeQuickItem(
        icon: Icons.fence,
        label: '围栏',
        accent: _serviceAccentViolet,
        onTap: () => _open(
          context,
          const LocationPage(initialTab: LocationInitialTab.fence),
        ),
      ),
      _HomeQuickItem(
        icon: Icons.music_note,
        label: '音效',
        accent: _serviceAccentAmber,
        onTap: () => _open(context, const QgjSoundEffectsPage()),
      ),
      // 第二屏
      _HomeQuickItem(
        icon: Icons.ios_share,
        label: '分享用车',
        accent: _serviceAccentViolet,
        onTap: () => _open(context, const ShareBikePage()),
      ),
      _HomeQuickItem(
        icon: Icons.nfc,
        label: 'NFC钥匙',
        accent: AppColors.accentTeal,
        onTap: () => _open(context, const NfcKeyPage()),
      ),
      _HomeQuickItem(
        icon: Icons.route,
        label: '骑行记录',
        accent: _serviceAccentAmber,
        onTap: () => _open(
          context,
          const LocationPage(initialTab: LocationInitialTab.travel),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _FunctionSettingsCard(items: items),
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
                        accent: ReplicaColors.blue,
                        onTap: () => _open(context, const OfficialCloudPage()),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          _OfficialSettingsServiceCard(
            onSettingsTap: () => _open(context, const VehicleSettingsPage()),
            onFenceTap: () => _open(
              context,
              const LocationPage(initialTab: LocationInitialTab.fence),
            ),
            onShareTap: () => _open(context, const ShareBikePage()),
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

  const _FunctionSettingsCard({required this.items});

  @override
  State<_FunctionSettingsCard> createState() => _FunctionSettingsCardState();
}

class _FunctionSettingsCardState extends State<_FunctionSettingsCard> {
  final _scrollController = ScrollController();
  // Whether the quick-function row actually overflows. When it fits (few items
  // / wide screen) the position indicator is meaningless, so hide it instead of
  // leaving a stationary dark pill on a grey track.
  final _scrollable = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollable.dispose();
    super.dispose();
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
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'SHORTCUTS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) {
                final canScroll = notification.metrics.maxScrollExtent > 0;
                if (_scrollable.value != canScroll) {
                  _scrollable.value = canScroll;
                }
                return false;
              },
              child: ListView.separated(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) => SizedBox(
                  width: 86,
                  child: _HomeQuickTile(item: widget.items[index]),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _scrollable,
            builder: (context, scrollable, _) {
              if (!scrollable) return const SizedBox(height: 10);
              return Padding(
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
              );
            },
          ),
        ],
      ),
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

  const _HomeQuickTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: item.onTap,
      radius: ReplicaRadii.card,
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
              child: Icon(item.icon, size: 23, color: item.accent),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: ReplicaColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: ReplicaColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: ReplicaColors.muted,
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

class _OfficialSettingsServiceCard extends StatelessWidget {
  final VoidCallback onSettingsTap;
  final VoidCallback onFenceTap;
  final VoidCallback onShareTap;

  const _OfficialSettingsServiceCard({
    required this.onSettingsTap,
    required this.onFenceTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 158,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ServiceTitle('常用服务'),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _ServiceSettingButton(
                    icon: Icons.tune,
                    label: '车辆设置',
                    color: ReplicaColors.blue,
                    onTap: onSettingsTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ServiceSettingButton(
                    icon: Icons.location_searching,
                    label: '电子围栏',
                    color: AppColors.success,
                    onTap: onFenceTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ServiceSettingButton(
                    icon: Icons.ios_share,
                    label: '分享用车',
                    color: _serviceAccentViolet,
                    onTap: onShareTap,
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

class _ServiceSettingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ServiceSettingButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      radius: 10,
      background: Colors.white,
      pressedBackground: _officialPressedBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ServiceIconBox(icon: icon, color: color, size: 42),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: ReplicaColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      background: const Color(0xFF20242B),
      pressedBackground: const Color(0xFF343943),
      child: SizedBox(
        height: 96,
        child: Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SoundWavePainter(color: AppColors.primary),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  _ServiceIconBox(
                    icon: Icons.graphic_eq,
                    color: AppColors.primary,
                    dark: true,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '音效设置',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'QGJ 个性化提示音',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB8C0CC),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 22, color: Colors.white70),
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
                    style: TextStyle(
                      fontSize: 13,
                      color: ReplicaColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
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
            const Icon(Icons.chevron_right, color: ReplicaColors.muted),
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
      background: const Color(0xFFF4F5F7),
      pressedBackground: _officialPressedBg,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _ServiceIconBox(
              icon: Icons.bluetooth_audio,
              color: ReplicaColors.muted,
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
                    style: TextStyle(
                      fontSize: 13,
                      color: ReplicaColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _serviceCardBorder,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                '暂未开放',
                style: TextStyle(
                  fontSize: 12,
                  color: ReplicaColors.muted,
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
                      color: ReplicaColors.muted,
                      size: 58,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '最近充电站',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: ReplicaColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '官方站点与交易接口暂未接入',
                            style: TextStyle(
                              fontSize: 13,
                              color: ReplicaColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
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
                  size: 18,
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
      style: const TextStyle(
        fontSize: 17,
        color: ReplicaColors.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ServiceIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool dark;

  const _ServiceIconBox({
    required this.icon,
    required this.color,
    this.size = 50,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.12),
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
  final bool enabled;
  final Color background;
  final Color pressedBackground;
  final double radius;
  final bool shadow;

  const _OfficialPressable({
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.background = Colors.white,
    this.pressedBackground = _officialPressedBg,
    this.radius = ReplicaRadii.card,
    this.shadow = true,
  });

  @override
  State<_OfficialPressable> createState() => _OfficialPressableState();
}

class _OfficialPressableState extends State<_OfficialPressable> {
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
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: widget.enabled && _pressed ? 0.98 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.enabled && _pressed
                ? widget.pressedBackground
                : widget.background,
            borderRadius: BorderRadius.circular(widget.radius),
            border: widget.shadow
                ? Border.all(color: AppColors.border, width: 1)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.enabled
                    ? () {
                        _setPressed(false);
                        HapticFeedback.mediumImpact();
                        widget.onTap();
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
          color: ReplicaColors.muted,
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
                  Icons.location_on,
                  color: AppColors.brandRed,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
