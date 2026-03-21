import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/postcard_element_layer.dart';
import '../widgets/postcard_layer_render_helper.dart';

class AddTextScreen extends StatefulWidget {
  final PostcardElementLayer initialLayer;

  const AddTextScreen({super.key, required this.initialLayer});

  @override
  State<AddTextScreen> createState() => _AddTextScreenState();
}

class _AddTextScreenState extends State<AddTextScreen> {
  static const double _previewAspectRatio = 400 / 258;
  static const List<String> _alignOptions = <String>['left', 'center', 'right'];
  static const List<String> _textColors = <String>[
    '#FFFFFF',
    '#000000',
    '#FFE082',
    '#90CAF9',
    '#81C784',
    '#F48FB1',
  ];
  static const List<String> _boxColors = <String>[
    'rgba(0,0,0,0.25)',
    'rgba(255,255,255,0.35)',
    'rgba(0,0,0,0.45)',
    'rgba(31,65,114,0.35)',
    'rgba(84,53,89,0.35)',
    'rgba(0,0,0,0)',
  ];

  late final TextEditingController _textController;
  late PostcardElementLayer _layer;

  PostcardTextLayerStyle get _style => _layer.resolvedStyle;
  PostcardTextLayerBox get _box => _layer.resolvedBox;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialLayer.isText
        ? widget.initialLayer
        : widget.initialLayer.copyWith(type: 'text', text: '');
    _layer = initial.copyWith(
      type: 'text',
      style: (initial.style ?? const PostcardTextLayerStyle()).copyWith(
        fontFamily: 'serif',
      ),
      box: initial.box ?? const PostcardTextLayerBox(),
      elementKey: '',
      assetPath: '',
      is3dEnabled: false,
      rotateX: 0,
      rotateY: 0,
      rotationSpeed: 1,
      clearSpeedLevel: true,
    );

    _textController = TextEditingController(text: _layer.text ?? '');
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final value = _textController.text;
    if ((_layer.text ?? '') == value) return;
    setState(() {
      _layer = _layer.copyWith(text: value);
    });
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _updateStyle(
    PostcardTextLayerStyle Function(PostcardTextLayerStyle) op,
  ) {
    setState(() {
      _layer = _layer.copyWith(style: op(_style));
    });
  }

  void _updateBox(PostcardTextLayerBox Function(PostcardTextLayerBox) op) {
    setState(() {
      _layer = _layer.copyWith(box: op(_box));
    });
  }

  void _updateLayer(PostcardElementLayer Function(PostcardElementLayer) op) {
    setState(() {
      _layer = op(_layer);
    });
  }

  double get _fontWeightNumber {
    final raw = _style.fontWeight.trim().toLowerCase();
    if (raw == 'bold') return 700;
    if (raw == 'normal') return 400;
    final parsed = double.tryParse(raw);
    if (parsed == null) return 600;
    return parsed.clamp(100, 900).toDouble();
  }

  String get _alignValue {
    final raw = _style.align.trim().toLowerCase();
    if (_alignOptions.contains(raw)) return raw;
    return 'center';
  }

  String _displayAlignLabel(String value) {
    switch (value) {
      case 'left':
        return '左对齐';
      case 'right':
        return '右对齐';
      default:
        return '居中';
    }
  }

  void _applyAndBack() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showHint('请先输入文字');
      return;
    }
    Navigator.pop(
      context,
      _layer.copyWith(
        type: 'text',
        text: text,
        elementKey: '',
        assetPath: '',
        style: _style.copyWith(fontFamily: 'serif'),
        box: _box,
        is3dEnabled: false,
        rotateX: 0,
        rotateY: 0,
        rotationSpeed: 1,
        clearSpeedLevel: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加文字'),
        actions: [
          TextButton(onPressed: _applyAndBack, child: const Text('应用')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactPreviewWidth = (constraints.maxWidth * 0.56)
                      .clamp(180.0, 280.0)
                      .toDouble();
                  return Center(child: _buildPreview(compactPreviewWidth));
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  children: [
                    _buildTextSection(),
                    const SizedBox(height: 12),
                    _buildTransformSection(),
                    const SizedBox(height: 12),
                    _buildStyleSection(),
                    const SizedBox(height: 12),
                    _buildBoxSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _applyAndBack,
                  child: const Text('添加文字'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(double previewWidth) {
    final previewHeight = previewWidth / _previewAspectRatio;
    final layerSize = measurePostcardLayerSize(
      _layer,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );
    final left = previewWidth / 2 - layerSize.width / 2;
    final top = previewHeight / 2 - layerSize.height / 2;

    return SizedBox(
      width: previewWidth,
      height: previewHeight,
      child: ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: layerSize.width,
              height: layerSize.height,
              child: Transform.rotate(
                angle: _layer.rotation2d,
                child: buildPostcardLayerVisual(
                  _layer,
                  previewWidth: previewWidth,
                  previewHeight: previewHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextSection() {
    return _ConfigCard(
      title: '文字内容',
      child: TextField(
        controller: _textController,
        minLines: 1,
        maxLines: 3,
        maxLength: 40,
        decoration: const InputDecoration(
          hintText: '请输入明信片文字',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildTransformSection() {
    final rotationDeg = (_layer.rotation2d * 180 / math.pi).clamp(
      -180.0,
      180.0,
    );

    return _ConfigCard(
      title: '变换',
      child: Column(
        children: [
          _buildSliderTile(
            label: '缩放',
            value: _layer.scale.clamp(0.5, 2.5).toDouble(),
            min: 0.5,
            max: 2.5,
            divisions: 40,
            formatter: (value) => value.toStringAsFixed(2),
            onChanged: (value) =>
                _updateLayer((layer) => layer.copyWith(scale: value)),
          ),
          _buildSliderTile(
            label: '旋转',
            value: rotationDeg.toDouble(),
            min: -180,
            max: 180,
            divisions: 360,
            formatter: (value) => '${value.round()}°',
            onChanged: (value) {
              final radians = value * math.pi / 180;
              _updateLayer((layer) => layer.copyWith(rotation2d: radians));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSection() {
    return _ConfigCard(
      title: '文字样式',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdownTile(
            label: '对齐',
            value: _alignValue,
            options: _alignOptions,
            displayText: _displayAlignLabel,
            onChanged: (value) =>
                _updateStyle((style) => style.copyWith(align: value)),
          ),
          const SizedBox(height: 10),
          _buildSliderTile(
            label: 'fontWeight',
            value: _fontWeightNumber,
            min: 100,
            max: 900,
            divisions: 8,
            formatter: (value) => value.round().toString(),
            onChanged: (value) => _updateStyle(
              (style) => style.copyWith(fontWeight: value.round().toString()),
            ),
          ),
          _buildSliderTile(
            label: '字号',
            value: _style.fontSize.clamp(12.0, 56.0).toDouble(),
            min: 12,
            max: 56,
            divisions: 44,
            formatter: (value) => value.round().toString(),
            onChanged: (value) =>
                _updateStyle((style) => style.copyWith(fontSize: value)),
          ),
          _buildSliderTile(
            label: '行高',
            value: _style.lineHeight.clamp(1.0, 2.4).toDouble(),
            min: 1,
            max: 2.4,
            divisions: 28,
            formatter: (value) => value.toStringAsFixed(2),
            onChanged: (value) =>
                _updateStyle((style) => style.copyWith(lineHeight: value)),
          ),
          _buildSliderTile(
            label: '字间距',
            value: _style.letterSpacing.clamp(0.0, 8.0).toDouble(),
            min: 0,
            max: 8,
            divisions: 40,
            formatter: (value) => value.toStringAsFixed(1),
            onChanged: (value) =>
                _updateStyle((style) => style.copyWith(letterSpacing: value)),
          ),
          const SizedBox(height: 6),
          const Text(
            '颜色',
            style: TextStyle(fontSize: 12, color: Color(0xFF5B7562)),
          ),
          const SizedBox(height: 6),
          _buildColorChoices(
            values: _textColors,
            selected: _style.color,
            onSelected: (value) =>
                _updateStyle((style) => style.copyWith(color: value)),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxSection() {
    final currentMaxWidth = (_box.maxWidth ?? 300).clamp(120.0, 360.0);

    return _ConfigCard(
      title: '文字框',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSliderTile(
            label: '最大宽度',
            value: currentMaxWidth.toDouble(),
            min: 120,
            max: 360,
            divisions: 48,
            formatter: (value) => value.round().toString(),
            onChanged: (value) =>
                _updateBox((box) => box.copyWith(maxWidth: value)),
          ),
          _buildSliderTile(
            label: '内边距',
            value: _box.padding.clamp(0.0, 24.0).toDouble(),
            min: 0,
            max: 24,
            divisions: 24,
            formatter: (value) => value.round().toString(),
            onChanged: (value) =>
                _updateBox((box) => box.copyWith(padding: value)),
          ),
          _buildSliderTile(
            label: '圆角',
            value: _box.borderRadius.clamp(0.0, 32.0).toDouble(),
            min: 0,
            max: 32,
            divisions: 32,
            formatter: (value) => value.round().toString(),
            onChanged: (value) =>
                _updateBox((box) => box.copyWith(borderRadius: value)),
          ),
          const SizedBox(height: 6),
          const Text(
            '背景色',
            style: TextStyle(fontSize: 12, color: Color(0xFF5B7562)),
          ),
          const SizedBox(height: 6),
          _buildColorChoices(
            values: _boxColors,
            selected: _box.backgroundColor ?? 'rgba(0,0,0,0.25)',
            onSelected: (value) =>
                _updateBox((box) => box.copyWith(backgroundColor: value)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    String Function(String value)? displayText,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: options.contains(value) ? value : options.first,
          items: options
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(displayText?.call(item) ?? item),
                ),
              )
              .toList(growable: false),
          onChanged: (next) {
            if (next == null) return;
            onChanged(next);
          },
        ),
      ),
    );
  }

  Widget _buildColorChoices({
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map((value) {
            final isSelected =
                selected.trim().toLowerCase() == value.trim().toLowerCase();
            final color = parseFlexibleColor(value, Colors.transparent);
            final isTransparent = color.a < 0.01;
            return GestureDetector(
              onTap: () => onSelected(value),
              child: Container(
                width: 36,
                height: 24,
                decoration: BoxDecoration(
                  color: isTransparent ? Colors.white : color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2F663A)
                        : const Color(0xFFB8D3AB),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: isTransparent
                    ? const Text(
                        'T',
                        style: TextStyle(
                          color: Color(0xFF5B7562),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String Function(double) formatter,
    int? divisions,
  }) {
    final safeValue = value.clamp(min, max).toDouble();
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2D5D35),
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              formatter(safeValue),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5B7562),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Slider(
          value: safeValue,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ConfigCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7E7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFAED0AE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D5D35),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
