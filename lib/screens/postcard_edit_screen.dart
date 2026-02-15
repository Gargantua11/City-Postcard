import 'package:flutter/material.dart';
import '../services/edited_postcard_service.dart';

class PostcardEditScreen extends StatefulWidget {
  const PostcardEditScreen({super.key});

  @override
  State<PostcardEditScreen> createState() => _PostcardEditScreenState();
}

class _PostcardEditScreenState extends State<PostcardEditScreen> {
  static const String _defaultPreviewAsset = 'assets/images/编辑-开始定制.png';

  final EditedPostcardService _editedPostcardService = EditedPostcardService();
  bool _isSaving = false;

  Future<void> _savePostcard() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    await _editedPostcardService.addEditedPostcard(_defaultPreviewAsset);

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context, true);
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
    _showHint([title, '功能开发中'].join(' '));
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
                            assetPath: 'assets/images/编辑-返回.png',
                            width: topButtonWidth,
                            height: topButtonHeight,
                            onTap: _undo,
                          ),
                          _AssetTapButton(
                            assetPath: 'assets/images/编辑-分享.png',
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
                                assetPath: 'assets/images/编辑-添加元素.png',
                                width: actionWidth,
                                height: actionHeight,
                                onTap: () => _onActionTap('添加元素'),
                              ),
                              SizedBox(height: 14 * scale),
                              _AssetTapButton(
                                assetPath: 'assets/images/编辑-动态效果.png',
                                width: actionWidth,
                                height: actionHeight,
                                onTap: () => _onActionTap('动态效果'),
                              ),
                              SizedBox(height: 14 * scale),
                              _AssetTapButton(
                                assetPath: 'assets/images/编辑-地点标注.png',
                                width: actionWidth,
                                height: actionHeight,
                                onTap: () => _onActionTap('地点标注'),
                              ),
                            ],
                          ),
                          SizedBox(width: actionGap),
                          _AssetTapButton(
                            assetPath: 'assets/images/编辑-热门模板.png',
                            width: actionWidth,
                            height: templateHeight,
                            onTap: () => _onActionTap('热门模板'),
                          ),
                        ],
                      ),
                      SizedBox(height: 44 * scale),
                      _AssetTapButton(
                        assetPath: 'assets/images/编辑-保存.png',
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
