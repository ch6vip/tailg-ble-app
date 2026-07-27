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
import '../widgets/lucide_icon.dart';
import '../widgets/vehicle_switch_sheet.dart';
import 'app_preferences_pages.dart';
import 'garage_page.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'vehicle_message_page.dart';

/// 我的 · Cyber home light cockpit.
///
/// 布局：
/// - 扁平资料头（无卡片外壳）
/// - 默认车辆卡片 + 切换（页内主 elevation 卡）
/// - 「账户与支持」列表（设置 / 消息 / 关于），与手机号卡同行几何对齐
/// - 账户行（手机号 / 退出登录）
/// - 版本脚注
///
/// 车务能力（骑行统计、诊断等）主入口在服务中心，本页不再等权九宫格重复。
///
/// 作为「我的」Tab 内容页使用，底栏由 shell（`main.dart`）提供。
class ProfileMinePage extends StatefulWidget {
  const ProfileMinePage({super.key});

  @override
  State<ProfileMinePage> createState() => _ProfileMinePageState();
}

class _ProfileMinePageState extends State<ProfileMinePage>
    with AutomaticKeepAliveClientMixin {
  StreamSubscription<OfficialCloudState>? _cloudSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cloudSub = officialCloudService.stateStream.listen((state) {
      if (mounted) setState(() {});
      _syncMessageBadge(state);
    });
    _syncMessageBadge(officialCloudService.state);
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

  void _syncMessageBadge(OfficialCloudState state) {
    if (!state.signedIn) {
      messageReadStore.setUnreadCount(0);
      return;
    }
    unawaited(
      messageReadStore
          .syncFromCloudMessages(
            vehicleMessages: state.vehicleMessages,
            systemMessages: state.systemMessages,
          )
          .catchError((Object error) {
            logService.operation(
              '我的页消息角标同步失败',
              detail: OfficialCloudRedactor.errorMessage(error),
              level: LogLevel.warning,
            );
          }),
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
            backgroundColor: CyberHomeColors.card,
            surfaceTintColor: CyberHomeColors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            title: const Text(
              '修改昵称',
              style: TextStyle(
                color: CyberHomeColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 20,
              style: const TextStyle(color: CyberHomeColors.ink),
              decoration: InputDecoration(
                hintText: '输入昵称',
                counterText: '',
                hintStyle: const TextStyle(color: CyberHomeColors.inkFaint),
                filled: true,
                fillColor: CyberHomeColors.cardMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  borderSide: const BorderSide(
                    color: CyberHomeColors.lineStrong,
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: CyberHomeColors.inkMuted,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CyberHomeColors.primary,
                  foregroundColor: CyberHomeColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                ),
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

  void _openAbout() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AboutAppPage())),
    );
  }

  Future<void> _confirmLogout() async {
    unawaited(HapticFeedback.mediumImpact());
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: CyberHomeColors.transparent,
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
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(top: 6, bottom: bottomPad),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                '我的',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: CyberHomeColors.ink,
                ),
              ),
            ),
            _ProfileHeader(
              avatarGlyph: _avatarGlyph,
              avatarUrl: _avatarUrl,
              nickname: _nickname,
              phoneLine: _maskedPhone,
              memberLabel: signedIn ? '已登录' : '游客',
              onAvatarTap: _onAvatarOrEdit,
              onEditTap: _onAvatarOrEdit,
            ),
            _VehicleCard(
              name: _vehicleName,
              online: _vehicleOnline,
              statusLabel: _vehicleOnlineLabel,
              batteryLabel: _batteryLabel,
              onTap: _onVehicleCard,
            ),
            const _MineSectionLabel('账户与支持'),
            ValueListenableBuilder<int>(
              valueListenable: messageReadStore.unreadCount,
              builder: (context, unread, _) {
                return _SupportCard(
                  messageBadge: signedIn && unread > 0 ? unread : null,
                  onSettings: _openSettings,
                  onMessages: _openMessages,
                  onAbout: _openAbout,
                );
              },
            ),
            _AccountCard(
              phoneValue: signedIn ? _maskedPhone : '未绑定',
              showLogout: signedIn,
              onLogoutTap: _confirmLogout,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Tailg Cloud · VOID',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: CyberHomeColors.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Design tokens mapped onto theme/
// ═══════════════════════════════════════════════════════════════════════════
abstract final class _Mine {
  static const cardMargin = EdgeInsets.fromLTRB(20, 12, 20, 0);
  static const cardRadius = AppRadii.tile;
  static const tabularNums = <FontFeature>[FontFeature.tabularFigures()];
  static const cardDecoration = BoxDecoration(
    color: CyberHomeColors.card,
    borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
    border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
  );
}

class _MineSectionLabel extends StatelessWidget {
  const _MineSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: CyberHomeColors.inkMuted,
        ),
      ),
    );
  }
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
    required this.onAvatarTap,
    required this.onEditTap,
  });

  final String avatarGlyph;
  final String? avatarUrl;
  final String nickname;
  final String phoneLine;
  final String memberLabel;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
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
              backgroundColor: CyberHomeColors.primarySoft,
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
                        color: CyberHomeColors.primary,
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
                    color: CyberHomeColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  phoneLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: CyberHomeColors.inkMuted,
                    fontFeatures: _Mine.tabularNums,
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
                        color: CyberHomeColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        memberLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: CyberHomeColors.primary,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
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
                      color: CyberHomeColors.inkSecondary,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: AppPressable(
        onTap: onTap,
        pressedScale: AppMotion.pressScale,
        borderRadius: BorderRadius.circular(_Mine.cardRadius),
        semanticsLabel: '切换默认车辆 $name',
        semanticsButton: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _Mine.cardDecoration,
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
                        color: CyberHomeColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                      child: LucideIcon(
                        Lucide.vehicle,
                        size: 22,
                        color: CyberHomeColors.primary,
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
                              color: CyberHomeColors.ink,
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
                                      ? CyberHomeColors.success
                                      : CyberHomeColors.inkFaint,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CyberHomeColors.inkMuted,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 10,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                color: CyberHomeColors.line,
                              ),
                              Text(
                                batteryLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CyberHomeColors.inkMuted,
                                  fontFeatures: _Mine.tabularNums,
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
                        color: CyberHomeColors.inkSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                    LucideIcon(
                      Lucide.chevronRight,
                      size: 16,
                      color: CyberHomeColors.inkFaint,
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
    required this.onAbout,
  });

  final int? messageBadge;
  final VoidCallback onSettings;
  final VoidCallback onMessages;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final rows = <_SupportRowData>[
      _SupportRowData(icon: Lucide.tune, title: '设置', onTap: onSettings),
      _SupportRowData(
        icon: Lucide.message,
        title: '消息中心',
        badge: messageBadge,
        onTap: onMessages,
      ),
      _SupportRowData(icon: Lucide.info, title: '关于我们', onTap: onAbout),
    ];

    return Container(
      margin: _Mine.cardMargin,
      padding: EdgeInsets.zero,
      decoration: _Mine.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: CyberHomeColors.line,
              ),
            _SupportRow(data: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _SupportRowData {
  const _SupportRowData({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? badge;
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({required this.data});

  final _SupportRowData data;

  @override
  Widget build(BuildContext context) {
    final badge = data.badge;
    return AppPressable(
      onTap: data.onTap,
      pressedScale: AppMotion.pressScale,
      pressedBackground: CyberHomeColors.cardMuted,
      semanticsLabel: data.title,
      semanticsButton: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          // Match _AccountCard phone row: 16 / 15 so left titles & chevrons line up.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: CyberHomeColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: LucideIcon(
                  data.icon,
                  size: 18,
                  color: CyberHomeColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    color: CyberHomeColors.ink,
                  ),
                ),
              ),
              if (badge != null && badge > 0) ...[
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: CyberHomeColors.danger,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: CyberHomeColors.white,
                      height: 1,
                      fontFeatures: _Mine.tabularNums,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const LucideIcon(
                Lucide.chevronRight,
                size: 16,
                color: CyberHomeColors.inkFaint,
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
    required this.onLogoutTap,
  });

  final String phoneValue;
  final bool showLogout;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: _Mine.cardMargin,
      padding: EdgeInsets.zero,
      decoration: _Mine.cardDecoration,
      child: Column(
        children: [
          Semantics(
            key: const ValueKey('mine-phone-identity'),
            container: true,
            label: '手机号 $phoneValue',
            child: ExcludeSemantics(
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
                            color: CyberHomeColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        phoneValue,
                        style: TextStyle(
                          fontSize: 14,
                          color: CyberHomeColors.inkMuted,
                          fontFeatures: _Mine.tabularNums,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showLogout) ...[
            const Divider(height: 1, thickness: 1, color: CyberHomeColors.line),
            AppPressable(
              onTap: onLogoutTap,
              pressedBackground: CyberHomeColors.cardMuted,
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
                      color: CyberHomeColors.danger,
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
        color: CyberHomeColors.card,
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
              color: CyberHomeColors.lineStrong,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          Text(
            '退出登录？',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: CyberHomeColors.ink,
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
                color: CyberHomeColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppPressable(
            onTap: () => Navigator.of(context).pop(true),
            pressedScale: AppMotion.pressScale,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            background: CyberHomeColors.danger,
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
                    color: CyberHomeColors.white,
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
            borderRadius: BorderRadius.circular(AppRadii.tile),
            background: CyberHomeColors.cardMuted,
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
                    color: CyberHomeColors.inkSecondary,
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
