import 'package:flutter/material.dart';

import '../models/postcard_element_layer.dart';

class AddIndexPage extends StatefulWidget {
  const AddIndexPage({super.key});

  @override
  State<AddIndexPage> createState() => _AddIndexPageState();
}

class _AddIndexPageState extends State<AddIndexPage> {
  static const double _newElementScale = 2 / 3;

  final List<_CategoryData> _categories = const [
    _CategoryData(name: '马年元素'),
    _CategoryData(name: '新年元素'),
    _CategoryData(name: '季节元素'),
  ];

  final Map<String, List<_ElementData>> _elementsByCategory = const {
    '马年元素': [
      _ElementData(
        name: '马踏飞燕',
        iconPath: 'assets/images/add_elements/马踏飞燕.png',
      ),
      _ElementData(name: '骏马', iconPath: 'assets/images/add_elements/骏马.png'),
      _ElementData(name: '马鞍', iconPath: 'assets/images/add_elements/马鞍.png'),
      _ElementData(name: '马蹄', iconPath: 'assets/images/add_elements/马蹄.png'),
    ],
    '新年元素': [
      _ElementData(name: '烟花', iconPath: 'assets/images/add_elements/烟花.png'),
      _ElementData(name: '灯笼', iconPath: 'assets/images/add_elements/灯笼.png'),
      _ElementData(name: '春联', iconPath: 'assets/images/add_elements/春联.png'),
      _ElementData(name: '鞭炮', iconPath: 'assets/images/add_elements/鞭炮.png'),
    ],
    '季节元素': [
      _ElementData(name: '梅花', iconPath: 'assets/images/add_elements/梅花.png'),
      _ElementData(name: '雪花', iconPath: 'assets/images/add_elements/雪花.png'),
      _ElementData(name: '绿叶', iconPath: 'assets/images/add_elements/绿叶.png'),
      _ElementData(name: '枫叶', iconPath: 'assets/images/add_elements/枫叶.png'),
    ],
  };

  final List<PostcardElementLayer> _addedLayers = <PostcardElementLayer>[];
  int _layerSequence = 0;

  Map<String, int> get _selectedCounts {
    final map = <String, int>{};
    for (final layer in _addedLayers) {
      map[layer.elementKey] = (map[layer.elementKey] ?? 0) + 1;
    }
    return map;
  }

  String _createLayerId() {
    _layerSequence += 1;
    return 'layer_${DateTime.now().microsecondsSinceEpoch}_$_layerSequence';
  }

  Offset _defaultLayerOffset(int index) {
    const perRow = 4;
    final col = index % perRow;
    final row = index ~/ perRow;
    final dx = (col - 1.5) * 42.0;
    final dy = ((row % 3) - 1) * 34.0;
    return Offset(dx, dy);
  }

  int _countElementInstances(String elementName) {
    var count = 0;
    for (final layer in _addedLayers) {
      if (layer.elementKey == elementName) {
        count += 1;
      }
    }
    return count;
  }

  void _addElement(String elementName, {required String iconPath}) {
    final normalizedName = elementName.trim();
    if (normalizedName.isEmpty) return;

    setState(() {
      final offset = _defaultLayerOffset(_addedLayers.length);
      _addedLayers.add(
        PostcardElementLayer(
          id: _createLayerId(),
          elementKey: normalizedName,
          assetPath: iconPath,
          scale: _newElementScale,
          x: offset.dx,
          y: offset.dy,
          zIndex: _addedLayers.length,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 $normalizedName'),
        duration: const Duration(milliseconds: 700),
      ),
    );
  }

  void _removeOneElement(String elementName) {
    setState(() {
      final index = _addedLayers.lastIndexWhere(
        (layer) => layer.elementKey == elementName,
      );
      if (index >= 0) {
        _addedLayers.removeAt(index);
      }
    });
  }

  Future<void> _confirmDeleteAll() async {
    if (_addedLayers.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定清空已选元素吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _addedLayers.clear());
  }

  void _applyAndReturn() {
    Navigator.pop(context, List<PostcardElementLayer>.from(_addedLayers));
  }

  Future<void> _goBack() async {
    if (_addedLayers.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('返回编辑页'),
          content: const Text('当前已选择元素，直接返回将丢失未应用的修改，确定返回吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('返回'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _goToSearchPage() async {
    final allElements = _elementsByCategory.values
        .expand((elements) => elements)
        .toList(growable: false);
    final uniqueElements = <_ElementData>[];
    final seen = <String>{};
    for (final element in allElements) {
      if (seen.add(element.name)) {
        uniqueElements.add(element);
      }
    }

    final selected = await showSearch<_ElementData?>(
      context: context,
      delegate: _ElementSearchDelegate(elements: uniqueElements),
    );
    if (!mounted || selected == null) return;
    _addElement(selected.name, iconPath: selected.iconPath);
  }

  Future<void> _openCategorySheet(_CategoryData category) async {
    final elements =
        _elementsByCategory[category.name] ?? const <_ElementData>[];
    if (elements.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.62,
          decoration: const BoxDecoration(
            color: Color(0xFFE9F4DE),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFA7C398),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: elements.length,
                  itemBuilder: (context, index) {
                    final element = elements[index];
                    final count = _countElementInstances(element.name);
                    return _ElementTile(
                      element: element,
                      count: count,
                      onTap: () {
                        _addElement(element.name, iconPath: element.iconPath);
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCounts = _selectedCounts;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(onBack: _goBack),
                    const SizedBox(height: 16),
                    _SearchBar(onTap: _goToSearchPage),
                    const SizedBox(height: 18),
                    for (var i = 0; i < _categories.length; i++) ...[
                      _CategoryPanel(
                        category: _categories[i],
                        elements:
                            _elementsByCategory[_categories[i].name] ??
                            const <_ElementData>[],
                        onOpenCategory: () =>
                            _openCategorySheet(_categories[i]),
                        onTapElement: (element) {
                          _addElement(element.name, iconPath: element.iconPath);
                        },
                      ),
                      if (i != _categories.length - 1)
                        const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SelectedPanel(
                    selectedCounts: selectedCounts,
                    onTapItem: _removeOneElement,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BottomButton(
                          label: '应用',
                          onTap: _applyAndReturn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BottomButton(
                          label: '删除',
                          onTap: _confirmDeleteAll,
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
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 74,
            height: 34,
            child: Image.asset(
              'assets/images/add_elements/返回.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.arrow_back_ios_new_rounded, size: 18);
              },
            ),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              '元素库',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 74),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFDDF1D0),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFA5C39A)),
        ),
        child: const Row(
          children: [
            Text(
              '搜索',
              style: TextStyle(color: Color(0xFF5C7558), fontSize: 18),
            ),
            Spacer(),
            Icon(Icons.search_rounded, size: 22),
          ],
        ),
      ),
    );
  }
}

class _CategoryPanel extends StatefulWidget {
  final _CategoryData category;
  final List<_ElementData> elements;
  final VoidCallback onOpenCategory;
  final ValueChanged<_ElementData> onTapElement;

  const _CategoryPanel({
    required this.category,
    required this.elements,
    required this.onOpenCategory,
    required this.onTapElement,
  });

  @override
  State<_CategoryPanel> createState() => _CategoryPanelState();
}

class _CategoryPanelState extends State<_CategoryPanel> {
  static const int _collapsedVisibleCount = 3;
  bool _expanded = false;

  bool get _canExpand => widget.elements.length > _collapsedVisibleCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF1D0),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFA5C39A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onOpenCategory,
            child: _CategoryTitlePillar(title: widget.category.name),
          ),
          const SizedBox(height: 10),
          const Text(
            '下方展示部分元素，点击元素可快速添加',
            style: TextStyle(fontSize: 12, color: Color(0xFF4C654A)),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _canExpand
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: _expanded ? 420 : 132),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: widget.elements
                        .map((element) {
                          return _CategoryPreviewTile(
                            element: element,
                            onTap: () => widget.onTapElement(element),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
          ),
          if (_canExpand) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3E5B3B),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: Text(_expanded ? '收起' : '展开'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryTitlePillar extends StatelessWidget {
  final String title;

  const _CategoryTitlePillar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1F2A1E),
      ),
    );
  }
}

class _CategoryPreviewTile extends StatelessWidget {
  final _ElementData element;
  final VoidCallback onTap;

  const _CategoryPreviewTile({required this.element, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 88,
        height: 132,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F6DD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB8D3AB)),
        ),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Column(
          children: [
            Text(
              element.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Image.asset(
                element.iconPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.image_not_supported_outlined,
                    size: 18,
                    color: Color(0xFF8BA081),
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

class _ElementTile extends StatelessWidget {
  final _ElementData element;
  final int count;
  final VoidCallback onTap;

  const _ElementTile({
    required this.element,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4FAEF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: count > 0
                ? const Color(0xFF5E9A66)
                : const Color(0xFFBFD6B4),
            width: count > 0 ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                child: Column(
                  children: [
                    Expanded(
                      child: Image.asset(
                        element.iconPath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported_outlined,
                            size: 24,
                            color: Color(0xFF93A48F),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      element.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF5E9A66),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedPanel extends StatelessWidget {
  final Map<String, int> selectedCounts;
  final ValueChanged<String> onTapItem;

  const _SelectedPanel({required this.selectedCounts, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF1D0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA5C39A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '已选元素：',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (selectedCounts.isEmpty)
            const Text(
              '暂无已选元素',
              style: TextStyle(fontSize: 12, color: Color(0xFF5A7356)),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: selectedCounts.entries
                  .map((entry) {
                    return GestureDetector(
                      onTap: () => onTapItem(entry.key),
                      child: Text(
                        '${entry.key} * ${entry.value}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BottomButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFD9EDCC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF9DBB90)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ElementSearchDelegate extends SearchDelegate<_ElementData?> {
  static const Color _themeColor = Color(0xFFCBE6BB);

  final List<_ElementData> elements;

  _ElementSearchDelegate({required this.elements});

  List<_ElementData> _filtered() {
    final keyword = query.trim();
    if (keyword.isEmpty) return elements;
    return elements
        .where((element) => element.name.contains(keyword))
        .toList(growable: false);
  }

  @override
  String get searchFieldLabel => '搜索现有元素';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: _themeColor,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: _themeColor,
        surfaceTintColor: _themeColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2E3A2F)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFE6F2DE),
        hintStyle: TextStyle(color: Color(0xFF6C786E)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: '清空',
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: '返回',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildResultList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildResultList(context);
  }

  Widget _buildResultList(BuildContext context) {
    final results = _filtered();
    if (results.isEmpty) {
      return const ColoredBox(
        color: _themeColor,
        child: Center(
          child: Text(
            '未找到相关元素',
            style: TextStyle(fontSize: 16, color: Color(0xFF6F7B88)),
          ),
        ),
      );
    }
    return ColoredBox(
      color: _themeColor,
      child: ListView.separated(
        itemCount: results.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: Color(0xFFC3D8B5)),
        itemBuilder: (context, index) {
          final element = results[index];
          return ListTile(
            tileColor: _themeColor,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                element.iconPath,
                width: 34,
                height: 34,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.image_not_supported_outlined,
                    size: 22,
                    color: Color(0xFF9AA3A2),
                  );
                },
              ),
            ),
            title: Text(
              element.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF4F8A73),
            ),
            onTap: () => close(context, element),
          );
        },
      ),
    );
  }
}

class _CategoryData {
  final String name;

  const _CategoryData({required this.name});
}

class _ElementData {
  final String name;
  final String iconPath;

  const _ElementData({required this.name, required this.iconPath});
}
