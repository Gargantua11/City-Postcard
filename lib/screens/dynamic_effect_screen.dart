import 'package:flutter/material.dart';

import '../models/postcard_element_layer.dart';
import '../widgets/postcard_layer_render_helper.dart';

const Color _kDynamicBg = Colors.white;
const Color _kDynamicCard = Color(0xFFDDF1D0);
const Color _kDynamicCardBorder = Color(0xFFA5C39A);
const Color _kDynamicChip = Color(0xFFE8F6DD);
const Color _kDynamicChipBorder = Color(0xFFB8D3AB);
const Color _kDynamicButton = Color(0xFFD9EDCC);
const Color _kDynamicButtonDisabled = Color(0xFFEAF3E3);
const Color _kDynamicAccent = Color(0xFF5E9A66);
const Color _kDynamicTextPrimary = Color(0xFF1F2A1E);
const Color _kDynamicTextSecondary = Color(0xFF4C654A);

class DynamicEffectScreen extends StatefulWidget {
  final List<PostcardElementLayer> initialLayers;

  const DynamicEffectScreen({super.key, this.initialLayers = const []});

  @override
  State<DynamicEffectScreen> createState() => _DynamicEffectScreenState();
}

class _DynamicEffectScreenState extends State<DynamicEffectScreen> {
  static const Map<_LevelOption, double> _rotationSpeedDefaults = {
    _LevelOption.low: 0.6,
    _LevelOption.medium: 1.0,
    _LevelOption.high: 1.6,
  };

  static const Map<_LevelOption, double> _perspectiveDefaults = {
    _LevelOption.low: 0.0008,
    _LevelOption.medium: 0.0012,
    _LevelOption.high: 0.0018,
  };

  late List<PostcardElementLayer> _originalLayers;
  late List<PostcardElementLayer> _layers;
  int _selectedLayerIndex = 0;

  @override
  void initState() {
    super.initState();
    _originalLayers = List<PostcardElementLayer>.from(widget.initialLayers);
    _layers = _originalLayers.where((item) => item.isAsset).toList();
  }

  bool get _hasLayers => _layers.isNotEmpty;

  PostcardElementLayer? get _currentLayer {
    if (!_hasLayers) return null;
    var index = _selectedLayerIndex;
    if (index < 0) index = 0;
    if (index >= _layers.length) index = _layers.length - 1;
    return _layers[index];
  }

  bool get _enable3dEffect => _currentLayer?.is3dEnabled ?? false;

  _LevelOption? get _rotationOption {
    final layer = _currentLayer;
    if (layer == null) return null;

    switch (layer.speedLevel?.toLowerCase()) {
      case 'low':
        return _LevelOption.low;
      case 'medium':
        return _LevelOption.medium;
      case 'high':
        return _LevelOption.high;
    }

    return _closestOption(layer.rotationSpeed, _rotationSpeedDefaults);
  }

  _LevelOption? get _perspectiveOption {
    final layer = _currentLayer;
    if (layer == null) return null;
    return _closestOption(layer.perspective, _perspectiveDefaults);
  }

  _AxisOption get _axisOption {
    final layer = _currentLayer;
    if (layer == null) return _AxisOption.vertical;
    return layer.rotationAxis == 'horizontal'
        ? _AxisOption.horizontal
        : _AxisOption.vertical;
  }

  _DirectionOption get _directionOption {
    final layer = _currentLayer;
    if (layer == null) return _DirectionOption.clockwise;
    return layer.rotationDirection == 'counterclockwise'
        ? _DirectionOption.counterclockwise
        : _DirectionOption.clockwise;
  }

  void _setSelectedLayer(int index) {
    if (index < 0 || index >= _layers.length) return;
    setState(() => _selectedLayerIndex = index);
  }

  void _updateCurrentLayer(
    PostcardElementLayer Function(PostcardElementLayer) fn,
  ) {
    if (!_hasLayers) return;
    setState(() {
      _layers[_selectedLayerIndex] = fn(_layers[_selectedLayerIndex]);
    });
  }

  void _toggle3dEffect() {
    final current = _currentLayer;
    if (current == null) return;

    final next = !current.is3dEnabled;
    _updateCurrentLayer((layer) {
      if (!next) {
        return layer.copyWith(is3dEnabled: false, clearSpeedLevel: true);
      }
      final option = _rotationOption ?? _LevelOption.medium;
      return layer.copyWith(
        is3dEnabled: true,
        speedLevel: option.name,
        rotationSpeed: _rotationSpeedDefaults[option],
        rotationAxis: _axisOption.name,
        rotationDirection: _directionOption.name,
      );
    });
  }

  void _setRotationSpeed(_LevelOption option) {
    final speed = _rotationSpeedDefaults[option];
    _updateCurrentLayer(
      (layer) => layer.copyWith(speedLevel: option.name, rotationSpeed: speed),
    );
  }

  void _setRotationAxis(_AxisOption option) {
    _updateCurrentLayer((layer) => layer.copyWith(rotationAxis: option.name));
  }

  void _setRotationDirection(_DirectionOption option) {
    _updateCurrentLayer(
      (layer) => layer.copyWith(rotationDirection: option.name),
    );
  }

  void _setPerspective(_LevelOption option) {
    final perspective = _perspectiveDefaults[option];
    _updateCurrentLayer((layer) => layer.copyWith(perspective: perspective));
  }

  void _resetCurrentLayer() {
    _updateCurrentLayer(
      (layer) => layer.copyWith(
        is3dEnabled: false,
        rotationSpeed: _rotationSpeedDefaults[_LevelOption.medium],
        rotationAxis: _AxisOption.vertical.name,
        rotationDirection: _DirectionOption.clockwise.name,
        perspective: _perspectiveDefaults[_LevelOption.medium],
        clearSpeedLevel: true,
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已重置当前元素的动态效果')));
  }

  void _apply() {
    if (_originalLayers.isEmpty) {
      Navigator.pop(context, const <PostcardElementLayer>[]);
      return;
    }

    final updatedById = <String, PostcardElementLayer>{
      for (final layer in _layers) layer.id: layer,
    };
    final merged = <PostcardElementLayer>[];
    for (final original in _originalLayers) {
      if (original.isText) {
        merged.add(original);
        continue;
      }
      merged.add(updatedById[original.id] ?? original);
    }

    Navigator.pop(context, merged);
  }

  @override
  Widget build(BuildContext context) {
    final currentLayer = _currentLayer;
    final rotationOption = _rotationOption;
    final axisOption = _axisOption;
    final directionOption = _directionOption;
    final perspectiveOption = _perspectiveOption;

    return Scaffold(
      backgroundColor: _kDynamicBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Column(
            children: [
              Row(
                children: [
                  _BackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 16),
                  const Text(
                    '动态效果',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _kDynamicTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _hasLayers
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            _SectionCard(
                              title: '选择元素',
                              child: _LayerSelector(
                                layers: _layers,
                                selectedIndex: _selectedLayerIndex,
                                onSelect: _setSelectedLayer,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SectionCard(
                              title: '3D效果',
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 176,
                                        child: _TopToggleChip(
                                          label: '启用3D效果',
                                          checked: _enable3dEffect,
                                          onTap: _toggle3dEffect,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  IgnorePointer(
                                    ignoring: !_enable3dEffect,
                                    child: Opacity(
                                      opacity: _enable3dEffect ? 1 : 0.45,
                                      child: Column(
                                        children: [
                                          _LabeledOptionRow(
                                            label: '旋转速度：',
                                            options: [
                                              _CheckItemData(
                                                label: '低',
                                                checked:
                                                    rotationOption ==
                                                    _LevelOption.low,
                                                onTap: () => _setRotationSpeed(
                                                  _LevelOption.low,
                                                ),
                                              ),
                                              _CheckItemData(
                                                label: '中',
                                                checked:
                                                    rotationOption ==
                                                    _LevelOption.medium,
                                                onTap: () => _setRotationSpeed(
                                                  _LevelOption.medium,
                                                ),
                                              ),
                                              _CheckItemData(
                                                label: '高',
                                                checked:
                                                    rotationOption ==
                                                    _LevelOption.high,
                                                onTap: () => _setRotationSpeed(
                                                  _LevelOption.high,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '默认值：${(currentLayer?.rotationSpeed ?? 0).toStringAsFixed(1)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: _kDynamicTextSecondary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _LabeledOptionRow(
                                            label: '旋转轴向：',
                                            options: [
                                              _CheckItemData(
                                                label: '水平',
                                                checked:
                                                    axisOption ==
                                                    _AxisOption.horizontal,
                                                onTap: () => _setRotationAxis(
                                                  _AxisOption.horizontal,
                                                ),
                                              ),
                                              _CheckItemData(
                                                label: '竖直',
                                                checked:
                                                    axisOption ==
                                                    _AxisOption.vertical,
                                                onTap: () => _setRotationAxis(
                                                  _AxisOption.vertical,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          _LabeledOptionRow(
                                            label: '旋转方向：',
                                            options: [
                                              _CheckItemData(
                                                label: '顺时针',
                                                checked:
                                                    directionOption ==
                                                    _DirectionOption.clockwise,
                                                onTap: () =>
                                                    _setRotationDirection(
                                                      _DirectionOption
                                                          .clockwise,
                                                    ),
                                              ),
                                              _CheckItemData(
                                                label: '逆时针',
                                                checked:
                                                    directionOption ==
                                                    _DirectionOption
                                                        .counterclockwise,
                                                onTap: () =>
                                                    _setRotationDirection(
                                                      _DirectionOption
                                                          .counterclockwise,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          _LabeledOptionRow(
                                            label: '透视强度：',
                                            options: [
                                              _CheckItemData(
                                                label: '低',
                                                checked:
                                                    perspectiveOption ==
                                                    _LevelOption.low,
                                                onTap: () => _setPerspective(
                                                  _LevelOption.low,
                                                ),
                                              ),
                                              _CheckItemData(
                                                label: '中',
                                                checked:
                                                    perspectiveOption ==
                                                    _LevelOption.medium,
                                                onTap: () => _setPerspective(
                                                  _LevelOption.medium,
                                                ),
                                              ),
                                              _CheckItemData(
                                                label: '高',
                                                checked:
                                                    perspectiveOption ==
                                                    _LevelOption.high,
                                                onTap: () => _setPerspective(
                                                  _LevelOption.high,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '默认值：${(currentLayer?.perspective ?? 0).toStringAsFixed(4)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: _kDynamicTextSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SectionCard(
                              title: '预览参数',
                              child: _PreviewInfo(layer: currentLayer),
                            ),
                          ],
                        ),
                      )
                    : _SectionCard(
                        title: '提示',
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            '请先在编辑页添加元素，再设置每个元素的3D效果。',
                            style: TextStyle(
                              fontSize: 14,
                              color: _kDynamicTextSecondary,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomActionButton(label: '应用', onTap: _apply),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _BottomActionButton(
                        label: '重置当前',
                        onTap: _hasLayers ? _resetCurrentLayer : null,
                      ),
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

enum _LevelOption { low, medium, high }

enum _AxisOption { horizontal, vertical }

enum _DirectionOption { clockwise, counterclockwise }

_LevelOption? _closestOption(double value, Map<_LevelOption, double> defaults) {
  _LevelOption? best;
  double? delta;
  defaults.forEach((key, target) {
    final diff = (value - target).abs();
    if (delta == null || diff < delta!) {
      delta = diff;
      best = key;
    }
  });
  return best;
}

class _LayerSelector extends StatelessWidget {
  final List<PostcardElementLayer> layers;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _LayerSelector({
    required this.layers,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < layers.length; i++)
          _ElementChip(
            label: _buildLabel(layers[i], counts),
            selected: i == selectedIndex,
            onTap: () => onSelect(i),
          ),
      ],
    );
  }

  String _buildLabel(PostcardElementLayer layer, Map<String, int> counts) {
    final name = resolveLayerLabel(layer);
    final next = (counts[name] ?? 0) + 1;
    counts[name] = next;
    return '$name#$next';
  }
}

class _PreviewInfo extends StatelessWidget {
  final PostcardElementLayer? layer;

  const _PreviewInfo({required this.layer});

  @override
  Widget build(BuildContext context) {
    if (layer == null) {
      return const Text(
        '暂无元素',
        style: TextStyle(fontSize: 14, color: _kDynamicTextSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当前元素：${layer!.elementKey}',
          style: const TextStyle(fontSize: 14, color: _kDynamicTextPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          '3D开关：${layer!.is3dEnabled ? '开启' : '关闭'}',
          style: const TextStyle(fontSize: 13, color: _kDynamicTextSecondary),
        ),
        Text(
          '旋转速度：${layer!.rotationSpeed.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 13, color: _kDynamicTextSecondary),
        ),
        Text(
          '旋转轴向：${layer!.rotationAxis == 'horizontal' ? '水平' : '竖直'}',
          style: const TextStyle(fontSize: 13, color: _kDynamicTextSecondary),
        ),
        Text(
          '旋转方向：${layer!.rotationDirection == 'counterclockwise' ? '逆时针' : '顺时针'}',
          style: const TextStyle(fontSize: 13, color: _kDynamicTextSecondary),
        ),
        Text(
          '透视强度：${layer!.perspective.toStringAsFixed(4)}',
          style: const TextStyle(fontSize: 13, color: _kDynamicTextSecondary),
        ),
      ],
    );
  }
}

class _ElementChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ElementChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFBFE0B2) : _kDynamicChip,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kDynamicAccent : _kDynamicChipBorder,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: _kDynamicTextPrimary),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _kDynamicButton,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kDynamicCardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply, size: 18, color: _kDynamicTextPrimary),
            SizedBox(width: 6),
            Text(
              '返回',
              style: TextStyle(fontSize: 15, color: _kDynamicTextPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopToggleChip extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _TopToggleChip({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _kDynamicCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kDynamicCardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              checked
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: _kDynamicTextPrimary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kDynamicTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: _kDynamicCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kDynamicCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _kDynamicTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _OptionCheck extends StatelessWidget {
  final String text;
  final bool checked;
  final VoidCallback onTap;

  const _OptionCheck({
    required this.text,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              checked
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: _kDynamicTextPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(fontSize: 13, color: _kDynamicTextPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckItemData {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _CheckItemData({
    required this.label,
    required this.checked,
    required this.onTap,
  });
}

class _LabeledOptionRow extends StatelessWidget {
  final String label;
  final List<_CheckItemData> options;

  const _LabeledOptionRow({required this.label, required this.options});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: _kDynamicTextPrimary),
          ),
          const SizedBox(width: 6),
          for (var i = 0; i < options.length; i++) ...[
            _OptionCheck(
              text: options[i].label,
              checked: options[i].checked,
              onTap: options[i].onTap,
            ),
            if (i != options.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _BottomActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? _kDynamicButton : _kDynamicButtonDisabled,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kDynamicCardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: enabled ? _kDynamicTextPrimary : const Color(0xFF7A8875),
          ),
        ),
      ),
    );
  }
}
