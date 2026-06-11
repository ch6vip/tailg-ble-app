part of 'control_page.dart';

/// 控车动作进行中的固定文案，避免散落硬编码字符串。
enum ControlLoadingLabel {
  unlock('解锁中'),
  lock('设防中'),
  find('寻车中'),
  start('启动中'),
  stop('熄火中'),
  execute('执行中');

  final String text;
  const ControlLoadingLabel(this.text);
}

/// Runtime descriptor for a single main-control button.
class _MainControlButtonData {
  final String id;
  final IconData icon;
  final String label;
  final Color accent;
  final String loadingLabel;
  final bool enabled;
  final bool active;
  final String disabledReason;
  final VoidCallback onTap;

  const _MainControlButtonData({
    required this.id,
    required this.icon,
    required this.label,
    required this.accent,
    required this.loadingLabel,
    required this.enabled,
    required this.active,
    required this.disabledReason,
    required this.onTap,
  });
}

/// Static display info for the edit page (independent of vehicle state).
class _MainControlCatalogEntry {
  final String id;
  final IconData icon;
  final String label;
  final Color accent;

  const _MainControlCatalogEntry({
    required this.id,
    required this.icon,
    required this.label,
    required this.accent,
  });
}

const _mainControlCatalog = [
  _MainControlCatalogEntry(
    id: 'find',
    icon: Icons.volume_up,
    label: '寻车',
    accent: AppColors.accentTeal,
  ),
  _MainControlCatalogEntry(
    id: 'lock',
    icon: Icons.lock_outline,
    label: '设防 / 解锁',
    accent: _serviceAccentAmber,
  ),
  _MainControlCatalogEntry(
    id: 'seat',
    icon: Icons.inventory_2,
    label: '座桶',
    accent: Color(0xFF8D6E63),
  ),
];

/// 首页主控区：整条全宽黑色滑块 + 可排序控制按钮（默认寻车 / 设防 / 座桶）。
/// 长按按钮行打开编辑页。
class _OfficialMainControlCard extends StatelessWidget {
  final String powerLabel;
  final String powerHint;
  final IconData powerIcon;
  final bool reverseSlide;
  final bool powerLoading;
  final String powerLoadingLabel;
  final Color powerColor;
  final bool enabled;
  final String disabledReason;
  final VoidCallback onDisabledTap;
  final VoidCallback onPowerSlideComplete;
  final List<_MainControlButtonData> buttons;
  final VoidCallback onEditButtons;

  const _OfficialMainControlCard({
    required this.powerLabel,
    required this.powerHint,
    required this.powerIcon,
    required this.reverseSlide,
    required this.powerLoading,
    required this.powerLoadingLabel,
    required this.powerColor,
    required this.enabled,
    required this.disabledReason,
    required this.onDisabledTap,
    required this.onPowerSlideComplete,
    required this.buttons,
    required this.onEditButtons,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: _PrimaryPowerControl(
            label: powerLabel,
            hint: powerHint,
            icon: powerIcon,
            reverseSlide: reverseSlide,
            loading: powerLoading,
            loadingLabel: powerLoadingLabel,
            color: powerColor,
            enabled: enabled,
            disabledReason: disabledReason,
            onDisabledTap: onDisabledTap,
            onSlideComplete: onPowerSlideComplete,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 84,
          child: Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _OfficialSmallControlButton(
                    icon: buttons[i].icon,
                    label: buttons[i].label,
                    accentColor: buttons[i].accent,
                    loadingLabel: buttons[i].loadingLabel,
                    enabled: buttons[i].enabled,
                    active: buttons[i].active,
                    loading: buttons[i].active,
                    disabledReason: buttons[i].disabledReason,
                    onTap: buttons[i].onTap,
                    onLongPress: onEditButtons,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OfficialSmallControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? accentColor;
  final String loadingLabel;
  final bool enabled;
  final bool active;
  final bool loading;
  final String disabledReason;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _OfficialSmallControlButton({
    required this.icon,
    required this.label,
    this.accentColor,
    this.loadingLabel = '执行中',
    required this.enabled,
    required this.active,
    required this.loading,
    required this.disabledReason,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_OfficialSmallControlButton> createState() =>
      _OfficialSmallControlButtonState();
}

class _OfficialSmallControlButtonState
    extends State<_OfficialSmallControlButton> {
  static const _motionDuration = Duration(milliseconds: 150);
  static const _motionCurve = Curves.easeOutCubic;

  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _showDisabledReason() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.disabledReason),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && !widget.loading;
    final accent = widget.accentColor ?? AppColors.dark;
    final color = widget.active ? accent : accent;
    final background = widget.active
        ? accent.withValues(alpha: _pressed ? 0.16 : 0.1)
        : _pressed
        ? const Color(0xFFF2F2F0)
        : Colors.white;
    final shadow = widget.active
        ? [BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))]
        : _pressed
        ? [BoxShadow(color: const Color(0x06000000), blurRadius: 4, offset: const Offset(0, 1))]
        : AppShadows.elevation1;
    const iconSize = 26.0;
    const fontSize = 12.0;
    const iconGap = 6.0;
    return AnimatedScale(
      duration: _motionDuration,
      curve: _motionCurve,
      scale: _pressed ? 0.96 : 1,
      child: AnimatedContainer(
        duration: _motionDuration,
        curve: _motionCurve,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          boxShadow: shadow,
        ),
        child: AnimatedOpacity(
          opacity: widget.enabled || widget.loading ? 1 : 0.54,
          duration: _motionDuration,
          curve: _motionCurve,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              splashColor: accent.withValues(alpha: 0.08),
              highlightColor: accent.withValues(alpha: 0.05),
              onTap: widget.loading
                  ? null
                  : interactive
                  ? () {
                      HapticFeedback.mediumImpact();
                      widget.onTap();
                    }
                  : _showDisabledReason,
              onLongPress: widget.onLongPress,
              onTapDown: interactive ? (_) => _setPressed(true) : null,
              onTapUp: interactive ? (_) => _setPressed(false) : null,
              onTapCancel: interactive ? () => _setPressed(false) : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: _motionDuration,
                      switchInCurve: _motionCurve,
                      switchOutCurve: Curves.easeInCubic,
                      child: widget.loading
                          ? _PulseActionIcon(
                              key: const ValueKey('loading-icon'),
                              icon: widget.icon,
                              color: color,
                            )
                          : Icon(
                              widget.icon,
                              key: const ValueKey('idle-icon'),
                              color: color,
                              size: iconSize,
                            ),
                    ),
                    const SizedBox(height: iconGap),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: _motionDuration,
                        switchInCurve: _motionCurve,
                        switchOutCurve: Curves.easeInCubic,
                        child: Text(
                          widget.loading ? widget.loadingLabel : widget.label,
                          key: ValueKey(
                            widget.loading ? widget.loadingLabel : widget.label,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: widget.enabled
                                ? AppColors.textSecondary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryPowerControl extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool reverseSlide;
  final bool loading;
  final String loadingLabel;
  final Color color;
  final bool enabled;
  final String disabledReason;
  final VoidCallback onDisabledTap;
  final VoidCallback onSlideComplete;

  const _PrimaryPowerControl({
    required this.label,
    required this.hint,
    required this.icon,
    required this.reverseSlide,
    required this.loading,
    required this.loadingLabel,
    required this.color,
    required this.enabled,
    required this.disabledReason,
    required this.onDisabledTap,
    required this.onSlideComplete,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SlideToAction(
        label: enabled ? (reverseSlide ? '左滑关闭' : '右滑启动') : '请连接车辆',
        icon: reverseSlide
            ? Icons.keyboard_double_arrow_left
            : Icons.keyboard_double_arrow_right,
        reverseSlide: reverseSlide,
        loading: loading,
        loadingLabel: loadingLabel,
        backgroundColor: enabled ? AppColors.dark : const Color(0xFFE8E8E5),
        thumbColor: Colors.white,
        enabled: enabled,
        height: 60,
        thumbSize: 48,
        thumbRadius: 14,
        trackInset: 6,
        iconSize: 24,
        labelFontSize: 14,
        loadingFontSize: 16,
        centerLabel: true,
        // The thumb already carries a double-arrow icon; a second pair of
        // direction chevrons next to the label is redundant.
        showCenterChevron: false,
        labelColor: enabled
            ? Colors.white.withValues(alpha: 0.85)
            : AppColors.textTertiary,
        chevronColor: Colors.white.withValues(alpha: 0.5),
        thumbIconColor: AppColors.dark,
        disabledBackgroundColor: const Color(0xFFE8E8E5),
        disabledThumbColor: Colors.white,
        disabledIconColor: AppColors.textTertiary,
        completionThreshold: 0.94,
        fadeLabelOnSlide: true,
        onDisabledTap: onDisabledTap,
        onSlideComplete: onSlideComplete,
      ),
    );
  }
}

/// Edit page for the main control buttons: drag to reorder, toggle to show or
/// hide each control. Returns the updated [MainControlConfig] (or null when
/// dismissed). No BLE/control logic — only which buttons appear on home.
class _MainControlEditPage extends StatefulWidget {
  final List<_MainControlCatalogEntry> entries;
  final Set<String> hidden;

  const _MainControlEditPage({required this.entries, required this.hidden});

  @override
  State<_MainControlEditPage> createState() => _MainControlEditPageState();
}

class _MainControlEditPageState extends State<_MainControlEditPage> {
  late List<_MainControlCatalogEntry> _order;
  late Set<String> _hidden;

  @override
  void initState() {
    super.initState();
    _order = List.of(widget.entries);
    _hidden = Set.of(widget.hidden);
  }

  int get _visibleCount => _order.where((e) => !_hidden.contains(e.id)).length;

  void _save() {
    Navigator.pop(
      context,
      MainControlConfig(
        order: _order.map((e) => e.id).toList(),
        hidden: _hidden,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '主控按钮设置',
              actions: [TextButton(onPressed: _save, child: const Text('保存'))],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '拖动排序，开关控制是否在首页显示（至少保留 1 个）',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                physics: const BouncingScrollPhysics(),
                itemCount: _order.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _order.removeAt(oldIndex);
                    _order.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final entry = _order[index];
                  final visible = !_hidden.contains(entry.id);
                  final lockOff = visible && _visibleCount <= 1;
                  return Padding(
                    key: ValueKey(entry.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EditableListRow(
                      icon: entry.icon,
                      label: entry.label,
                      accent: entry.accent,
                      visible: visible,
                      lockOff: lockOff,
                      dragIndex: index,
                      onVisibleChanged: (value) {
                        setState(() {
                          if (value) {
                            _hidden.remove(entry.id);
                          } else {
                            _hidden.add(entry.id);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
