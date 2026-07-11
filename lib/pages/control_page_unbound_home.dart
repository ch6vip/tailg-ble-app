part of 'control_page.dart';

/// Official UnControlFragment replica (cloud-only interactions).
///
/// Layout mirrors `fragment_uncontrol.xml`:
/// - top gradient bg `iv_bg_control`
/// - vehicle selector + detail/message icons
/// - center bike illustration `iv_control_evbike`
/// - bottom bind card `iv_uncontrol_bg` with hit target
///
/// Bind hotspot is honest: not signed in → LoginPage; signed in → AddVehiclePage.
class _UnboundVehicleHome extends StatelessWidget {
  const _UnboundVehicleHome({super.key, this.mode = ControlHomeMode.unbound});

  /// Optional mode so needLogin / unbound can share this shell.
  final ControlHomeMode mode;

  static const _vehicleTitle = '--';

  void _openAddVehicle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()),
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  void _openMessages(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const VehicleMessagePage()),
    );
  }

  void _openCloudOrLogin(BuildContext context) {
    if (officialCloudService.state.signedIn) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const OfficialCloudPage()),
      );
      return;
    }
    _openLogin(context);
  }

  void _onVehicleSelectTap(BuildContext context) {
    AppSnack.info(context, '暂无车辆！');
  }

  void _onDetailTap(BuildContext context) {
    // Official opens EVBikeInfoDetail; cloud-only falls back to vehicle list /
    // login since there is no bound car detail to show.
    _openCloudOrLogin(context);
  }

  void _onBindHotspot(BuildContext context) {
    HapticFeedback.mediumImpact();
    if (!officialCloudService.state.signedIn) {
      _openLogin(context);
      return;
    }
    _openAddVehicle(context);
  }

  @override
  Widget build(BuildContext context) {
    // mode is used for AnimatedSwitcher keys; keep field for future copy.
    assert(
      mode == ControlHomeMode.needLogin || mode == ControlHomeMode.unbound,
    );
    final topPadding = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;

    // Official dimen400 = 200dp bike height; keep a floor so narrow test
    // surfaces still look intentional.
    final bikeHeight = (width * 0.52).clamp(160.0, 220.0);
    // Bind card is a tall marketing image (1008×2577). Cap height so the page
    // stays scrollable without dominating small phones.
    final bindCardHeight = (width * 1.05).clamp(280.0, 420.0);
    // Official hit target sits around 34.8% from top of the bind image.
    final bindHitTop = bindCardHeight * 0.348 - 27.5;
    final bindHitHeight = 55.0;

    return Container(
      key: const ValueKey('unbound-home'),
      decoration: const BoxDecoration(
        color: AppColors.officialPageBg,
        image: DecorationImage(
          image: AssetImage('assets/official_tailg/iv_bg_control.png'),
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topPadding + 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _UnboundTopBar(
              title: _vehicleTitle,
              onVehicleTap: () => _onVehicleSelectTap(context),
              onDetail: () => _onDetailTap(context),
              onMessage: () => _openMessages(context),
            ),
          ),
          SizedBox(height: (bikeHeight * 0.18).clamp(24.0, 48.0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Semantics(
              label: '未绑定车辆',
              image: true,
              child: Image.asset(
                'assets/official_tailg/iv_control_evbike.png',
                height: bikeHeight,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => SizedBox(
                  height: bikeHeight,
                  child: const Center(
                    child: Icon(
                      Icons.electric_bike,
                      size: 96,
                      color: AppColors.officialTextMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: bindCardHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/official_tailg/iv_uncontrol_bg.png',
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.sheet),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '绑定智能中控',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.officialStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 15,
                    right: 15,
                    top: bindHitTop.clamp(0.0, bindCardHeight - bindHitHeight),
                    height: bindHitHeight,
                    child: AppPressable(
                      pressedScale: AppMotion.pressScale,
                      duration: AppMotion.micro,
                      curve: AppMotion.pressCurve,
                      background: Colors.transparent,
                      pressedBackground: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      haptic: false,
                      semanticsLabel: '绑定设备',
                      semanticsButton: true,
                      semanticsEnabled: true,
                      onTap: () => _onBindHotspot(context),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Cloud-only secondary path: keep an explicit login entry for users
          // who already own a bound vehicle on the official account.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: AppPressable(
              pressedScale: AppMotion.pressScale,
              duration: AppMotion.micro,
              curve: AppMotion.pressCurve,
              background: Colors.white,
              pressedBackground: AppColors.officialPressedBg,
              borderRadius: BorderRadius.circular(15),
              boxShadow: AppShadows.elevation1,
              haptic: false,
              semanticsLabel: '登录账号',
              semanticsButton: true,
              semanticsEnabled: true,
              onTap: () {
                HapticFeedback.mediumImpact();
                _openLogin(context);
              },
              builder: (context, pressed) {
                return SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      '登录账号同步车辆',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: pressed
                            ? AppColors.textSecondary
                            : AppColors.officialStrong,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _UnboundTopBar extends StatelessWidget {
  const _UnboundTopBar({
    required this.title,
    this.onVehicleTap,
    this.onDetail,
    this.onMessage,
  });

  final String title;
  final VoidCallback? onVehicleTap;
  final VoidCallback? onDetail;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final vehicleSwitch = GestureDetector(
      onTap: onVehicleTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouchTargets.min),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/official_tailg/ic_control_pup_select.png',
              width: 13,
              height: 13,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: '切换车辆',
            button: true,
            enabled: onVehicleTap != null,
            onTap: onVehicleTap,
            child: ExcludeSemantics(child: vehicleSwitch),
          ),
        ),
        const SizedBox(width: 8),
        _UnboundTopIconButton(
          asset: 'assets/official_tailg/ic_control_detail.png',
          fallback: Icons.more_horiz,
          label: '车辆详情',
          onTap: onDetail,
        ),
        const SizedBox(width: 14),
        _UnboundTopIconButton(
          asset: 'assets/official_tailg/ic_control_msg_change.png',
          fallback: Icons.notifications_none,
          label: '消息',
          onTap: onMessage,
        ),
      ],
    );
  }
}

class _UnboundTopIconButton extends StatelessWidget {
  const _UnboundTopIconButton({
    required this.asset,
    required this.fallback,
    required this.label,
    this.onTap,
  });

  final String asset;
  final IconData fallback;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsEnabled: onTap != null,
      child: SizedBox(
        width: AppTouchTargets.min,
        height: AppTouchTargets.min,
        child: Center(
          child: Image.asset(
            asset,
            width: 24,
            height: 24,
            errorBuilder: (_, __, ___) =>
                Icon(fallback, size: 24, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
