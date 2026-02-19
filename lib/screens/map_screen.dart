import 'package:flutter/material.dart';
import 'dart:async';

// 导入其他页面
import 'home_screen.dart';
import 'comment_section_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // 当前选中的省份
  String? selectedProvince;

  // 模拟已添加的省份数据
  final List<String> addedProvinces = [
    '北京',
    '上海',
    '广东',
    '浙江',
    '江苏',
    '四川',
    '陕西',
  ];

  // 模拟明信片数据
  final List<PostcardData> postcards = [
    PostcardData(
      city: '北京',
      imageUrl: 'assets/images/postcard1.jpg',
      content: '故宫的红墙黄瓦，历史的厚重感扑面而来',
      date: '2024-01-15',
    ),
    PostcardData(
      city: '上海',
      imageUrl: 'assets/images/postcard2.jpg',
      content: '外滩的夜景，繁华都市的璀璨灯火',
      date: '2024-02-20',
    ),
    PostcardData(
      city: '广州',
      imageUrl: 'assets/images/postcard3.jpg',
      content: '早茶的香气，岭南文化的独特韵味',
      date: '2024-03-10',
    ),
    PostcardData(
      city: '杭州',
      imageUrl: 'assets/images/postcard4.jpg',
      content: '西湖春晓，断桥残雪的诗意之美',
      date: '2024-04-05',
    ),
    PostcardData(
      city: '南京',
      imageUrl: 'assets/images/postcard5.jpg',
      content: '秦淮河畔，六朝古都的文化底蕴',
      date: '2024-05-18',
    ),
    PostcardData(
      city: '成都',
      imageUrl: 'assets/images/postcard6.jpg',
      content: '宽窄巷子的悠闲，川蜀生活的慢节奏',
      date: '2024-06-22',
    ),
  ];

  // 省份数据（与地图区域对应）
  final List<ProvinceData> provinces = [
    ProvinceData(name: '北京', x: 0.78, y: 0.28, region: '华北'),
    ProvinceData(name: '天津', x: 0.76, y: 0.32, region: '华北'),
    ProvinceData(name: '河北', x: 0.74, y: 0.34, region: '华北'),
    ProvinceData(name: '山西', x: 0.70, y: 0.36, region: '华北'),
    ProvinceData(name: '内蒙古', x: 0.62, y: 0.28, region: '华北'),
    ProvinceData(name: '辽宁', x: 0.82, y: 0.22, region: '东北'),
    ProvinceData(name: '吉林', x: 0.84, y: 0.18, region: '东北'),
    ProvinceData(name: '黑龙江', x: 0.86, y: 0.14, region: '东北'),
    ProvinceData(name: '上海', x: 0.84, y: 0.48, region: '华东'),
    ProvinceData(name: '江苏', x: 0.80, y: 0.46, region: '华东'),
    ProvinceData(name: '浙江', x: 0.82, y: 0.52, region: '华东'),
    ProvinceData(name: '安徽', x: 0.76, y: 0.48, region: '华东'),
    ProvinceData(name: '福建', x: 0.78, y: 0.62, region: '华东'),
    ProvinceData(name: '江西', x: 0.74, y: 0.56, region: '华东'),
    ProvinceData(name: '山东', x: 0.72, y: 0.38, region: '华东'),
    ProvinceData(name: '河南', x: 0.68, y: 0.42, region: '华中'),
    ProvinceData(name: '湖北', x: 0.66, y: 0.48, region: '华中'),
    ProvinceData(name: '湖南', x: 0.64, y: 0.54, region: '华中'),
    ProvinceData(name: '广东', x: 0.72, y: 0.72, region: '华南'),
    ProvinceData(name: '广西', x: 0.66, y: 0.68, region: '华南'),
    ProvinceData(name: '海南', x: 0.70, y: 0.82, region: '华南'),
    ProvinceData(name: '重庆', x: 0.60, y: 0.56, region: '西南'),
    ProvinceData(name: '四川', x: 0.52, y: 0.50, region: '西南'),
    ProvinceData(name: '贵州', x: 0.58, y: 0.60, region: '西南'),
    ProvinceData(name: '云南', x: 0.50, y: 0.64, region: '西南'),
    ProvinceData(name: '西藏', x: 0.32, y: 0.48, region: '西南'),
    ProvinceData(name: '陕西', x: 0.60, y: 0.40, region: '西北'),
    ProvinceData(name: '甘肃', x: 0.48, y: 0.38, region: '西北'),
    ProvinceData(name: '青海', x: 0.40, y: 0.44, region: '西北'),
    ProvinceData(name: '宁夏', x: 0.56, y: 0.36, region: '西北'),
    ProvinceData(name: '新疆', x: 0.20, y: 0.30, region: '西北'),
    ProvinceData(name: '香港', x: 0.76, y: 0.70, region: '港澳台'),
    ProvinceData(name: '澳门', x: 0.78, y: 0.72, region: '港澳台'),
    ProvinceData(name: '台湾', x: 0.88, y: 0.58, region: '港澳台'),
  ];

  // 明信片滚动控制器
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  // 开始自动滚动
  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentPage < postcards.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题栏（只有"地图"图片，无状态栏）
            _buildTopTitleBar(),

            // 地图区域
            Expanded(flex: 5, child: _buildMapArea()),

            // "时间，地点"按钮
            _buildTimeLocationButton(),

            // 灰色占位区域
            _buildPlaceholderArea(),

            // 明信片滚动播放区域
            Expanded(flex: 2, child: _buildPostcardCarousel()),

            // 底部导航栏
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  /// 构建顶部标题栏（只有地图图片，无状态栏）
  Widget _buildTopTitleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          const Spacer(),

          // 大号"地图"标题图片
          Image.asset(
            'assets/images/地图/地图.png',
            width: 100,
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                '地图',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              );
            },
          ),

          const Spacer(),
        ],
      ),
    );
  }

  /// 构建地图区域
  Widget _buildMapArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 中国彩色行政区划地图背景
            Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFFE8F4FD),
              child: Image.asset(
                'assets/images/地图/Group 49.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildColoredMapFallback();
                },
              ),
            ),

            // 省份交互层
            ..._buildProvinceLayers(),

            // 城市标点覆盖层
            ..._buildCityMarkers(),

            // 选中省份提示
            if (selectedProvince != null) _buildSelectedProvinceOverlay(),
          ],
        ),
      ),
    );
  }

  /// 构建彩色地图回退（当图片加载失败时）
  Widget _buildColoredMapFallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: CustomPaint(painter: ColoredMapPainter(), size: Size.infinite),
    );
  }

  /// 构建省份交互层
  List<Widget> _buildProvinceLayers() {
    return provinces.map((province) {
      final isAdded = addedProvinces.contains(province.name);
      final isSelected = selectedProvince == province.name;

      return Positioned(
        left: (province.x - 0.04) * 100,
        top: (province.y - 0.025) * 100,
        child: GestureDetector(
          onTap: () {
            _onProvinceTap(province);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 80,
            height: 50,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
          ),
        ),
      );
    }).toList();
  }

  /// 构建城市标点
  List<Widget> _buildCityMarkers() {
    final majorCities = [
      {'name': '北京', 'x': 0.78, 'y': 0.28},
      {'name': '上海', 'x': 0.84, 'y': 0.48},
      {'name': '广州', 'x': 0.72, 'y': 0.72},
      {'name': '深圳', 'x': 0.74, 'y': 0.76},
      {'name': '成都', 'x': 0.52, 'y': 0.50},
      {'name': '西安', 'x': 0.60, 'y': 0.40},
      {'name': '杭州', 'x': 0.82, 'y': 0.52},
      {'name': '南京', 'x': 0.80, 'y': 0.46},
      {'name': '武汉', 'x': 0.70, 'y': 0.52},
      {'name': '重庆', 'x': 0.60, 'y': 0.56},
      {'name': '乌鲁木齐', 'x': 0.20, 'y': 0.30},
      {'name': '拉萨', 'x': 0.32, 'y': 0.52},
      {'name': '呼和浩特', 'x': 0.68, 'y': 0.32},
      {'name': '银川', 'x': 0.56, 'y': 0.36},
      {'name': '南宁', 'x': 0.66, 'y': 0.78},
      {'name': '哈尔滨', 'x': 0.86, 'y': 0.14},
      {'name': '长春', 'x': 0.84, 'y': 0.18},
      {'name': '沈阳', 'x': 0.82, 'y': 0.22},
      {'name': '济南', 'x': 0.72, 'y': 0.38},
      {'name': '郑州', 'x': 0.68, 'y': 0.42},
      {'name': '长沙', 'x': 0.64, 'y': 0.54},
      {'name': '福州', 'x': 0.78, 'y': 0.62},
      {'name': '昆明', 'x': 0.50, 'y': 0.64},
      {'name': '贵阳', 'x': 0.58, 'y': 0.60},
      {'name': '兰州', 'x': 0.48, 'y': 0.38},
      {'name': '西宁', 'x': 0.40, 'y': 0.44},
      {'name': '海口', 'x': 0.70, 'y': 0.82},
      {'name': '香港', 'x': 0.76, 'y': 0.70},
      {'name': '澳门', 'x': 0.78, 'y': 0.72},
      {'name': '台北', 'x': 0.88, 'y': 0.58},
    ];

    return majorCities.map((city) {
      final isAdded = addedProvinces.contains(city['name']);
      final isSelected = selectedProvince == city['name'];

      return Positioned(
        left: (city['x'] as double) * 100,
        top: (city['y'] as double) * 100,
        child: GestureDetector(
          onTap: () {
            _onCityMarkerTap(city['name'] as String);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            transform: Matrix4.identity()..scale(isSelected ? 1.3 : 1.0),
            child: Column(
              children: [
                // 标点图标
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAdded
                        ? (isSelected
                              ? Colors.blue.shade600
                              : Colors.blue.shade500)
                        : Colors.white,
                    border: Border.all(
                      color: isAdded
                          ? Colors.blue.shade600
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isAdded ? Colors.blue : Colors.grey)
                            .withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isAdded ? Icons.check : Icons.location_on_outlined,
                    color: isAdded ? Colors.white : Colors.grey.shade500,
                    size: 12,
                  ),
                ),

                // 城市名称标签
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    city['name'] as String,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey.shade800,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),

                // 动态波纹效果（仅已添加的城市）
                if (isAdded)
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ...List.generate(3, (index) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(seconds: 2 + index),
                            builder: (context, value, child) {
                              return Container(
                                width: 16 * value,
                                height: 16 * value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(
                                      0.3 * (1 - value),
                                    ),
                                    width: 2,
                                  ),
                                ),
                              );
                            },
                            onEnd: () {},
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  /// 构建选中省份覆盖层
  Widget _buildSelectedProvinceOverlay() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade500, Colors.blue.shade600],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              '已选择：$selectedProvince',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() {
                  selectedProvince = null;
                });
              },
              child: Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  /// 处理省份点击
  void _onProvinceTap(ProvinceData province) {
    setState(() {
      if (addedProvinces.contains(province.name)) {
        selectedProvince = province.name;
      } else {
        // 未添加省份的提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${province.name} 暂未添加，快去打卡吧！'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  /// 处理城市标点点击
  void _onCityMarkerTap(String cityName) {
    _onProvinceTap(ProvinceData(name: cityName, x: 0, y: 0, region: ''));
  }

  /// 构建"时间，地点"按钮
  Widget _buildTimeLocationButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          'assets/images/地图/地图1-时间地点.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 图片加载失败时显示原来的样式作为回退
            return Container(
              color: Colors.grey.shade200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '时间，地点',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建灰色占位区域
  Widget _buildPlaceholderArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  /// 构建明信片滚动播放区域
  Widget _buildPostcardCarousel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区域标题
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Icon(Icons.auto_stories, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 6),
                Text(
                  '滚动播放自己的城市明信片',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${postcards.length}张',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // 横向滚动卡片列表
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: postcards.length,
              itemBuilder: (context, index) {
                return _buildPostcardItem(postcards[index], index);
              },
            ),
          ),

          // 页面指示器
          _buildPageIndicator(),
        ],
      ),
    );
  }

  /// 构建页面指示器
  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(postcards.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _currentPage == index ? 12 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? Colors.blue.shade500
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  /// 构建单个明信片项
  Widget _buildPostcardItem(PostcardData postcard, int index) {
    final isVisible = (index - _currentPage).abs() <= 1;

    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: () => _onPostcardTap(postcard),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 明信片图片
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        // 图片
                        Image.asset(
                          postcard.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: _getRandomColor(postcard.city.hashCode),
                              child: Center(
                                child: Icon(
                                  Icons.image,
                                  size: 40,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            );
                          },
                        ),

                        // 城市标签
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              postcard.city,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 明信片内容
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 内容文字
                          Expanded(
                            child: Text(
                              postcard.content,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // 日期
                          Text(
                            postcard.date,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 获取随机颜色（用于占位图）
  Color _getRandomColor(int seed) {
    final colors = [
      Colors.blue.shade300,
      Colors.green.shade300,
      Colors.orange.shade300,
      Colors.purple.shade300,
      Colors.teal.shade300,
      Colors.pink.shade300,
    ];
    return colors[seed % colors.length];
  }

  /// 明信片点击事件
  void _onPostcardTap(PostcardData postcard) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildPostcardDetailSheet(postcard),
    );
  }

  /// 构建明信片详情弹窗
  Widget _buildPostcardDetailSheet(PostcardData postcard) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 头部
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.location_city,
                  color: Colors.blue.shade600,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  postcard.city,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 图片
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  postcard.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: _getRandomColor(postcard.city.hashCode),
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 内容
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '旅行笔记',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    postcard.content,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        postcard.date,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部导航栏（使用自定义图片图标）
  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: 1, // 地图页默认选中
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue.shade400,
        unselectedItemColor: Colors.grey.shade400,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        elevation: 0,
        items: [
          // 首页
          BottomNavigationBarItem(
            icon: _buildNavIcon('assets/images/首页-首页（无色）.png', false),
            activeIcon: _buildNavIcon('assets/images/首页-首页（无色）.png', true),
            label: '首页',
          ),
          // 地图
          BottomNavigationBarItem(
            icon: _buildNavIcon('assets/images/首页-地图.png', false),
            activeIcon: _buildNavIcon('assets/images/首页-地图.png', true),
            label: '地图',
          ),
          // 讨论区
          BottomNavigationBarItem(
            icon: _buildNavIcon('assets/images/首页-讨论区.png', false),
            activeIcon: _buildNavIcon('assets/images/首页-讨论区.png', true),
            label: '讨论区',
          ),
          // 我的
          BottomNavigationBarItem(
            icon: _buildNavIcon('assets/images/首页-我的.png', false),
            activeIcon: _buildNavIcon('assets/images/首页-我的.png', true),
            label: '我的',
          ),
        ],
        onTap: (index) {
          _onNavigationTap(index);
        },
      ),
    );
  }

  /// 构建导航栏图标
  Widget _buildNavIcon(String assetPath, bool isActive) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Image.asset(
        assetPath,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // 图片加载失败时显示默认图标
          return Icon(
            isActive ? Icons.circle : Icons.circle_outlined,
            size: 24,
            color: isActive ? Colors.blue.shade400 : Colors.grey.shade400,
          );
        },
      ),
    );
  }

  /// 导航栏点击事件 - 实现页面跳转
  void _onNavigationTap(int index) {
    switch (index) {
      case 0:
        // 跳转到首页
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1:
        // 当前就是地图页，不需要跳转
        break;
      case 2:
        // 跳转到讨论区
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CommentSectionScreen()),
        );
        break;
    }
  }
}

/// 明信片数据模型
class PostcardData {
  final String city;
  final String imageUrl;
  final String content;
  final String date;

  PostcardData({
    required this.city,
    required this.imageUrl,
    required this.content,
    required this.date,
  });
}

/// 省份数据模型
class ProvinceData {
  final String name;
  final double x;
  final double y;
  final String region;

  ProvinceData({
    required this.name,
    required this.x,
    required this.y,
    required this.region,
  });
}

/// 彩色地图绘制器（当图片资源缺失时使用）
class ColoredMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 定义各区域颜色
    final regionColors = {
      '东北': const Color(0xFFB8E6B8),
      '华北': const Color(0xFFB8D4E6),
      '华东': const Color(0xFFE6D4B8),
      '华中': const Color(0xFFD4B8E6),
      '华南': const Color(0xFFE6B8B8),
      '西南': const Color(0xFFB8E6E6),
      '西北': const Color(0xFFE6E6B8),
      '港澳台': const Color(0xFFFFE4B8),
    };

    // 绘制简化版中国地图轮廓
    _drawSimplifiedChinaMap(canvas, size, regionColors);
  }

  void _drawSimplifiedChinaMap(
    Canvas canvas,
    Size size,
    Map<String, Color> regionColors,
  ) {
    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFFA0A0A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 主轮廓路径
    final mainPath = Path();

    // 简化的大陆轮廓
    mainPath.moveTo(size.width * 0.65, size.height * 0.25);
    mainPath.quadraticBezierTo(
      size.width * 0.90,
      size.height * 0.30,
      size.width * 0.88,
      size.height * 0.50,
    );
    mainPath.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.70,
      size.width * 0.70,
      size.height * 0.80,
    );
    mainPath.quadraticBezierTo(
      size.width * 0.50,
      size.height * 0.88,
      size.width * 0.30,
      size.height * 0.75,
    );
    mainPath.quadraticBezierTo(
      size.width * 0.15,
      size.height * 0.60,
      size.width * 0.20,
      size.height * 0.40,
    );
    mainPath.quadraticBezierTo(
      size.width * 0.30,
      size.height * 0.20,
      size.width * 0.50,
      size.height * 0.25,
    );
    mainPath.close();

    // 填充主背景
    paint.color = const Color(0xFFE8F4FD);
    canvas.drawPath(mainPath, paint);
    canvas.drawPath(mainPath, strokePaint);

    // 绘制各区域（简化表示）
    _drawRegion(canvas, size, 0.70, 0.20, 0.20, 0.15, regionColors['东北']!);
    _drawRegion(canvas, size, 0.60, 0.25, 0.15, 0.12, regionColors['华北']!);
    _drawRegion(canvas, size, 0.75, 0.40, 0.15, 0.18, regionColors['华东']!);
    _drawRegion(canvas, size, 0.60, 0.40, 0.12, 0.10, regionColors['华中']!);
    _drawRegion(canvas, size, 0.60, 0.60, 0.12, 0.15, regionColors['华南']!);
    _drawRegion(canvas, size, 0.40, 0.40, 0.20, 0.20, regionColors['西南']!);
    _drawRegion(canvas, size, 0.25, 0.20, 0.20, 0.18, regionColors['西北']!);
    _drawRegion(canvas, size, 0.82, 0.70, 0.08, 0.08, regionColors['港澳台']!);
  }

  void _drawRegion(
    Canvas canvas,
    Size size,
    double x,
    double y,
    double w,
    double h,
    Color color,
  ) {
    final paint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = const Color(0xFF909090)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 绘制不规则区域
    final path = Path();
    path.moveTo(size.width * (x - w / 2), size.height * (y - h / 3));
    path.lineTo(size.width * (x + w / 2), size.height * (y - h / 3));
    path.quadraticBezierTo(
      size.width * (x + w / 2 + 0.05),
      size.height * y,
      size.width * (x + w / 3),
      size.height * (y + h / 2),
    );
    path.quadraticBezierTo(
      size.width * x,
      size.height * (y + h / 2 + 0.05),
      size.width * (x - w / 3),
      size.height * (y + h / 2),
    );
    path.quadraticBezierTo(
      size.width * (x - w / 2 - 0.05),
      size.height * y,
      size.width * (x - w / 2),
      size.height * (y - h / 3),
    );
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
