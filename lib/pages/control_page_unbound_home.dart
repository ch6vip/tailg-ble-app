part of 'control_page.dart';

class _UnboundVehicleHome extends StatelessWidget {
  const _UnboundVehicleHome();

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
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
            color: ReplicaColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '绑定车辆后可使用蓝牙控车、定位、轨迹和电池服务',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: ReplicaColors.secondary,
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
                borderColor: AppColors.primary,
                onTap: () => openScanTab(context),
              ),
              const SizedBox(height: 12),
              _OfficialActionButton(
                label: '虚拟体验（演示）',
                foreground: ReplicaColors.secondary,
                background: Colors.white,
                borderColor: AppColors.border,
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
                    color: ReplicaColors.muted,
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
                  MaterialPageRoute(builder: (_) => const OfficialCloudPage()),
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
            color: Colors.white,
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
            color: ReplicaColors.ink,
          ),
        ),
      ],
    );
  }
}

class _UnboundBanner extends StatelessWidget {
  const _UnboundBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            height: 230,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
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
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF8FAFF),
                          Color(0xFFE9F0FF),
                          Color(0xFFFFF4F4),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 40,
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _UnboundBannerPainter()),
                  ),
                ),
                const Positioned(
                  left: 18,
                  top: 18,
                  child: _UnboundBannerChip(text: '蓝牙控车'),
                ),
                const Positioned(
                  right: 18,
                  top: 18,
                  child: _UnboundBannerChip(text: '云端车辆'),
                ),
                const Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Text(
                    '绑定设备后同步车辆状态',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: ReplicaColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BannerDot(active: true),
              SizedBox(width: 6),
              _BannerDot(active: false),
              SizedBox(width: 6),
              _BannerDot(active: false),
            ],
          ),
        ],
      ),
    );
  }
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
          color: ReplicaColors.muted,
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
        color: active ? AppColors.primary : const Color(0xFFD8DAE2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _OfficialActionButton extends StatefulWidget {
  final String label;
  final Color foreground;
  final Color background;
  final Color borderColor;
  final VoidCallback onTap;

  const _OfficialActionButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.borderColor,
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
          border: Border.all(
            color: _pressed ? _officialPressedBg : widget.borderColor,
          ),
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
                        ? ReplicaColors.secondary
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
        splashColor: ReplicaColors.blue.withValues(alpha: 0.08),
        highlightColor: ReplicaColors.blue.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: ReplicaColors.blue),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ReplicaColors.secondary,
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
