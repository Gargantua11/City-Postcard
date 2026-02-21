import 'package:flutter/material.dart';
// 导入搜索页面
import 'search_index.dart';
// 导入编辑页面
import 'postcard_edit_screen.dart';

class AddIndexPage extends StatefulWidget {
  const AddIndexPage({Key? key}) : super(key: key);

  @override
  State<AddIndexPage> createState() => _AddIndexPageState();
}

class _AddIndexPageState extends State<AddIndexPage> {
  // 已选元素列表
  List<Map<String, dynamic>> selectedElements = [
    {'name': '烟花', 'count': 2},
    {'name': '马踏飞燕', 'count': 1},
  ];

  // 分类数据 - 按图片顺序：马年元素、新年元素、季节元素
  final List<Map<String, dynamic>> categories = [
    {'name': '马年元素', 'icon': 'assets/images/添加元素/马年元素.png'},
    {'name': '新年元素', 'icon': 'assets/images/添加元素/新年元素.png'},
    {'name': '季节元素', 'icon': 'assets/images/添加元素/季节元素.png'},
  ];

  // 每个分类下的具体元素
  final Map<String, List<Map<String, dynamic>>> elementsByCategory = {
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

  // 当前选中的元素
  Map<String, int> addedElements = {'烟花': 2, '马踏飞燕': 1};

  @override
  void dispose() {
    super.dispose();
  }

  // 添加元素 - 点击直接添加
  void addElement(String elementName) {
    setState(() {
      if (addedElements.containsKey(elementName)) {
        addedElements[elementName] = addedElements[elementName]! + 1;
      } else {
        addedElements[elementName] = 1;
      }
      updateSelectedElementsList();

      // 添加成功提示
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
              Text('已添加 $elementName'),
            ],
          ),
          duration: const Duration(milliseconds: 800),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  // 移除单个元素的一个数量
  void removeElement(String elementName) {
    setState(() {
      if (addedElements.containsKey(elementName)) {
        if (addedElements[elementName]! > 1) {
          addedElements[elementName] = addedElements[elementName]! - 1;
        } else {
          addedElements.remove(elementName);
        }
        updateSelectedElementsList();
      }
    });
  }

  // 删除所有已选元素
  void deleteAllElements() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Image.asset(
                'assets/images/添加元素/删除.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Text('确认删除'),
            ],
          ),
          content: const Text('确定要清空所有已选元素吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  addedElements.clear();
                  selectedElements.clear();
                });
                Navigator.pop(context);

                // 删除成功提示
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Image.asset(
                          'assets/images/添加元素/删除.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        const Text('已清空所有元素'),
                      ],
                    ),
                    duration: const Duration(milliseconds: 800),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 更新已选元素列表
  void updateSelectedElementsList() {
    selectedElements.clear();
    addedElements.forEach((key, value) {
      selectedElements.add({'name': key, 'count': value});
    });
  }

  // 应用并返回编辑页
  void applyAndReturn() {
    print('应用的元素: $addedElements');

    // 显示应用成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Image.asset(
              'assets/images/添加元素/应用.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text('应用成功，返回编辑页'),
          ],
        ),
        duration: const Duration(milliseconds: 1000),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );

    // 延迟返回编辑页
    Future.delayed(const Duration(milliseconds: 800), () {
      Navigator.pop(context);
    });
  }

  // 返回编辑页
  void goBackToEditPage() {
    // 如果有已选元素，可以选择提示用户是否保存
    if (addedElements.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Image.asset(
                  'assets/images/添加元素/返回.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                const Text('返回编辑页'),
              ],
            ),
            content: const Text('当前已选择了元素，返回后将丢失未应用的更改，确定要返回吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 关闭对话框
                  Navigator.pop(context); // 返回编辑页
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    } else {
      // 没有已选元素，直接返回
      Navigator.pop(context);
    }
  }

  // 跳转到搜索页面
  void goToSearchPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchIndexScreen()),
    ).then((result) {
      // 从搜索页面返回后，如果有返回的数据（如选中的元素），可以在这里处理
      if (result != null && result is Map<String, dynamic>) {
        String elementName = result['name'];
        addElement(elementName);

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
                Text('从搜索结果添加: $elementName'),
              ],
            ),
            duration: const Duration(milliseconds: 800),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部区域
            _buildTopBar(),

            // 搜索框
            _buildSearchBox(),

            // 分类区域 - 垂直排列，不滚动
            _buildCategorySection(),

            // 已选元素区域
            _buildSelectedElementsSection(),

            // 底部按钮
            _buildBottomButtons(),
          ],
        ),
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
          // 返回按钮 - 使用素材库图片，点击返回编辑页
          GestureDetector(
            onTap: goBackToEditPage,
            child: Image.asset(
              'assets/images/添加元素/返回.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(width: 12),

          // 标题"元素库" - 使用素材库图片
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/添加元素/元素库.png',
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

  // 构建搜索框 - 点击跳转到搜索页面
  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: goToSearchPage,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              // 搜索图标 - 使用素材库图片
              Image.asset(
                'assets/images/添加元素/搜索.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              // 搜索提示文字
              const Text(
                '搜索',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // 构建分类区域 - 垂直排列，不滚动
  Widget _buildCategorySection() {
    return Expanded(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
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
            // 三个分类卡片 - 垂直排列，不滚动
            ...categories.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> category = entry.value;
              return _buildCategoryCard(category, index);
            }).toList(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 构建分类卡片 - 垂直排列
  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    String categoryName = category['name'];
    List<Map<String, dynamic>> categoryElements =
        elementsByCategory[categoryName] ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // 浅绿色背景
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类标题行
          Row(
            children: [
              // 分类图标 - 使用素材库图片
              Image.asset(
                category['icon'],
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              // 分类名称 - 使用素材库图片
              Image.asset(
                'assets/images/添加元素/$categoryName.png',
                height: 22,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 该分类下的元素网格 - 每行4个
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 每行4个元素
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: categoryElements.length,
            itemBuilder: (context, index) {
              return _buildElementItem(categoryElements[index]);
            },
          ),
        ],
      ),
    );
  }

  // 构建元素项 - 点击直接添加
  Widget _buildElementItem(Map<String, dynamic> element) {
    String elementName = element['name'];
    bool isSelected = addedElements.containsKey(elementName);
    int count = addedElements[elementName] ?? 0;

    return GestureDetector(
      onTap: () {
        // 点击直接添加元素
        addElement(elementName);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
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

            // 选中计数角标
            if (isSelected && count > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 构建已选元素区域
  Widget _buildSelectedElementsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "已选元素："标题 - 使用素材库图片
          Row(
            children: [
              Image.asset(
                'assets/images/添加元素/已选元素.png',
                height: 18,
                fit: BoxFit.contain,
              ),
              const Text(
                '：',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 已选元素列表
          selectedElements.isEmpty
              ? const Text(
                  '暂未选择任何元素',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: selectedElements.map((element) {
                    return _buildSelectedElementChip(element);
                  }).toList(),
                ),
        ],
      ),
    );
  }

  // 构建已选元素标签
  Widget _buildSelectedElementChip(Map<String, dynamic> element) {
    return GestureDetector(
      onTap: () {
        // 点击已选元素可减少数量
        removeElement(element['name']);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 元素图标
            Image.asset(
              'assets/images/添加元素/${element['name']}.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            // 元素名称
            Text(
              element['name'],
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(width: 4),
            // 数量
            Text(
              '×${element['count']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // 构建底部按钮
  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 返回按钮 - 使用素材库图片，点击返回编辑页
          Expanded(
            child: GestureDetector(
              onTap: goBackToEditPage,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/添加元素/返回.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 删除按钮 - 使用素材库图片
          Expanded(
            child: GestureDetector(
              onTap: deleteAllElements,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/添加元素/删除.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 应用按钮 - 使用素材库图片
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: applyAndReturn,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/添加元素/应用.png',
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
