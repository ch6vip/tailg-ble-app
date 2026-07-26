import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../services/app_navigation.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';
import '../widgets/vehicle_stage.dart';
import 'add_vehicle_page.dart';
import 'garage_code_scanner_page.dart';
import 'login_page.dart';

enum _GarageSearchType {
  frame('车架号', '请输入车架号'),
  sharePhone('被分享人手机号', '请输入手机号');

  const _GarageSearchType(this.label, this.hint);

  final String label;
  final String hint;
}

/// Official GarageV2 information architecture with the app's CyberHome skin.
class GaragePage extends StatefulWidget {
  const GaragePage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<GaragePage> createState() => _GaragePageState();
}

class _GaragePageState extends State<GaragePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<OfficialCloudState>? _cloudSub;
  late OfficialCloudState _cloudState;
  List<OfficialVehicle> _vehicles = const [];
  _GarageSearchType _searchType = _GarageSearchType.frame;
  String _activeQuery = '';
  String? _error;
  String? _busyVehicleKey;
  var _pageIndex = 0;
  var _hasNext = false;
  var _loading = false;
  var _loadingMore = false;
  var _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _cloudState = officialCloudService.state;
    _vehicles = _cloudState.vehicles;
    _cloudSub = officialCloudService.stateStream.listen(_onCloudState);
    _scrollController.addListener(_onScroll);
    if (_cloudState.signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadPage(refresh: true));
      });
    }
  }

  @override
  void dispose() {
    _requestGeneration += 1;
    final cloudSub = _cloudSub;
    if (cloudSub != null) unawaited(cloudSub.cancel());
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onCloudState(OfficialCloudState state) {
    if (!mounted) return;
    final sessionChanged = state.token != _cloudState.token;
    setState(() {
      _cloudState = state;
      if (state.signedIn && _vehicles.isEmpty && state.vehicles.isNotEmpty) {
        _vehicles = state.vehicles;
      }
      if (!state.signedIn) {
        _vehicles = const [];
        _pageIndex = 0;
        _hasNext = false;
      }
    });
    if (sessionChanged && state.signedIn) {
      unawaited(_loadPage(refresh: true));
    }
  }

  void _onScroll() {
    if (!_hasNext || _loading || _loadingMore) return;
    if (_scrollController.position.extentAfter < 240) {
      unawaited(_loadPage(refresh: false));
    }
  }

  Future<void> _loadPage({required bool refresh}) async {
    if (!_cloudState.signedIn) return;
    if (refresh ? _loading : _loadingMore) return;
    final generation = ++_requestGeneration;
    final nextPage = refresh ? 1 : _pageIndex + 1;
    setState(() {
      if (refresh) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await officialCloudService.fetchGaragePage(
        pageIndex: nextPage,
        frame: _searchType == _GarageSearchType.frame ? _activeQuery : '',
        shareUserPhone: _searchType == _GarageSearchType.sharePhone
            ? _activeQuery
            : '',
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _vehicles = refresh
            ? result.vehicles
            : [..._vehicles, ...result.vehicles];
        _pageIndex = result.pageIndex;
        _hasNext = result.hasNext;
        _error = null;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      final message = OfficialCloudRedactor.errorMessage(e);
      setState(() => _error = message);
      if (_vehicles.isNotEmpty) AppSnack.error(context, message);
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() => _loadPage(refresh: true);

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      AppSnack.error(
        context,
        _searchType == _GarageSearchType.frame ? '车架号不能为空' : '被分享人手机号不能为空',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _activeQuery = query);
    unawaited(_loadPage(refresh: true));
  }

  Future<void> _clearSearch() async {
    _searchController.clear();
    if (_activeQuery.isEmpty) return;
    setState(() => _activeQuery = '');
    await _loadPage(refresh: true);
  }

  Future<void> _chooseSearchType() async {
    final selected = await showModalBottomSheet<_GarageSearchType>(
      context: context,
      backgroundColor: CyberHomeColors.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '搜索方式',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CyberHomeColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              for (final type in _GarageSearchType.values)
                _SearchTypeOption(
                  type: type,
                  selected: type == _searchType,
                  onTap: () => Navigator.of(context).pop(type),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == _searchType || !mounted) return;
    setState(() {
      _searchType = selected;
      _activeQuery = '';
      _searchController.clear();
    });
    await _loadPage(refresh: true);
  }

  Future<void> _scanVehicleCode() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const GarageCodeScannerPage()),
    );
    if (!mounted || raw == null) return;
    final code = _normalizeVehicleCode(raw);
    if (code == null) {
      AppSnack.error(context, '车架码错误');
      return;
    }
    setState(() {
      _searchType = _GarageSearchType.frame;
      _activeQuery = code;
      _searchController.text = code;
    });
    await _loadPage(refresh: true);
  }

  String? _normalizeVehicleCode(String raw) {
    var value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      value = uri.queryParameters['barcode']?.trim() ?? '';
    }
    return RegExp(r'^[0-9a-zA-Z]{2,20}$').hasMatch(value) ? value : null;
  }

  void _openAddVehicle() {
    final page = _cloudState.signedIn
        ? const AddVehiclePage()
        : const LoginPage();
    unawaited(
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }

  bool _isUsing(OfficialVehicle vehicle) {
    final selected = _cloudState.selectedVehicle;
    return vehicle.isUsing ||
        selected != null &&
            selected.carId.isNotEmpty &&
            vehicle.carId == selected.carId;
  }

  Future<void> _selectVehicle(OfficialVehicle vehicle) async {
    if (_isUsing(vehicle)) {
      AppSnack.info(context, '该车辆已是当前使用车辆');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberHomeColors.card,
        title: const Text('切换车辆'),
        content: Text('确认切换到“${vehicle.displayName}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认切换'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyVehicleKey = vehicle.key);
    try {
      await officialMqttService.disconnect();
      await connectionManager.removeBond(quiet: true);
      await connectionManager.disconnect();
      await officialCloudService.changeUsingVehicle(vehicle);
      if (!mounted) return;
      AppNavigation.returnToVehicleHome(context);
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busyVehicleKey = null);
    }
  }

  Future<void> _renameVehicle(OfficialVehicle vehicle) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RenameVehicleDialog(initialName: vehicle.displayName),
    );
    final nickName = result?.trim() ?? '';
    if (!mounted || nickName.isEmpty || nickName == vehicle.displayName) return;

    setState(() => _busyVehicleKey = vehicle.key);
    try {
      await officialCloudService.updateCarNickName(
        carId: vehicle.carId,
        carNickName: nickName,
      );
      if (!mounted) return;
      setState(() {
        _vehicles = [
          for (final item in _vehicles)
            if (item.key == vehicle.key)
              OfficialVehicle.fromJson({
                ...item.toJson(),
                'carNickName': nickName,
              })
            else
              item,
        ];
      });
      AppSnack.success(context, '车辆名称已修改');
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busyVehicleKey = null);
    }
  }

  Future<void> _showVehicleCode(OfficialVehicle vehicle) async {
    if (vehicle.frame.isEmpty) {
      AppSnack.error(context, '该车辆暂无车架号');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CyberHomeColors.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '车辆码',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CyberHomeColors.ink,
                ),
              ),
              const SizedBox(height: 18),
              QrImageView(
                data: vehicle.frame,
                size: 220,
                padding: const EdgeInsets.all(12),
                backgroundColor: CyberHomeColors.white,
              ),
              const SizedBox(height: 14),
              Text(
                '车架号：${vehicle.frame}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: CyberHomeColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unbindVehicle(OfficialVehicle vehicle) async {
    final phone = _cloudState.phone.trim();
    if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
      AppSnack.error(context, '账号手机号不完整，请使用手机号重新登录后解绑');
      return;
    }
    final masked = '${phone.substring(0, 3)}****${phone.substring(7)}';
    final input = await showDialog<String>(
      context: context,
      builder: (context) => _UnbindVerificationDialog(maskedPhone: masked),
    );
    if (input == null || !mounted) return;
    if (input != phone.substring(3, 7)) {
      AppSnack.error(context, '手机号验证失败');
      return;
    }

    setState(() => _busyVehicleKey = vehicle.key);
    try {
      if (_isUsing(vehicle)) {
        await officialMqttService.disconnect();
        await connectionManager.removeBond(quiet: true);
        await connectionManager.disconnect();
      }
      await officialCloudService.unbindVehicle(
        carId: vehicle.carId,
        unbindType: vehicle.shareCarFlag ? 2 : 1,
      );
      if (!mounted) return;
      AppSnack.success(context, '车辆已解绑');
      await _loadPage(refresh: true);
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busyVehicleKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _cloudState.signedIn;
    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      bottomNavigationBar: _GarageAddBar(
        onTap: _openAddVehicle,
        label: signedIn ? '添加爱车' : '登录并添加爱车',
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _GarageSearchHeader(
              showBack: !widget.embedded,
              controller: _searchController,
              type: _searchType,
              onBack: () => Navigator.of(context).pop(),
              onChooseType: _chooseSearchType,
              onScan: _scanVehicleCode,
              onSearch: _submitSearch,
              onClear: _clearSearch,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '点击卡片选择设备',
                  style: TextStyle(
                    fontSize: 13,
                    color: CyberHomeColors.inkMuted,
                  ),
                ),
              ),
            ),
            Expanded(
              child: !signedIn
                  ? _GarageSignedOut(onLogin: _openAddVehicle)
                  : _buildVehicleList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleList() {
    if (_loading && _vehicles.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: CyberHomeColors.primary),
      );
    }
    if (_error != null && _vehicles.isEmpty) {
      return _GarageError(message: _error!, onRetry: _refresh);
    }
    if (_vehicles.isEmpty) {
      return _GarageEmpty(searching: _activeQuery.isNotEmpty);
    }

    return RefreshIndicator(
      color: CyberHomeColors.primary,
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: _vehicles.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _vehicles.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CyberHomeColors.primary,
                  ),
                ),
              ),
            );
          }
          final vehicle = _vehicles[index];
          return _GarageVehicleCard(
            vehicle: vehicle,
            isUsing: _isUsing(vehicle),
            busy: _busyVehicleKey == vehicle.key,
            onTap: () => _selectVehicle(vehicle),
            onRename: () => _renameVehicle(vehicle),
            onVehicleCode: () => _showVehicleCode(vehicle),
            onUnbind: () => _unbindVehicle(vehicle),
          );
        },
      ),
    );
  }
}

class _RenameVehicleDialog extends StatefulWidget {
  const _RenameVehicleDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameVehicleDialog> createState() => _RenameVehicleDialogState();
}

class _RenameVehicleDialogState extends State<_RenameVehicleDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CyberHomeColors.card,
      title: const Text('修改设备名称'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 20,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: '请输入设备名称'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _UnbindVerificationDialog extends StatefulWidget {
  const _UnbindVerificationDialog({required this.maskedPhone});

  final String maskedPhone;

  @override
  State<_UnbindVerificationDialog> createState() =>
      _UnbindVerificationDialogState();
}

class _UnbindVerificationDialogState extends State<_UnbindVerificationDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CyberHomeColors.card,
      title: const Text('验证后解绑'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('请输入绑定号码 ${widget.maskedPhone} 的中间 4 位'),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: '手机号中间 4 位'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('确认解绑'),
        ),
      ],
    );
  }
}

class _GarageSearchHeader extends StatelessWidget {
  const _GarageSearchHeader({
    required this.showBack,
    required this.controller,
    required this.type,
    required this.onBack,
    required this.onChooseType,
    required this.onScan,
    required this.onSearch,
    required this.onClear,
  });

  final bool showBack;
  final TextEditingController controller;
  final _GarageSearchType type;
  final VoidCallback onBack;
  final VoidCallback onChooseType;
  final VoidCallback onScan;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(showBack ? 8 : 16, 10, 16, 4),
      child: Row(
        children: [
          if (showBack) ...[
            Tooltip(
              message: '返回',
              child: AppPressable(
                key: const ValueKey('garage-back'),
                onTap: onBack,
                semanticsLabel: '返回',
                semanticsButton: true,
                child: const SizedBox(
                  width: AppTouchTargets.min,
                  height: AppTouchTargets.min,
                  child: Center(
                    child: LucideIcon(
                      Lucide.arrowLeft,
                      size: 20,
                      color: CyberHomeColors.inkSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: CyberHomeColors.card,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(color: CyberHomeColors.line),
                boxShadow: AppShadows.cyberActionShadow,
              ),
              child: Row(
                children: [
                  AppPressable(
                    onTap: onChooseType,
                    semanticsLabel: '搜索方式：${type.label}',
                    semanticsButton: true,
                    child: SizedBox(
                      width: type == _GarageSearchType.frame ? 78 : 104,
                      height: 52,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              type.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CyberHomeColors.inkSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const LucideIcon(
                            Lucide.chevronDown,
                            size: 14,
                            color: CyberHomeColors.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                    child: VerticalDivider(
                      width: 1,
                      color: CyberHomeColors.lineStrong,
                    ),
                  ),
                  Tooltip(
                    message: '扫描车架码',
                    child: AppPressable(
                      onTap: onScan,
                      semanticsLabel: '扫描车架码',
                      semanticsButton: true,
                      child: const SizedBox(
                        width: AppTouchTargets.min,
                        height: 52,
                        child: Center(
                          child: LucideIcon(
                            Lucide.scan,
                            size: 19,
                            color: CyberHomeColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('garage-search-field'),
                      controller: controller,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CyberHomeColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: type.hint,
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: CyberHomeColors.inkFaint,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                      ),
                      onSubmitted: (_) => onSearch(),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : Tooltip(
                            message: '清空搜索',
                            child: AppPressable(
                              onTap: onClear,
                              semanticsLabel: '清空搜索',
                              semanticsButton: true,
                              child: const SizedBox(
                                width: 36,
                                height: 52,
                                child: Center(
                                  child: LucideIcon(
                                    Lucide.x,
                                    size: 16,
                                    color: CyberHomeColors.inkFaint,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  AppPressable(
                    key: const ValueKey('garage-search'),
                    onTap: onSearch,
                    semanticsLabel: '搜索',
                    semanticsButton: true,
                    child: const SizedBox(
                      width: 48,
                      height: 52,
                      child: Center(
                        child: Text(
                          '搜索',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: CyberHomeColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTypeOption extends StatelessWidget {
  const _SearchTypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final _GarageSearchType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticsLabel: type.label,
      semanticsButton: true,
      semanticsSelected: selected,
      pressedBackground: CyberHomeColors.cardMuted,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            LucideIcon(
              type == _GarageSearchType.frame ? Lucide.scan : Lucide.phone,
              size: 19,
              color: selected
                  ? CyberHomeColors.primary
                  : CyberHomeColors.inkMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                type.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CyberHomeColors.ink,
                ),
              ),
            ),
            if (selected)
              const LucideIcon(
                Lucide.check,
                size: 19,
                color: CyberHomeColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _GarageVehicleCard extends StatelessWidget {
  const _GarageVehicleCard({
    required this.vehicle,
    required this.isUsing,
    required this.busy,
    required this.onTap,
    required this.onRename,
    required this.onVehicleCode,
    required this.onUnbind,
  });

  final OfficialVehicle vehicle;
  final bool isUsing;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onVehicleCode;
  final VoidCallback onUnbind;

  @override
  Widget build(BuildContext context) {
    final shared = vehicle.shareCarFlag;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: CyberHomeColors.card,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(
          color: isUsing ? CyberHomeColors.primary : CyberHomeColors.line,
          width: isUsing ? 1.5 : 1,
        ),
        boxShadow: AppShadows.cyberCardShadow,
      ),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: '${vehicle.displayName}${isUsing ? '，使用中' : '，点击切换'}',
        button: true,
        child: AppPressable(
          enabled: !busy,
          onTap: onTap,
          haptic: false,
          semanticsButton: false,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          pressedBackground: CyberHomeColors.cardMuted,
          child: SizedBox(
            height: 398,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicle.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: CyberHomeColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (isUsing)
                                      const _GarageBadge(
                                        text: '使用中',
                                        color: CyberHomeColors.primary,
                                        background: CyberHomeColors.primarySoft,
                                      ),
                                    _GarageStatus(online: vehicle.online),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              LucideIcon(
                                shared ? Lucide.users : Lucide.userCircle,
                                size: 22,
                                color: shared
                                    ? CyberHomeColors.warning
                                    : CyberHomeColors.primary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                shared ? '好友车辆' : '车主车辆',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CyberHomeColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(child: _GarageVehicleVisual(vehicle: vehicle)),
                      if (vehicle.shareCount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const LucideIcon(
                              Lucide.share,
                              size: 14,
                              color: CyberHomeColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '已分享 ${vehicle.shareCount} 次',
                              style: const TextStyle(
                                fontSize: 12,
                                color: CyberHomeColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          if (!shared)
                            _GarageCardAction(
                              icon: Lucide.scan,
                              label: '车辆码',
                              onTap: onVehicleCode,
                            ),
                          const Spacer(),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    vehicle.carName.isEmpty
                                        ? '台铃智能车辆'
                                        : vehicle.carName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: CyberHomeColors.inkSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                _GarageCardAction(
                                  icon: Lucide.edit,
                                  label: '修改',
                                  compact: true,
                                  onTap: onRename,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (!shared)
                            _GarageCardAction(
                              icon: Lucide.unlink,
                              label: '解绑',
                              danger: true,
                              onTap: onUnbind,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (busy)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CyberHomeColors.white75,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: CyberHomeColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GarageVehicleVisual extends StatelessWidget {
  const _GarageVehicleVisual({required this.vehicle});

  final OfficialVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final imageUrl = vehicle.carPhoto.trim();
    if (imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        fit: BoxFit.contain,
        placeholder: (_, _) => const _GarageVehicleFallback(),
        errorWidget: (_, _, _) => const _GarageVehicleFallback(),
      );
    }
    return const _GarageVehicleFallback();
  }
}

class _GarageVehicleFallback extends StatelessWidget {
  const _GarageVehicleFallback();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: VehicleStagePainter(batteryLevel: 0.72),
      size: const Size(double.infinity, 210),
    );
  }
}

class _GarageCardAction extends StatelessWidget {
  const _GarageCardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = danger ? CyberHomeColors.danger : CyberHomeColors.primary;
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: label,
      semanticsButton: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppTouchTargets.min,
          minHeight: AppTouchTargets.min,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LucideIcon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GarageBadge extends StatelessWidget {
  const _GarageBadge({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _GarageStatus extends StatelessWidget {
  const _GarageStatus({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? CyberHomeColors.success : CyberHomeColors.inkFaint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          online ? '在线' : '离线',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _GarageAddBar extends StatelessWidget {
  const _GarageAddBar({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: CyberHomeColors.pageBg,
        padding: const EdgeInsets.fromLTRB(40, 10, 40, 14),
        child: FilledButton.icon(
          key: const ValueKey('garage-add'),
          onPressed: onTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: CyberHomeColors.primary,
            foregroundColor: CyberHomeColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
          ),
          icon: const LucideIcon(Lucide.plus, size: 19),
          label: Text(label),
        ),
      ),
    );
  }
}

class _GarageSignedOut extends StatelessWidget {
  const _GarageSignedOut({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return _GarageMessage(
      icon: Lucide.login,
      title: '登录后查看我的车库',
      subtitle: '车辆搜索、切换、改名和解绑需要官方账号。',
      actionLabel: '登录账号',
      onAction: onLogin,
    );
  }
}

class _GarageEmpty extends StatelessWidget {
  const _GarageEmpty({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return _GarageMessage(
      icon: searching ? Lucide.search : Lucide.garage,
      title: searching ? '未找到车辆' : '车库暂无车辆',
      subtitle: searching ? '请检查搜索信息后重试。' : '添加爱车后会显示在这里。',
    );
  }
}

class _GarageError extends StatelessWidget {
  const _GarageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _GarageMessage(
      icon: Lucide.cloudOff,
      title: '车库加载失败',
      subtitle: message,
      actionLabel: '重新加载',
      onAction: onRetry,
    );
  }
}

class _GarageMessage extends StatelessWidget {
  const _GarageMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CyberHomeColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: LucideIcon(icon, size: 27, color: CyberHomeColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: CyberHomeColors.inkMuted,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
