import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/battery_snapshot.dart';
import '../models/official_vehicle.dart';
import '../services/app_navigation.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/sensitive_value_masker.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/vehicle_switch_sheet.dart';
import 'app_preferences_pages.dart';
import 'diagnostic_page.dart';
import 'login_page.dart';
import 'official_cloud_page.dart';
import 'ride_stats_page.dart';
import 'settings_page.dart';
import 'vehicle_message_page.dart';

/// 我的 · Tailg Aurora (Open Design `profile-mine`)
///
/// 布局对齐 HTML / 设计稿：
/// - 扁平资料头（无卡片外壳）
/// - 默认车辆卡片 + 切换
/// - 「工具与服务」2×3 功能网格
/// - 账户行（手机号 / 退出登录）
/// - 版本脚注
///
/// 作为「我的」Tab 内容页使用时，底栏由 shell（`main.dart`）提供，
/// 本页不再自带 TabBar。也可在预览场景下设置 [showBottomNav] = true。
class ProfileMinePage extends StatefulWidget {
  const ProfileMinePage({super.key, this.showBottomNav = false});

  /// 预览 / 独立路由时显示临时底栏；嵌入 shell 时保持 false。
  final bool showBottomNav;

  @override
  State<ProfileMinePage> createState() => _ProfileMinePageState();
}

class _ProfileMinePageState extends State<ProfileMinePage>
    with AutomaticKeepAliveClientMixin {
  StreamSubscription<OfficialCloudState>? _cloudSub;
  int _previewNavIndex = 2;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cloudSub = officialCloudService.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_bootstrapMessageBadge());
    if (officialCloudService.state.signedIn) {
      unawaited(
        officialCloudService.refreshUserProfile(silent: true).catchError((
          Object e,
        ) {
          logService.operation(
            '我的页用户资料刷新失败',
            detail: OfficialCloudRedactor.errorMessage(e),
            level: LogLevel.warning,
          );
        }),
      );
    }
  }

  @override
  void dispose() {
    final sub = _cloudSub;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  Future<void> _bootstrapMessageBadge() async {
    await messageReadStore.ensureLoaded();
    final state = officialCloudService.state;
    if (!state.signedIn) {
      messageReadStore.setUnreadCount(0);
      return;
    }
    await messageReadStore.syncFromCloudMessages(
      vehicleMessages: state.vehicleMessages,
      systemMessages: state.systemMessages,
    );
  }

  // ── Data helpers ────────────────────────────────────────────────────────

  String get _nickname {
    final signedIn = officialCloudService.state.signedIn;
    if (!signedIn) return '立即登录';
    final fromProfile = officialCloudService.state.userProfile?.displayName
        .trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    // Fallback when getUserProfile not yet loaded / empty nickName.
    return '台铃用户';
  }

  String get _avatarGlyph {
    final name = _nickname;
    if (name.isEmpty || name == '立即登录') return '登';
    return String.fromCharCode(name.runes.first);
  }

  String? get _rawPhone {
    final phone = officialCloudService.state.phone.trim();
    if (phone.isEmpty) return null;
    return phone;
  }

  String get _maskedPhone {
    final phone = _rawPhone;
    if (phone == null) {
      return officialCloudService.state.signedIn ? '已登录' : '登录后同步车辆和消息';
    }
    return SensitiveValueMasker.phone(phone, minMaskLength: 11);
  }

  OfficialVehicle? get _vehicle => officialCloudService.state.signedIn
      ? officialCloudService.state.selectedVehicle
      : null;

  BatterySnapshot get _battery => BatterySnapshot.fromSources(
    officialVehicle: _vehicle,
    officialBatteryInfo: officialCloudService.state.batteryInfo,
  );

  String get _vehicleName {
    return _vehicle?.displayName ??
        vehicleStore.defaultVehicle?.displayName ??
        '暂无车辆';
  }

  String get _vehicleOnlineLabel {
    final v = _vehicle;
    if (v == null) {
      return officialCloudService.state.signedIn ? '未绑定' : '未登录';
    }
    return v.online ? '在线' : '离线';
  }

  bool get _vehicleOnline => _vehicle?.online ?? false;

  String get _batteryLabel {
    final p = _battery.percent ?? _vehicle?.electricQuantity;
    if (p == null) return '--';
    return '$p%';
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _openLogin() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage())),
    );
  }

  void _onAvatarOrEdit() {
    if (!officialCloudService.state.signedIn) {
      _openLogin();
      return;
    }
    AppSnack.featureUnavailable(context, '资料编辑');
  }

  void _onVehicleCard() {
    if (!officialCloudService.state.signedIn) {
      _openLogin();
      return;
    }
    final vehicles = officialCloudService.state.vehicles;
    if (vehicles.length > 1) {
      unawaited(showVehicleSwitchSheet(context));
      return;
    }
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const OfficialCloudPage()),
      ),
    );
  }

  void _openSettings() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
    );
  }

  void _openMessages() {
    if (!officialCloudService.state.signedIn) {
      _openLogin();
      return;
    }
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const VehicleMessagePage()),
      ),
    );
  }

  void _openRideStats() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const RideStatsPage())),
    );
  }

  void _openDiagnostic() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticPage())),
    );
  }

  void _openHelp() {
    // Official mine routes problem/feedback via customer-menu H5
    // (`problemService` dict). No native page yet.
    AppSnack.featureUnavailable(context, '帮助与反馈');
  }

  void _openAbout() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AboutAppPage())),
    );
  }

  void _onPhoneRow() {
    if (!officialCloudService.state.signedIn) {
      _openLogin();
      return;
    }
    // Official app has no in-place phone change on mine; phone is login identity.
    AppSnack.featureUnavailable(context, '更换手机号');
  }

  void _onPointsTap() {
    // Decompiled: myPointsCustomer is a menu flag/H5 URL, not a points balance.
    // Official mine shows static「我的积分 / 赚更多积分」entry — no numeric balance.
    AppSnack.featureUnavailable(context, '我的积分');
  }

  Future<void> _confirmLogout() async {
    unawaited(HapticFeedback.mediumImpact());
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _LogoutSheet(),
    );
    if (confirmed != true || !mounted) return;
    try {
      await officialCloudService.logout();
      if (!mounted) return;
      AppSnack.success(context, '已退出');
      AppNavigation.focusVehicleTabAfterSignOut();
    } catch (e) {
      logService.operation(
        '退出登录失败',
        detail: OfficialCloudRedactor.errorMessage(e),
        level: LogLevel.warning,
      );
      if (mounted) {
        AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final signedIn = officialCloudService.state.signedIn;
    final bottomPad =
        AppNav.contentBottomPadding + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _Aurora.pageBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            top: 6,
            bottom: widget.showBottomNav ? 24 : bottomPad,
          ),
          children: [
            // ── Profile header ──────────────────────────────────────────
            _ProfileHeader(
              avatarGlyph: _avatarGlyph,
              nickname: _nickname,
              phoneLine: _maskedPhone,
              // Decompiled UserInfoBean has no member level; show login state only.
              memberLabel: signedIn ? '已登录' : '游客',
              // No points balance in official API; hide fake numbers.
              showPointsEntry: signedIn,
              onAvatarTap: _onAvatarOrEdit,
              onEditTap: _onAvatarOrEdit,
              onPointsTap: _onPointsTap,
            ),

            // ── Default vehicle ─────────────────────────────────────────
            _VehicleCard(
              name: _vehicleName,
              online: _vehicleOnline,
              statusLabel: _vehicleOnlineLabel,
              batteryLabel: _batteryLabel,
              onTap: _onVehicleCard,
            ),

            // ── Tools grid ──────────────────────────────────────────────
            ValueListenableBuilder<int>(
              valueListenable: messageReadStore.unreadCount,
              builder: (context, unread, _) {
                return _ToolsCard(
                  messageBadge: signedIn && unread > 0 ? unread : null,
                  onSettings: _openSettings,
                  onMessages: _openMessages,
                  onStats: _openRideStats,
                  onDiag: _openDiagnostic,
                  onHelp: _openHelp,
                  onAbout: _openAbout,
                );
              },
            ),

            // ── Account ─────────────────────────────────────────────────
            _AccountCard(
              phoneValue: signedIn ? _maskedPhone : '未绑定',
              showLogout: signedIn,
              onPhoneTap: _onPhoneRow,
              onLogoutTap: _confirmLogout,
            ),

            // ── Version ─────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Tailg Cloud 1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFA0A6AD),
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? _PreviewBottomNav(
              currentIndex: _previewNavIndex,
              onTap: (i) {
                if (i == 2) return;
                setState(() => _previewNavIndex = i);
                AppSnack.info(context, i == 0 ? '控车' : '服务');
              },
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Design tokens mapped onto theme/
// ═══════════════════════════════════════════════════════════════════════════
abstract final class _Aurora {
  static const accent = AppColors.primary; // #00C896
  static const accentDeep = AppColors.primaryDark; // #00A57C
  static const accentSoft = AppColors.energySoft; // 12% green
  static const danger = AppColors.danger;
  static const pageBg = Color(0xFFF5F6F8); // HTML --bg-page
  static const surface = AppColors.surface;
  static const surfaceSoft = AppColors.surfaceContainerHigh; // #F0F0F4
  static const fg = AppColors.textPrimary;
  static const fgSecondary = AppColors.textSecondary;
  static const muted = AppColors.textTertiary;
  static const line = AppColors.hairline;

  static const cardMargin = EdgeInsets.fromLTRB(20, 12, 20, 0);
  static const cardRadius = AppRadii.lg; // 20 ≈ HTML 18
  static const cardShadow = AppShadows.elevation1;
  static const tabularNums = <FontFeature>[FontFeature.tabularFigures()];
}

// ═══════════════════════════════════════════════════════════════════════════
// Profile header (flat, no card chrome)
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.avatarGlyph,
    required this.nickname,
    required this.phoneLine,
    required this.memberLabel,
    required this.showPointsEntry,
    required this.onAvatarTap,
    required this.onEditTap,
    required this.onPointsTap,
  });

  final String avatarGlyph;
  final String nickname;
  final String phoneLine;
  final String memberLabel;
  final bool showPointsEntry;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditTap;
  final VoidCallback onPointsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          AppPressable(
            onTap: onAvatarTap,
            pressedScale: AppMotion.pressScale,
            semanticsLabel: '编辑资料',
            semanticsButton: true,
            child: CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFFE6F5EF),
              child: Text(
                avatarGlyph,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _Aurora.accentDeep,
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                    color: _Aurora.fg,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  phoneLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _Aurora.muted,
                    fontFeatures: _Aurora.tabularNums,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _Aurora.accentSoft,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        memberLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _Aurora.accentDeep,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (showPointsEntry) ...[
                      const SizedBox(width: 10),
                      AppPressable(
                        onTap: onPointsTap,
                        pressedScale: AppMotion.pressScale,
                        semanticsLabel: '我的积分',
                        semanticsButton: true,
                        child: const Text(
                          '我的积分',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _Aurora.fgSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Edit
          AppPressable(
            onTap: onEditTap,
            pressedScale: AppMotion.pressScale,
            semanticsLabel: '编辑',
            semanticsButton: true,
            child: const SizedBox(
              height: AppTouchTargets.min,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(
                    '编辑',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _Aurora.fgSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Vehicle card
// ═══════════════════════════════════════════════════════════════════════════
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.name,
    required this.online,
    required this.statusLabel,
    required this.batteryLabel,
    required this.onTap,
  });

  final String name;
  final bool online;
  final String statusLabel;
  final String batteryLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: AppPressable(
        onTap: onTap,
        pressedScale: AppMotion.pressScale,
        borderRadius: BorderRadius.circular(_Aurora.cardRadius),
        background: _Aurora.surface,
        pressedBackground: const Color(0xFFFBFBFC),
        boxShadow: _Aurora.cardShadow,
        semanticsLabel: '切换默认车辆 $name',
        semanticsButton: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _Aurora.surfaceSoft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: const Icon(
                        Icons.electric_moped_outlined,
                        size: 24,
                        color: _Aurora.fgSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              height: 1.2,
                              color: _Aurora.fg,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: online
                                      ? _Aurora.accent
                                      : const Color(0xFFC5CAD0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _Aurora.fgSecondary,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 10,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                color: const Color(0x1F111315),
                              ),
                              Text(
                                batteryLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _Aurora.fgSecondary,
                                  fontFeatures: _Aurora.tabularNums,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '切换',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _Aurora.fgSecondary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: _Aurora.fgSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tools & services (2 rows × 3 cols GridView)
// ═══════════════════════════════════════════════════════════════════════════
class _ToolsCard extends StatelessWidget {
  const _ToolsCard({
    required this.messageBadge,
    required this.onSettings,
    required this.onMessages,
    required this.onStats,
    required this.onDiag,
    required this.onHelp,
    required this.onAbout,
  });

  final int? messageBadge;
  final VoidCallback onSettings;
  final VoidCallback onMessages;
  final VoidCallback onStats;
  final VoidCallback onDiag;
  final VoidCallback onHelp;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final items = <_FuncItemData>[
      _FuncItemData(
        icon: Icons.settings_outlined,
        label: '设置',
        onTap: onSettings,
      ),
      _FuncItemData(
        icon: Icons.mail_outline,
        label: '消息中心',
        badge: messageBadge,
        onTap: onMessages,
      ),
      _FuncItemData(
        icon: Icons.bar_chart_rounded,
        label: '骑行统计',
        onTap: onStats,
      ),
      _FuncItemData(
        icon: Icons.task_alt_outlined,
        label: '诊断报告',
        onTap: onDiag,
      ),
      _FuncItemData(icon: Icons.help_outline, label: '帮助与反馈', onTap: onHelp),
      _FuncItemData(icon: Icons.info_outline, label: '关于我们', onTap: onAbout),
    ];

    return Container(
      margin: _Aurora.cardMargin,
      decoration: BoxDecoration(
        color: _Aurora.surface,
        borderRadius: BorderRadius.circular(_Aurora.cardRadius),
        boxShadow: _Aurora.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: Text(
              '工具与服务',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: _Aurora.fg,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 14),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 0,
                mainAxisExtent: 86,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return _FuncGridTile(data: item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FuncItemData {
  const _FuncItemData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;
}

class _FuncGridTile extends StatelessWidget {
  const _FuncGridTile({required this.data});

  final _FuncItemData data;

  @override
  Widget build(BuildContext context) {
    final badge = data.badge;
    return AppPressable(
      onTap: data.onTap,
      pressedScale: AppMotion.pressScale,
      borderRadius: BorderRadius.circular(AppRadii.md),
      pressedBackground: const Color(0x080F1620),
      semanticsLabel: data.label,
      semanticsButton: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _Aurora.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  data.icon,
                  size: AppIconSizes.md,
                  color: _Aurora.fgSecondary,
                ),
              ),
              if (badge != null && badge > 0)
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _Aurora.danger,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                        fontFeatures: _Aurora.tabularNums,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _Aurora.fg,
              letterSpacing: 0.1,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Account card (phone + logout)
// ═══════════════════════════════════════════════════════════════════════════
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.phoneValue,
    required this.showLogout,
    required this.onPhoneTap,
    required this.onLogoutTap,
  });

  final String phoneValue;
  final bool showLogout;
  final VoidCallback onPhoneTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: _Aurora.cardMargin,
      decoration: BoxDecoration(
        color: _Aurora.surface,
        borderRadius: BorderRadius.circular(_Aurora.cardRadius),
        boxShadow: _Aurora.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AppPressable(
            onTap: onPhoneTap,
            pressedBackground: const Color(0x080F1620),
            semanticsLabel: '手机号 $phoneValue',
            semanticsButton: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '手机号',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                          color: _Aurora.fg,
                        ),
                      ),
                    ),
                    Text(
                      phoneValue,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _Aurora.muted,
                        fontFeatures: _Aurora.tabularNums,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFFC4C8CD),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showLogout) ...[
            const Divider(height: 1, thickness: 1, color: _Aurora.line),
            AppPressable(
              onTap: onLogoutTap,
              pressedBackground: const Color(0x080F1620),
              semanticsLabel: '退出登录',
              semanticsButton: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: const Center(
                  child: Text(
                    '退出登录',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _Aurora.danger,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Logout confirmation sheet (matches HTML bottom sheet)
// ═══════════════════════════════════════════════════════════════════════════
class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _Aurora.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
        boxShadow: AppShadows.sheetShadow,
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFD8DCE1),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const Text(
            '退出登录？',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: _Aurora.fg,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '下次登录需验证手机号。本机车辆缓存会保留。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: _Aurora.fgSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppPressable(
            onTap: () => Navigator.of(context).pop(true),
            pressedScale: AppMotion.pressScale,
            borderRadius: BorderRadius.circular(AppRadii.md),
            background: _Aurora.danger,
            semanticsLabel: '确认退出',
            semanticsButton: true,
            child: const SizedBox(
              height: 48,
              width: double.infinity,
              child: Center(
                child: Text(
                  '退出',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppPressable(
            onTap: () => Navigator.of(context).pop(false),
            pressedScale: AppMotion.pressScale,
            borderRadius: BorderRadius.circular(AppRadii.md),
            background: _Aurora.surfaceSoft,
            semanticsLabel: '取消',
            semanticsButton: true,
            child: const SizedBox(
              height: 48,
              width: double.infinity,
              child: Center(
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _Aurora.fgSecondary,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Optional preview bottom nav (standalone / design review only)
// ═══════════════════════════════════════════════════════════════════════════
class _PreviewBottomNav extends StatelessWidget {
  const _PreviewBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.control_camera_outlined, '控车'),
      (Icons.work_outline, '服务'),
      (Icons.person_outline, '我的'),
    ];
    return Material(
      color: const Color(0xF5FFFFFF),
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 56,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _Aurora.line)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: AppPressable(
                    onTap: () => onTap(i),
                    pressedScale: AppMotion.pressScale,
                    semanticsLabel: items[i].$2,
                    semanticsButton: true,
                    semanticsSelected: currentIndex == i,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].$1,
                          size: 22,
                          color: currentIndex == i
                              ? _Aurora.accentDeep
                              : _Aurora.muted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$2,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: currentIndex == i
                                ? _Aurora.accentDeep
                                : _Aurora.muted,
                          ),
                        ),
                      ],
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
