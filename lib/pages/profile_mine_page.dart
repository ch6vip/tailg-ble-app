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
import '../theme/app_void.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';
import '../widgets/vehicle_switch_sheet.dart';
import '../widgets/void_canvas.dart';
import '../widgets/void_glass.dart';
import '../widgets/void_typography.dart';
import 'app_preferences_pages.dart';
import 'garage_page.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'vehicle_message_page.dart';

/// 我的 · Tailg Aurora (Open Design `profile-mine`)
///
/// 布局：
/// - 扁平资料头（无卡片外壳）
/// - 默认车辆卡片 + 切换（页内主 elevation 卡）
/// - 「账户与支持」列表（设置 / 消息 / 帮助 / 关于），与手机号卡同行几何对齐
/// - 账户行（手机号 / 退出登录）
/// - 版本脚注
///
/// 车务能力（骑行统计、诊断等）主入口在服务中心，本页不再等权九宫格重复。
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

  String? get _avatarUrl {
    if (!officialCloudService.state.signedIn) return null;
    return officialCloudService.state.userProfile?.avatarUrl;
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
    unawaited(_editNickname());
  }

  Future<void> _editNickname() async {
    final current = officialCloudService.state.userProfile?.displayName ?? '';
    final controller = TextEditingController(text: current);
    try {
      final next = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('修改昵称'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 20,
              decoration: const InputDecoration(
                hintText: '输入昵称',
                counterText: '',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
      if (next == null || !mounted) return;
      if (next.isEmpty) {
        AppSnack.info(context, '昵称不能为空');
        return;
      }
      if (next == current) return;
      try {
        await officialCloudService.updateUserNickname(next);
        if (!mounted) return;
        AppSnack.success(context, '昵称已更新');
      } catch (e) {
        if (!mounted) return;
        AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
      }
    } finally {
      // Dispose after the dialog route is fully torn down.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
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
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const GaragePage())),
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
      backgroundColor: VoidColors.voidDeep,
      body: VoidCanvas(
        child: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: 6,
              bottom: widget.showBottomNav ? 24 : bottomPad,
            ),
            children: [
              // ── Profile header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: KineticType(
                  signedIn ? _nickname : '我的',
                  mode: KineticTypeMode.word,
                  staggerDelay: 30,
                  duration: const Duration(milliseconds: 400),
                  style: VoidType.hero.copyWith(fontSize: 28),
                ),
              ),
              _ProfileHeader(
                avatarGlyph: _avatarGlyph,
                avatarUrl: _avatarUrl,
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

              // ── Account & support (list, not equal-weight grid) ────────
              const VoidSectionLabel('账户与支持'),
              ValueListenableBuilder<int>(
                valueListenable: messageReadStore.unreadCount,
                builder: (context, unread, _) {
                  return _SupportCard(
                    messageBadge: signedIn && unread > 0 ? unread : null,
                    onSettings: _openSettings,
                    onMessages: _openMessages,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text(
                  'Tailg Cloud · VOID',
                  textAlign: TextAlign.center,
                  style: VoidType.micro.copyWith(letterSpacing: 2),
                ),
              ),
            ],
          ),
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
  static const cardMargin = EdgeInsets.fromLTRB(20, 12, 20, 0);
  static const cardRadius = AppRadii.lg; // 20 ≈ HTML 18
  static const tabularNums = <FontFeature>[FontFeature.tabularFigures()];
}

// ═══════════════════════════════════════════════════════════════════════════
// Profile header (flat, no card chrome)
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.avatarGlyph,
    required this.avatarUrl,
    required this.nickname,
    required this.phoneLine,
    required this.memberLabel,
    required this.showPointsEntry,
    required this.onAvatarTap,
    required this.onEditTap,
    required this.onPointsTap,
  });

  final String avatarGlyph;
  final String? avatarUrl;
  final String nickname;
  final String phoneLine;
  final String memberLabel;
  final bool showPointsEntry;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditTap;
  final VoidCallback onPointsTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final url = avatarUrl;
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
              backgroundColor: colors.primary.withValues(alpha: 0.12),
              backgroundImage: url == null || url.isEmpty
                  ? null
                  : NetworkImage(url),
              onBackgroundImageError: url == null || url.isEmpty
                  ? null
                  : (Object error, StackTrace? stackTrace) {},
              child: url == null || url.isEmpty
                  ? Text(
                      avatarGlyph,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                        letterSpacing: 0,
                        height: 1,
                      ),
                    )
                  : null,
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.15,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  phoneLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textTertiary,
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
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        memberLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                          letterSpacing: 0,
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
                        child: Text(
                          '我的积分',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
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
            child: SizedBox(
              height: AppTouchTargets.min,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(
                    '编辑',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                      letterSpacing: 0,
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
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: AppPressable(
        onTap: onTap,
        pressedScale: AppMotion.pressScale,
        borderRadius: BorderRadius.circular(_Aurora.cardRadius),
        semanticsLabel: '切换默认车辆 $name',
        semanticsButton: true,
        child: VoidGlassCard(
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
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: LucideIcon(
                        Lucide.vehicle,
                        size: 22,
                        color: VoidColors.energy,
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                              height: 1.2,
                              color: colors.textPrimary,
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
                                      ? colors.primary
                                      : colors.textTertiary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 10,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                color: colors.outlineVariant,
                              ),
                              Text(
                                batteryLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
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
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '切换',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                    LucideIcon(
                      Lucide.chevronRight,
                      size: 16,
                      color: VoidColors.inkMuted,
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
// Account & support — same row geometry as phone/logout card (no lead icons)
// so title / chevron columns align across both list cards.
// ═══════════════════════════════════════════════════════════════════════════
class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.messageBadge,
    required this.onSettings,
    required this.onMessages,
    required this.onHelp,
    required this.onAbout,
  });

  final int? messageBadge;
  final VoidCallback onSettings;
  final VoidCallback onMessages;
  final VoidCallback onHelp;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rows = <_SupportRowData>[
      _SupportRowData(title: '设置', onTap: onSettings),
      _SupportRowData(title: '消息中心', badge: messageBadge, onTap: onMessages),
      _SupportRowData(title: '帮助与反馈', onTap: onHelp),
      _SupportRowData(title: '关于我们', onTap: onAbout),
    ];

    return VoidGlassCard(
      margin: _Aurora.cardMargin,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: colors.outlineVariant),
            _SupportRow(data: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _SupportRowData {
  const _SupportRowData({required this.title, required this.onTap, this.badge});

  final String title;
  final VoidCallback onTap;
  final int? badge;
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({required this.data});

  final _SupportRowData data;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final badge = data.badge;
    return AppPressable(
      onTap: data.onTap,
      pressedScale: AppMotion.pressScale,
      pressedBackground: colors.surfaceContainerHigh,
      semanticsLabel: data.title,
      semanticsButton: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          // Match _AccountCard phone row: 16 / 15 so left titles & chevrons line up.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (badge != null && badge > 0) ...[
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: colors.danger,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
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
                const SizedBox(width: 4),
              ],
              const LucideIcon(
                Lucide.chevronRight,
                size: 16,
                color: VoidColors.inkFaint,
              ),
            ],
          ),
        ),
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
    final colors = AppColors.of(context);
    return VoidGlassCard(
      margin: _Aurora.cardMargin,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AppPressable(
            onTap: onPhoneTap,
            pressedBackground: colors.surfaceContainerHigh,
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
                    Expanded(
                      child: Text(
                        '手机号',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      phoneValue,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textTertiary,
                        fontFeatures: _Aurora.tabularNums,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const LucideIcon(
                      Lucide.chevronRight,
                      size: 16,
                      color: VoidColors.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showLogout) ...[
            Divider(height: 1, thickness: 1, color: colors.outlineVariant),
            AppPressable(
              onTap: onLogoutTap,
              pressedBackground: colors.surfaceContainerHigh,
              semanticsLabel: '退出登录',
              semanticsButton: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Center(
                  child: Text(
                    '退出登录',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.danger,
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
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
        boxShadow: dark ? const [] : AppShadows.sheetShadow,
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
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          Text(
            '退出登录？',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '下次登录需验证手机号。本机车辆缓存会保留。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppPressable(
            onTap: () => Navigator.of(context).pop(true),
            pressedScale: AppMotion.pressScale,
            borderRadius: BorderRadius.circular(AppRadii.md),
            background: colors.danger,
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
            background: colors.surfaceContainerHigh,
            semanticsLabel: '取消',
            semanticsButton: true,
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: Center(
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                    letterSpacing: 0,
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
    final colors = AppColors.of(context);
    final items = const [
      (Lucide.vehicle, '控车'),
      (Lucide.service, '服务'),
      (Lucide.mine, '我的'),
    ];
    return Material(
      color: colors.surface.withValues(alpha: 0.96),
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
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
                        LucideIcon(
                          items[i].$1,
                          size: 22,
                          color: currentIndex == i
                              ? VoidColors.energy
                              : VoidColors.inkFaint,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$2,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            color: currentIndex == i
                                ? VoidColors.energy
                                : VoidColors.inkFaint,
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
