part of 'control_page.dart';

class _UnboundVehicleHome extends StatelessWidget {
  const _UnboundVehicleHome({this.connectionLost = false});

  /// When true, the user previously had a BLE connection but vehicles are
  /// currently unavailable — likely a connectivity glitch rather than a
  /// first-launch empty state.
  final bool connectionLost;

  void _showSnack(BuildContext context, String message) {
    AppSnack.info(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('unbound-home'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: _UnboundLogoMark(),
        ),
        const SizedBox(height: 54),
        if (connectionLost) ...[
          // Connection-lost variant: show retry CTA instead of full intro
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceBrandAmberTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bluetooth_disabled,
              size: 40,
              color: AppColors.energyAmber,
            ),
          ),
          const Text(
            '连接已中断',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '之前连接的设备暂时不可用\n请靠近车辆后重试',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: _OfficialActionButton(
              label: '重新连接',
              foreground: Colors.white,
              background: AppColors.primary,
              onTap: () => openScanTab(context),
            ),
          ),
        ] else ...[
          // Normal first-launch empty state
          const Text(
            '未绑定车辆',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '绑定车辆后可使用蓝牙控车、定位、轨迹和电池服务',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (!connectionLost) ...[
          const SizedBox(height: 22),
          const _UnboundBanner(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                _OfficialActionButton(
                  label: '绑定设备',
                  foreground: Colors.white,
                  background: AppColors.primary,
                  onTap: () => openScanTab(context),
                ),
                const SizedBox(height: 12),
                _OfficialActionButton(
                  label: '虚拟体验（演示）',
                  foreground: AppColors.textSecondary,
                  background: AppColors.surface,
                  onTap: () =>
                      _showSnack(context, '虚拟体验功能开发中，可先「绑定设备」或登录官方账号查看车辆'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GaragePage()),
                  ),
                  child: const Text(
                    '绑定说明',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _OfficialTextLinkRow(
                  icon: Icons.cloud_done_outlined,
                  label: '已绑定官方账号？登录后自动显示车辆',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OfficialCloudPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _UnboundLogoMark extends StatelessWidget {
  const _UnboundLogoMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppShadows.cardShadow,
          ),
          child: const Icon(
            Icons.electric_bike,
            size: 25,
            color: AppColors.brandRed,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'TAILG',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _UnboundBanner extends StatefulWidget {
  const _UnboundBanner();

  @override
  State<_UnboundBanner> createState() => _UnboundBannerState();
}

class _UnboundBannerState extends State<_UnboundBanner> {
  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  static const _pages = [
    _BannerPage(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF6F8FB), Color(0xFFEDF1F5), Color(0xFFE6F7F1)],
      ),
      chips: ['蓝牙控车', '云端车辆'],
      caption: '绑定设备后同步车辆状态',
    ),
    _BannerPage(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF8F4FF), Color(0xFFF0EBFF), Color(0xFFE8E0FF)],
      ),
      chips: ['一键寻车', '远程设防'],
      caption: '手机就是你的车钥匙',
    ),
    _BannerPage(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF8F0), Color(0xFFFFF0E0), Color(0xFFFFE8D0)],
      ),
      chips: ['骑行记录', '电池管理'],
      caption: '全面掌控车辆数据',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _pages.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            height: 230,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _pages.length,
              itemBuilder: (context, i) {
                final page = _pages[i];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: page.gradient,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        top: 18,
                        child: _UnboundBannerChip(text: page.chips[0]),
                      ),
                      Positioned(
                        right: 18,
                        top: 18,
                        child: _UnboundBannerChip(text: page.chips[1]),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: Text(
                          page.caption,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _BannerDot(active: i == _currentPage),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BannerPage {
  final LinearGradient gradient;
  final List<String> chips;
  final String caption;
  const _BannerPage({
    required this.gradient,
    required this.chips,
    required this.caption,
  });
}

class _UnboundBannerChip extends StatelessWidget {
  final String text;

  const _UnboundBannerChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BannerDot extends StatelessWidget {
  final bool active;

  const _BannerDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 28 : 8,
      height: 6,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.outlineVariant,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _OfficialActionButton extends StatefulWidget {
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  const _OfficialActionButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  @override
  State<_OfficialActionButton> createState() => _OfficialActionButtonState();
}

class _OfficialActionButtonState extends State<_OfficialActionButton> {
  static const _motionDuration = Duration(milliseconds: 150);
  static const _motionCurve = Curves.easeOutCubic;

  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: _motionDuration,
      curve: _motionCurve,
      scale: _pressed ? 0.97 : 1,
      child: AnimatedContainer(
        duration: _motionDuration,
        curve: _motionCurve,
        height: 54,
        decoration: BoxDecoration(
          color: _pressed ? _officialPressedBg : widget.background,
          borderRadius: BorderRadius.circular(15),
          boxShadow: _pressed ? null : AppShadows.elevation1,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            splashColor: widget.foreground.withValues(alpha: 0.08),
            highlightColor: widget.foreground.withValues(alpha: 0.05),
            onTap: () {
              _setPressed(false);
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            borderRadius: BorderRadius.circular(15),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _pressed
                        ? AppColors.textSecondary
                        : widget.foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfficialTextLinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OfficialTextLinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppIconSizes.sm, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
