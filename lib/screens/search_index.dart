// search_index_screen.dart
import 'package:flutter/material.dart';
// 导入添加元素页面
import 'add_screen.dart';

class SearchIndexScreen extends StatefulWidget {
  const SearchIndexScreen({Key? key}) : super(key: key);

  @override
  State<SearchIndexScreen> createState() => _SearchIndexScreenState();
}

class _SearchIndexScreenState extends State<SearchIndexScreen> {
  // 搜索框控制器
  final TextEditingController _searchController = TextEditingController();

  // 搜索关键词
  String _searchKeyword = '';

  // 分类数据
  final List<Map<String, dynamic>> _categories = [
    {'name': '马年元素', 'icon': 'assets/images/搜索元素/马年元素.png'},
    {'name': '新年元素', 'icon': 'assets/images/搜索元素/新年元素.png'},
    {'name': '季节元素', 'icon': 'assets/images/搜索元素/季节元素.png'},
  ];

  // 每个分类下的具体元素
  final Map<String, List<Map<String, dynamic>>> _elementsByCategory = {
    '马年元素': [
      {'name': '马踏飞燕', 'icon': 'assets/images/添加元素/马踏飞燕.png'},
      {'name': '骏马', 'icon': 'assets/images/添加元素/骏马.png'},
      {'name': '马鞍', 'icon': 'assets/images/添加元素/马鞍.png'},
      {'name': '马蹄', 'icon': 'assets/images/添加元素/马蹄.png'},
    ],
    '新年元素': [
      {'name': '烟花', 'icon': 'assets/images/添加元素/烟花.png'},
      {'name': '灯笼', 'icon': 'assets/images/添加元素/灯笼.png'},
      {'name': '春联', 'icon': 'assets/images/添加元素/春联.png'},
      {'name': '鞭炮', 'icon': 'assets/images/添加元素/鞭炮.png'},
    ],
    '季节元素': [
      {'name': '梅花', 'icon': 'assets/images/添加元素/梅花.png'},
      {'name': '雪花', 'icon': 'assets/images/添加元素/雪花.png'},
      {'name': '绿叶', 'icon': 'assets/images/添加元素/绿叶.png'},
      {'name': '枫叶', 'icon': 'assets/images/添加元素/枫叶.png'},
    ],
  };

  // 常用元素（合并所有分类的前几个元素）
  final List<Map<String, dynamic>> _commonElements = [
    {'name': '烟花', 'icon': 'assets/images/添加元素/烟花.png'},
    {'name': '马踏飞燕', 'icon': 'assets/images/添加元素/马踏飞燕.png'},
    {'name': '骏马', 'icon': 'assets/images/添加元素/骏马.png'},
    {'name': '灯笼', 'icon': 'assets/images/添加元素/灯笼.png'},
  ];

  // 热门元素
  final List<Map<String, dynamic>> _hotElements = [
    {'name': '烟花', 'icon': 'assets/images/添加元素/烟花.png'},
    {'name': '梅花', 'icon': 'assets/images/添加元素/梅花.png'},
    {'name': '骏马', 'icon': 'assets/images/添加元素/骏马.png'},
    {'name': '雪花', 'icon': 'assets/images/添加元素/雪花.png'},
  ];

  // 热搜元素
  final List<Map<String, dynamic>> _hotSearchElements = [
    {'name': '烟花', 'icon': 'assets/images/添加元素/烟花.png'},
    {'name': '马踏飞燕', 'icon': 'assets/images/添加元素/马踏飞燕.png'},
    {'name': '骏马', 'icon': 'assets/images/添加元素/骏马.png'},
    {'name': '梅花', 'icon': 'assets/images/添加元素/梅花.png'},
    {'name': '雪花', 'icon': 'assets/images/添加元素/雪花.png'},
    {'name': '绿叶', 'icon': 'assets/images/添加元素/绿叶.png'},
    {'name': '枫叶', 'icon': 'assets/images/添加元素/枫叶.png'},
    {'name': '灯笼', 'icon': 'assets/images/添加元素/灯笼.png'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 过滤元素列表（根据搜索关键词）
  List<Map<String, dynamic>> _filterElements(
    List<Map<String, dynamic>> elements,
  ) {
    if (_searchKeyword.isEmpty) {
      return elements;
    }
    return elements.where((element) {
      String name = element['name'] as String;
      return name.contains(_searchKeyword);
    }).toList();
  }

  // 点击元素项，返回添加元素页并传递选中的元素
  void _onElementTap(Map<String, dynamic> element) {
    String elementName = element['name'];

    // 返回上一页并传递选中的元素数据
    Navigator.pop(context, {'name': elementName, 'icon': element['icon']});

    // 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Image.asset(
              'assets/images/添加元素/应用.png',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text('已选择: $elementName'),
          ],
        ),
        duration: const Duration(milliseconds: 800),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 构建顶部栏
  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Image.asset(
              'assets/images/搜索元素/返回.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(width: 12),

          // 标题"元素搜索" - 使用素材库图片
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/搜索元素/元素搜索.png',
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 占位，保持标题居中
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  // 构建搜索框
  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            // 搜索图标
            Image.asset(
              'assets/images/搜索元素/搜索.png',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            // 搜索输入框
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchKeyword = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: '搜索',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            // 清除按钮（当有输入时显示）
            if (_searchKeyword.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searchController.clear();
                    _searchKeyword = '';
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Image.asset(
                    'assets/images/搜索元素/删除.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 构建通用模块（常用、热门、热搜）
  Widget _buildModule({
    required String title,
    required List<Map<String, dynamic>> elements,
    required String moduleIcon,
  }) {
    // 过滤元素
    List<Map<String, dynamic>> filteredElements = _filterElements(elements);

    // 如果没有匹配的元素，不显示该模块
    if (filteredElements.isEmpty && _searchKeyword.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 模块标题行
          Row(
            children: [
              // 模块图标
              Image.asset(
                'assets/images/搜索元素/$moduleIcon.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              // 模块标题
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 元素网格
          filteredElements.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '暂无相关元素',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: filteredElements.length,
                  itemBuilder: (context, index) {
                    return _buildElementItem(filteredElements[index]);
                  },
                ),
        ],
      ),
    );
  }

  // 构建分类模块
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分类标题
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 8, bottom: 12),
          child: Text(
            '分类',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        // 分类卡片
        ..._categories.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> category = entry.value;
          return _buildCategoryCard(category, index);
        }).toList(),
      ],
    );
  }

  // 构建分类卡片
  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    String categoryName = category['name'];
    List<Map<String, dynamic>> categoryElements =
        _elementsByCategory[categoryName] ?? [];

    // 过滤元素
    List<Map<String, dynamic>> filteredElements = _filterElements(
      categoryElements,
    );

    // 如果没有匹配的元素且正在搜索，不显示该分类
    if (filteredElements.isEmpty && _searchKeyword.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类标题行
          Row(
            children: [
              // 分类图标
              Image.asset(
                category['icon'],
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              // 分类名称
              Image.asset(
                'assets/images/搜索元素/$categoryName.png',
                height: 22,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 元素网格
          filteredElements.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '暂无相关元素',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: filteredElements.length,
                  itemBuilder: (context, index) {
                    return _buildElementItem(filteredElements[index]);
                  },
                ),
        ],
      ),
    );
  }

  // 构建元素项
  Widget _buildElementItem(Map<String, dynamic> element) {
    String elementName = element['name'];

    return GestureDetector(
      onTap: () {
        // 点击元素，返回添加元素页并传递数据
        _onElementTap(element);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 元素图标
            Image.asset(
              element['icon'],
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.image, size: 20, color: Colors.grey[400]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            _buildTopBar(),

            // 搜索框
            _buildSearchBox(),

            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 常用模块
                    _buildModule(
                      title: '常用',
                      elements: _commonElements,
                      moduleIcon: '常用',
                    ),

                    // 热门模块
                    _buildModule(
                      title: '热门',
                      elements: _hotElements,
                      moduleIcon: '热门',
                    ),

                    // 热搜模块
                    _buildModule(
                      title: '热搜',
                      elements: _hotSearchElements,
                      moduleIcon: '热搜',
                    ),

                    // 分类模块
                    _buildCategorySection(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
