import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

const _pageBg = Color(0xFFF5F6FA);

class OfficialCloudPage extends StatefulWidget {
  const OfficialCloudPage({super.key});

  @override
  State<OfficialCloudPage> createState() => _OfficialCloudPageState();
}

class _OfficialCloudPageState extends State<OfficialCloudPage> {
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final phone = officialCloudService.state.phone;
    if (phone.isNotEmpty) _phoneController.text = phone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    try {
      await officialCloudService.requestSmsCode(_phoneController.text);
      if (!mounted) return;
      _showSnack('验证码已发送');
    } catch (e) {
      if (!mounted) return;
      _showSnack(_errorMessage(e), error: true);
    }
  }

  Future<void> _login() async {
    try {
      await officialCloudService.login(
        _phoneController.text,
        _smsController.text,
      );
      if (!mounted) return;
      _showSnack('官方账号登录成功');
    } catch (e) {
      if (!mounted) return;
      _showSnack(_errorMessage(e), error: true);
    }
  }

  Future<void> _refresh() async {
    try {
      await officialCloudService.refreshVehicles();
      if (!mounted) return;
      _showSnack('官方车辆已刷新');
    } catch (e) {
      if (!mounted) return;
      _showSnack(_errorMessage(e), error: true);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  String _errorMessage(Object e) {
    if (e is OfficialCloudApiException) return e.message;
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: StreamBuilder<OfficialCloudState>(
          stream: officialCloudService.stateStream,
          initialData: officialCloudService.state,
          builder: (context, snapshot) {
            final state = snapshot.data ?? officialCloudService.state;
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                bottom: AppNav.contentBottomPadding,
              ),
              children: [
                AppPageHeader(
                  title: '官方账号',
                  actions: [
                    if (state.signedIn)
                      AppHeaderAction(
                        icon: Icons.refresh,
                        tooltip: '刷新车辆',
                        onTap: state.loading ? null : _refresh,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!state.signedIn)
                  _LoginCard(
                    phoneController: _phoneController,
                    smsController: _smsController,
                    loading: state.loading,
                    onRequestCode: _requestCode,
                    onLogin: _login,
                  )
                else ...[
                  _SessionCard(state: state),
                  const SizedBox(height: 14),
                  _ChannelCard(state: state),
                  const SizedBox(height: 14),
                  _VehicleListCard(state: state),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    child: Text(
                      state.error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const AppCard(
                  child: Text(
                    '官方账号模式只使用你自己的验证码登录和已绑定车辆，不绕过官方登录、token 或车辆绑定关系。普通日志不会输出 token、手机号和 IMEI 明文。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController smsController;
  final bool loading;
  final VoidCallback onRequestCode;
  final VoidCallback onLogin;

  const _LoginCard({
    required this.phoneController,
    required this.smsController,
    required this.loading,
    required this.onRequestCode,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '登录官方账号',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: _inputDecoration('手机号'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: smsController,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: _inputDecoration('短信验证码'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: loading ? null : onRequestCode,
                  child: const Text('获取'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: loading ? null : onLogin,
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('登录'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F6FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final OfficialCloudState state;

  const _SessionCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '官方账号已登录',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.phone.isEmpty ? '手机号已脱敏保存' : _maskPhone(state.phone),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => officialCloudService.logout(),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 7) return '已登录';
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }
}

class _ChannelCard extends StatelessWidget {
  final OfficialCloudState state;

  const _ChannelCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '控车通道',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...OfficialControlChannel.values.map((channel) {
            final selected = channel == state.controlChannel;
            return RadioListTile<OfficialControlChannel>(
              value: channel,
              groupValue: state.controlChannel,
              onChanged: (value) {
                if (value != null) {
                  officialCloudService.setControlChannel(value);
                }
              },
              contentPadding: EdgeInsets.zero,
              title: Text(channel.label),
              subtitle: Text(channel.description),
              activeColor: AppColors.primary,
              selected: selected,
            );
          }),
        ],
      ),
    );
  }
}

class _VehicleListCard extends StatelessWidget {
  final OfficialCloudState state;

  const _VehicleListCard({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.vehicles.isEmpty) {
      return const AppCard(child: Center(child: CircularProgressIndicator()));
    }
    if (state.vehicles.isEmpty) {
      return const AppCard(
        child: Text(
          '当前官方账号未返回车辆，请确认手机号已绑定台铃车辆。',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }
    return Column(
      children: state.vehicles.map((vehicle) {
        final selected = state.selectedVehicle?.key == vehicle.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _OfficialVehicleCard(vehicle: vehicle, selected: selected),
        );
      }).toList(),
    );
  }
}

class _OfficialVehicleCard extends StatelessWidget {
  final OfficialVehicle vehicle;
  final bool selected;

  const _OfficialVehicleCard({required this.vehicle, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.white,
      child: InkWell(
        onTap: () async {
          HapticFeedback.selectionClick();
          await officialCloudService.selectVehicle(vehicle);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _StatusChip(
                  label: vehicle.onlineLabel,
                  color: vehicle.online
                      ? AppColors.success
                      : AppColors.textTertiary,
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: vehicle.defenceLabel,
                  color: AppColors.primary,
                ),
                _StatusChip(
                  label: vehicle.powerLabel,
                  color: AppColors.warning,
                ),
                _StatusChip(
                  label: vehicle.electricQuantity == null
                      ? '电量 --'
                      : '电量 ${vehicle.electricQuantity}%',
                  color: AppColors.success,
                ),
                _StatusChip(
                  label: vehicle.voltage == null
                      ? '电压 --'
                      : '${vehicle.voltage}V',
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailLine('蓝牙名', vehicle.btname.isEmpty ? '未返回' : vehicle.btname),
            _DetailLine(
              '蓝牙 MAC',
              vehicle.btmac.isEmpty ? '未返回' : vehicle.btmac,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OfficialVehicleDetailPage(vehicle: vehicle),
                      ),
                    ),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('详情'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OfficialVehicleLinkPage(vehicle: vehicle),
                      ),
                    ),
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('关联'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OfficialVehicleDetailPage extends StatelessWidget {
  final OfficialVehicle vehicle;

  const OfficialVehicleDetailPage({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
          children: [
            AppPageHeader(title: vehicle.displayName),
            const SizedBox(height: 12),
            if (vehicle.carPhoto.isNotEmpty)
              AppCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: Image.network(
                    vehicle.carPhoto,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 120,
                      child: Center(child: Icon(Icons.electric_bike, size: 56)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  _DetailLine('车辆昵称', vehicle.carNickName),
                  _DetailLine('车辆名称', vehicle.carName),
                  _DetailLine('车架号', vehicle.frame),
                  _DetailLine('官方 IMEI', _maskId(vehicle.imei)),
                  _DetailLine('GPS IMEI', _maskId(vehicle.imeiGps)),
                  _DetailLine('命令 IMEI', _maskId(vehicle.commandImei)),
                  _DetailLine(
                    '车型 modelType',
                    vehicle.modelType?.toString() ?? '未返回',
                  ),
                  _DetailLine('在线状态', vehicle.onlineLabel),
                  _DetailLine('设防状态', vehicle.defenceLabel),
                  _DetailLine('ACC 状态', vehicle.powerLabel),
                  _DetailLine(
                    '电量',
                    vehicle.electricQuantity == null
                        ? '未返回'
                        : '${vehicle.electricQuantity}%',
                  ),
                  _DetailLine(
                    '电压',
                    vehicle.voltage == null ? '未返回' : '${vehicle.voltage}V',
                  ),
                  _DetailLine(
                    '里程',
                    vehicle.mileage == null ? '未返回' : '${vehicle.mileage} km',
                  ),
                  _DetailLine('蓝牙名', vehicle.btname),
                  _DetailLine('蓝牙 MAC', _maskId(vehicle.btmac)),
                  _DetailLine('经度', vehicle.longitude),
                  _DetailLine('纬度', vehicle.latitude),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _maskId(String value) {
    if (value.isEmpty) return '未返回';
    if (value.length <= 6) return '***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }
}

class OfficialVehicleLinkPage extends StatelessWidget {
  final OfficialVehicle vehicle;

  const OfficialVehicleLinkPage({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: StreamBuilder<OfficialCloudState>(
          stream: officialCloudService.stateStream,
          initialData: officialCloudService.state,
          builder: (context, snapshot) {
            final state = snapshot.data ?? officialCloudService.state;
            final linkedId = state.linkedLocalVehicleId(vehicle.key);
            return StreamBuilder<List<VehicleProfile>>(
              stream: vehicleStore.vehiclesStream,
              initialData: vehicleStore.vehicles,
              builder: (context, vehiclesSnapshot) {
                final vehicles =
                    vehiclesSnapshot.data ?? const <VehicleProfile>[];
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    bottom: AppNav.contentBottomPadding,
                  ),
                  children: [
                    AppPageHeader(title: '关联本地车辆'),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Text(
                        '把官方车辆“${vehicle.displayName}”关联到本地 BLE 车辆后，自动通道可以优先使用 BLE，未连接时再走官方云端。',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (vehicles.isEmpty)
                      const AppCard(
                        child: Text(
                          '本地车库暂无车辆，请先扫描连接车辆。',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ...vehicles.map((local) {
                        final selected = linkedId == local.id;
                        return AppCard(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            ),
                            title: Text(local.displayName),
                            subtitle: Text(
                              '${local.protocol.label} · ${local.id}',
                            ),
                            onTap: () async {
                              await officialCloudService.linkLocalVehicle(
                                officialVehicleKey: vehicle.key,
                                localVehicleId: local.id,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已关联本地车辆')),
                                );
                              }
                            },
                          ),
                        );
                      }),
                    if (linkedId != null) ...[
                      const SizedBox(height: 4),
                      AppCard(
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await officialCloudService.unlinkLocalVehicle(
                                vehicle.key,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已取消关联')),
                                );
                              }
                            },
                            icon: const Icon(Icons.link_off),
                            label: const Text('取消关联'),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? '未返回' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
