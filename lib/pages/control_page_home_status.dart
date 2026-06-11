part of 'control_page.dart';

/// 首页电量主视觉：居中超大电量数字 + 竖向分隔线 + 右侧堆叠里程/电压。
class _StatusSection extends StatelessWidget {
  final ble.ConnectionState connState;
  const _StatusSection({required this.connState});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      initialData: connectionManager.latestBikeState,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        return StreamBuilder<OfficialCloudState>(
          stream: officialCloudService.stateStream,
          initialData: officialCloudService.state,
          builder: (context, cloudSnapshot) {
            final cloudState = cloudSnapshot.data ?? officialCloudService.state;
            final cloudVehicle = cloudState.signedIn
                ? cloudState.selectedVehicle
                : null;
            final isBleReady = connState == ble.ConnectionState.ready;
            final battery = _normalizePercent(
              isBleReady
                  ? bike?.batteryPercent ?? cloudVehicle?.electricQuantity
                  : cloudVehicle?.electricQuantity,
            );
            final batteryColor = battery == null
                ? AppColors.textTertiary
                : battery > 60
                ? AppColors.success
                : battery > 20
                ? AppColors.warning
                : AppColors.danger;
            final mileage = cloudVehicle?.mileage;
            final rangeText = mileage != null
                ? _formatMetricNumber(mileage)
                : battery != null
                ? '${(battery * _kmPerPercent).round()}'
                : '--';
            final rangeLabel = mileage != null ? '累计里程' : '预估里程';
            final voltage = isBleReady ? bike?.voltage : null;
            final voltageText = voltage != null
                ? _formatMetricNumber(voltage)
                : '--';

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: _HeroBattery(
                        value: battery != null ? '$battery' : '--',
                        color: batteryColor,
                        hasData: battery != null,
                        hint: isBleReady ? '等待数据' : '连接后查看',
                      ),
                    ),
                  ),
                  Container(width: 1, height: 56, color: AppColors.border),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeroMiniStat(
                          label: rangeLabel,
                          value: rangeText,
                          unit: rangeText == '--' ? '' : 'km',
                        ),
                        const SizedBox(height: 16),
                        _HeroMiniStat(
                          label: '电压',
                          value: voltageText,
                          unit: voltageText == '--' ? '' : 'V',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HeroBattery extends StatelessWidget {
  final String value;
  final Color color;
  final bool hasData;
  final String hint;

  const _HeroBattery({
    required this.value,
    required this.color,
    required this.hasData,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hasData ? '剩余电量，$value%' : '剩余电量，$hint',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!hasData)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: const [
                Text(
                  '--',
                  style: TextStyle(
                    fontSize: 50,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTertiary,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 6),
                  child: Text(
                    '%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _animatedMetricValue(value)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) {
                final display = _formatAnimated(value, animated);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      display,
                      style: TextStyle(
                        fontSize: 50,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 6),
                      child: Text(
                        '%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 6),
          Text(
            hasData ? '剩余电量' : hint,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _HeroMiniStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label，$value$unit',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: _AnimatedMetricText(
                  value: value,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: ReplicaColors.ink,
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// mockup 中的状态条：teal 圆点 + 设防/通电/健康文案 + 连接通道。
class _HomeStatusLine extends StatelessWidget {
  final ble.ConnectionState connState;
  const _HomeStatusLine({required this.connState});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      initialData: connectionManager.latestBikeState,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        return StreamBuilder<OfficialCloudState>(
          stream: officialCloudService.stateStream,
          initialData: officialCloudService.state,
          builder: (context, cloudSnapshot) {
            final cloudState = cloudSnapshot.data ?? officialCloudService.state;
            final cloudVehicle = cloudState.signedIn
                ? cloudState.selectedVehicle
                : null;
            final isBleReady = connState == ble.ConnectionState.ready;
            final hasBikeState = isBleReady && bike != null;
            final hasState = hasBikeState || cloudVehicle != null;
            final isLocked = hasBikeState
                ? bike.isLocked
                : cloudVehicle?.isLocked ?? true;
            final isPowerOn = hasBikeState
                ? bike.isPowerOn
                : cloudVehicle?.isPowerOn ?? false;
            final hasFault =
                hasBikeState &&
                (bike.faultMotor ||
                    bike.faultController ||
                    bike.faultBrake ||
                    bike.faultLowVoltage);
            final statusText = !hasState
                ? '等待车辆数据'
                : '${isLocked ? '已设防' : '已解锁'} · '
                      '${isPowerOn ? '已通电' : '未通电'} · '
                      '${hasFault ? '检测到异常' : '系统正常'}';
            final dotColor = !hasState
                ? AppColors.textTertiary
                : hasFault
                ? AppColors.danger
                : AppColors.success;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 数字型 metric 文本：更新时用 TweenAnimationBuilder 平滑滚动到新值，
/// 非数字（如 `--` 占位）则直接静态显示。与首页大号电量动画一致。
class _AnimatedMetricText extends StatelessWidget {
  final String value;
  final TextStyle style;

  const _AnimatedMetricText({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    if (num.tryParse(value) == null) {
      return Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _animatedMetricValue(value)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text(
        _formatAnimated(value, animated),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// 把当前的 metric 字符串解析成 double，用于 TweenAnimationBuilder 的目标值。
/// 不是数字的（如预留字符串）直接返回 0，避免动画跳到随机数。
double _animatedMetricValue(String value) {
  final parsed = num.tryParse(value);
  return parsed?.toDouble() ?? 0;
}

/// 根据 TweenAnimationBuilder 传入的当前动画值渲染最终展示字符串。
/// 整数 metric 始终保持整数显示；带小数的 metric 保留 1 位小数。
String _formatAnimated(String target, double animatedValue) {
  final parsed = num.tryParse(target);
  if (parsed == null) return target;
  if (!_hasFraction(target)) return animatedValue.round().toString();
  return animatedValue.toStringAsFixed(1);
}

bool _hasFraction(String value) => value.contains('.');
