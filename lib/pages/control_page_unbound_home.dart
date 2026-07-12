part of 'control_page.dart';

/// Official UnControlFragment replica (cloud-only interactions).
///
/// Layout mirrors `fragment_uncontrol.xml`:
/// - top gradient bg `iv_bg_control`
/// - vehicle selector + detail/message icons
/// - center bike illustration `iv_control_evbike`
/// - bottom bind card `iv_uncontrol_bg` with hit target
///
/// Asset notes for `iv_uncontrol_bg.png` (1008×2577):
/// The full PNG is a tall marketing collage. Showing the entire natural height
/// (`width * 2577/1008 ≈ width * 2.556`) overflows phones badly. We crop to the
/// upper useful portion with `BoxFit.cover` + `Alignment.topCenter` so the blue
/// CTA remains visible without the huge empty bottom of the asset.
///
/// Bind hotspot opens AddVehiclePage (user is always signed in here).
class _UnboundVehicleHome extends StatelessWidget {
  const _UnboundVehicleHome({super.key});

  static const _vehicleTitle = '--';

  // Source asset is 1008×2577. We display an upper crop near 1008:1100 so the
  // CTA band stays in view without the tall empty marketing padding.
  static const _bindCardAspect = 1008 / 1100;

  // Official full-image hotspot was ~0.348 from the top. After top-aligned
  // cover crop of the upper portion, the blue CTA sits nearer mid-card.
  static const _bindHotspotTopFraction = 0.55;
  static const _bindHotspotHeight = 56.0;

  void _openAddVehicle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()),
    );
  }

  void _openMessages(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const VehicleMessagePage()),
    );
  }

  void _openCloud(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const OfficialCloudPage()),
    );
  }

  void _onVehicleSelectTap(BuildContext context) {
    AppSnack.info(context, '暂无车辆！');
  }

  void _onDetailTap(BuildContext context) {
    _openCloud(context);
  }

  void _onBindHotspot(BuildContext context) {
    HapticFeedback.mediumImpact();
    _openAddVehicle(context);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;

    // Official dimen400 = 200dp bike height; keep a floor so narrow test
    // surfaces still look intentional. Cap lower than before to leave room for
    // the bind card CTA without huge empty gaps.
    final bikeHeight = (width * 0.42).clamp(140.0, 200.0);

    // Prefer fitting the useful upper card crop. Clamp against remaining
    // viewport so small phones stay scrollable instead of clipping mid-CTA.
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxBindHeight = (viewportHeight * 0.48).clamp(260.0, 420.0);

    return Container(
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
          SizedBox(height: (bikeHeight * 0.12).clamp(16.0, 36.0)),
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth;
                final cardHeight = (cardWidth / _bindCardAspect).clamp(
                  240.0,
                  maxBindHeight,
                );
                // Hotspot over the blue CTA after top-aligned cover crop.
                final hitTop =
                    (cardHeight * _bindHotspotTopFraction) -
                    (_bindHotspotHeight / 2);
                return SizedBox(
                  height: cardHeight,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.sheet),
                          child: Image.asset(
                            'assets/official_tailg/iv_uncontrol_bg.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.sheet,
                                ),
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
                      ),
                      Positioned(
                        left: 15,
                        right: 15,
                        top: hitTop.clamp(0.0, cardHeight - _bindHotspotHeight),
                        height: _bindHotspotHeight,
                        child: AppPressable(
                          pressedScale: AppMotion.pressScale,
                          duration: AppMotion.micro,
                          curve: AppMotion.pressCurve,
                          background: Colors.transparent,
                          pressedBackground: Colors.black.withValues(
                            alpha: 0.04,
                          ),
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
                );
              },
            ),
          ),
          const SizedBox(height: 28),
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
