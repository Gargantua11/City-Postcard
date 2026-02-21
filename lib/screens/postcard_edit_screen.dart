import 'package:flutter/material.dart';

import '../data/city_code_center.dart';
import '../services/edited_postcard_service.dart';
import 'city_search_screen.dart';

class PostcardEditScreen extends StatefulWidget {
  const PostcardEditScreen({super.key});

  @override
  State<PostcardEditScreen> createState() => _PostcardEditScreenState();
}

class _PostcardEditScreenState extends State<PostcardEditScreen> {
  static const String _defaultPreviewAsset = 'assets/images/edit/编辑-开始定制.png';

  final EditedPostcardService _editedPostcardService = EditedPostcardService();
  City? _selectedCity;
  bool _isSaving = false;

  Future<void> _savePostcard() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final cityCode = _normalizeCityCode(_selectedCity?.code);
    final cityName = _selectedCity?.name.trim();
    final provinceName = _resolveProvinceNameFromCityCode(cityCode);
    final coordinate = cityCode == null ? null : kCityCodeCoordinates[cityCode];

    await _editedPostcardService.addEditedPostcard(
      _defaultPreviewAsset,
      cityName: (cityName == null || cityName.isEmpty) ? null : cityName,
      cityCode: cityCode,
      provinceName: provinceName,
      latitude: coordinate?.latitude,
      longitude: coordinate?.longitude,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (cityName != null && cityName.isNotEmpty) {
      _showHint('已保存并标注：$cityName');
    }
    Navigator.pop(context, true);
  }

  Future<void> _selectLocationTag() async {
    if (_isSaving) return;

    final selectedCity = await Navigator.push<City>(
      context,
      MaterialPageRoute(
        builder: (context) => CitySearchScreen(selectedCity: _selectedCity?.name),
      ),
    );

    if (!mounted || selectedCity == null) return;
    setState(() => _selectedCity = selectedCity);
    _showHint('已标注地点：${selectedCity.name}');
  }

  String? _normalizeCityCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return digits;
  }

  String? _resolveProvinceNameFromCityCode(String? cityCode) {
    if (cityCode == null || cityCode.length < 2) return null;
    return _provinceNameByPrefix[cityCode.substring(0, 2)];
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _undo() {
    _showHint('已撤销到上一步状态');
  }

  void _share() {
    _showHint('分享功能开发中');
  }

  void _onActionTap(String title) {
    _showHint('$title 功能开发中');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double designWidth = 400;
            const double designHeight = 770;
            final double availableWidth = constraints.maxWidth - 40;
            final double availableHeight = constraints.maxHeight;

            double widthScale = availableWidth / designWidth;
            double heightScale = availableHeight / designHeight;
            double scale = widthScale < heightScale ? widthScale : heightScale;
            if (scale > 1.0) scale = 1.0;
            if (scale < 0.72) scale = 0.72;

            final double contentWidth = designWidth * scale;
            final double topButtonWidth = 94 * scale;
            final double topButtonHeight = 41 * scale;
            final double previewHeight = 258 * scale;
            final double actionWidth = 166 * scale;
            final double actionHeight = 50 * scale;
            final double templateHeight = 180 * scale;
            final double saveWidth = 353 * scale;
            final double saveHeight = 87 * scale;
            double actionGap = contentWidth - actionWidth * 2;
            if (actionGap < 14 * scale) actionGap = 14 * scale;
            if (actionGap > 40 * scale) actionGap = 40 * scale;

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 24 * scale, 0, 26 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '城市明信片 · 编辑',
                        style: TextStyle(
                          fontSize: 22 * scale,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 18 * scale),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _AssetTapButton(
                            assetPath: 'assets/images/edit/编辑-返回.png',
                            width: topButtonWidth,
                            height: topButtonHeight,
                            onTap: _undo,
                          ),
                          _AssetTapButton(
                            assetPath: 'assets/images/edit/编辑-分享.png',
                            width: topButtonWidth,
                            height: topButtonHeight,
                            onTap: _share,
                          ),
                        ],
                      ),
                      SizedBox(height: 24 * scale),
                      _AssetTapButton(
                        assetPath: _defaultPreviewAsset,
                        width: contentWidth,
                        height: previewHeight,
                        onTap: () => _onActionTap('开始定制'),
                      ),
                      SizedBox(height: 30 * scale),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              _AssetTapButton(
                                assetPath: 'assets/images/edit/编辑-添加元素.png',
                                width: actionWidth,
                                height: actionHeight,
                                onTap: () => Navigator.pushNamed(context, '/add'),
                              ),
                              SizedBox(height: 14 * scale),
                              _AssetTapButton(
                                assetPath: 'assets/images/edit/编辑-动态效果.png',
                                width: actionWidth,
                                height: actionHeight,
                                onTap: () => _onActionTap('动态效果'),
                              ),
                              SizedBox(height: 14 * scale),
                              _AssetTapButton(
                                assetPath: 'assets/images/edit/编辑-地点标注.png',
                                width: actionWidth,
                                height: actionHeight,
                                onTap: _selectLocationTag,
                              ),
                            ],
                          ),
                          SizedBox(width: actionGap),
                          _AssetTapButton(
                            assetPath: 'assets/images/edit/编辑-热门模板.png',
                            width: actionWidth,
                            height: templateHeight,
                            onTap: () => _onActionTap('热门模板'),
                          ),
                        ],
                      ),
                      SizedBox(height: 14 * scale),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _selectedCity == null
                              ? '未标注地点'
                              : '已标注地点：${_selectedCity!.name} (${_selectedCity!.code})',
                          style: TextStyle(
                            fontSize: 13 * scale,
                            color: const Color(0xFF3F4E63),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: 30 * scale),
                      _AssetTapButton(
                        assetPath: 'assets/images/edit/编辑-保存.png',
                        width: saveWidth,
                        height: saveHeight,
                        onTap: _isSaving ? null : _savePostcard,
                        child: _isSaving
                            ? const Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

const Map<String, String> _provinceNameByPrefix = {
  '11': '北京',
  '12': '天津',
  '13': '河北',
  '14': '山西',
  '15': '内蒙古',
  '21': '辽宁',
  '22': '吉林',
  '23': '黑龙江',
  '31': '上海',
  '32': '江苏',
  '33': '浙江',
  '34': '安徽',
  '35': '福建',
  '36': '江西',
  '37': '山东',
  '41': '河南',
  '42': '湖北',
  '43': '湖南',
  '44': '广东',
  '45': '广西',
  '46': '海南',
  '50': '重庆',
  '51': '四川',
  '52': '贵州',
  '53': '云南',
  '54': '西藏',
  '61': '陕西',
  '62': '甘肃',
  '63': '青海',
  '64': '宁夏',
  '65': '新疆',
  '71': '台湾',
  '81': '香港',
  '82': '澳门',
};

class _AssetTapButton extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final Widget? child;

  const _AssetTapButton({
    required this.assetPath,
    required this.width,
    required this.height,
    this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
            if (child case final Widget overlay) overlay,
          ],
        ),
      ),
    );
  }
}
