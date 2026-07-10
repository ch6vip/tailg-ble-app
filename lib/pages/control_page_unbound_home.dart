part of 'control_page.dart';

class _UnboundVehicleHome extends StatelessWidget {
  const _UnboundVehicleHome();

  void _showSnack(BuildContext context, String message) {
    AppSnack.info(context, message);
  }

  void _openAddVehicle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()),
    );
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
          '登录官方账号后可使用控车、定位、轨迹和电池服务',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                onTap: () => _openAddVehicle(context),
              ),
              const SizedBox(height: 12),
              _OfficialActionButton(
                label: '虚拟体验（演示）',
                foreground: AppColors.textSecondary,
                background: AppColors.surface,
                onTap: () => _showSnack(context, '虚拟体验暂未开放，可先登录账号'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const GaragePage()),
                ),
                child: const Text(
                  '绑定说明',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
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
            borderRadius: BorderRadius.circular(AppRadii.card),
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

class _UnboundBannerState extends State<_UnboundBanner>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _autoAdvanceInterval = Duration(seconds: 4);
  static const _pageTransitionDuration = Duration(milliseconds: 400);

  final _pageController = PageController();
  late final AnimationController _autoAdvanceController;
  int _currentPage = 0;

  static const _pages = [
    _BannerPage(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.pageBgBot, Color(0xFFEDF1F5), Color(0xFFE6F7F1)],
      ),
      chips: ['远程控车', '云端车辆'],
      caption: '登录官方账号后同步车辆状态',
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
    WidgetsBinding.instance.addObserver(this);
    _autoAdvanceController =
        AnimationController(vsync: this, duration: _autoAdvanceInterval)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _advancePage();
              _autoAdvanceController.reset();
              _autoAdvanceController.forward();
            }
          });
    _autoAdvanceController.forward();
  }

  void _advancePage() {
    if (!mounted || !_pageController.hasClients) return;
    final visiblePage = (_pageController.page ?? _currentPage).round().clamp(
      0,
      _pages.length - 1,
    );
    final next = (visiblePage + 1) % _pages.length;
    _pageController.animateToPage(
      next,
      duration: _pageTransitionDuration,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _autoAdvanceController.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (_autoAdvanceController.isCompleted) {
        _autoAdvanceController.forward(from: 0);
      } else {
        _autoAdvanceController.forward();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoAdvanceController.dispose();
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
                    borderRadius: BorderRadius.circular(AppRadii.sheet),
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
                            borderRadius: BorderRadius.circular(AppRadii.card),
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

class _OfficialActionButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AppPressable(
      pressedScale: AppMotion.pressScale,
      duration: AppMotion.micro,
      curve: AppMotion.pressCurve,
      background: background,
      pressedBackground: AppColors.officialPressedBg,
      borderRadius: BorderRadius.circular(15),
      boxShadow: AppShadows.elevation1,
      haptic: false,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsEnabled: true,
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      builder: (context, pressed) {
        return SizedBox(
          height: 54,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: pressed ? AppColors.textSecondary : foreground,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
