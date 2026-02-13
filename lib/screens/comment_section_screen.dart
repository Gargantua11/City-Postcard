import 'package:flutter/material.dart';
import '../widgets/postcard_display_card.dart';

/// 评论区页面：独立页面，使用可滚动列表展示明信片卡片。
class CommentSectionScreen extends StatelessWidget {
  const CommentSectionScreen({super.key});

  static const List<PostcardDisplayCardData> _cards = [
    PostcardDisplayCardData(
      id: 15,
      username: 'test03',
      avatar: null,
      imageUrl: '',
      createdAt: '2026-02-08T11:00:00',
      address: '济南市历下区',
      likeCount: 126,
      commentCount: 12,
      hotComment: PostcardHotComment(
        id: 9,
        userId: 8,
        username: 'sentimental0610',
        avatar: null,
        content: '板凳，大家好这是第二条评论',
        createdAt: '2026-02-06T23:20:51',
        likeCount: 0,
        liked: false,
        hotScore: 0.0,
        cursor: '2026-02-06 23:20:51_9',
      ),
    ),
    PostcardDisplayCardData(
      id: 14,
      username: 'test01',
      avatar: null,
      imageUrl: '',
      createdAt: '2026-02-07T20:10:00',
      address: '长沙市天心区',
      likeCount: 88,
      commentCount: 6,
      hotComment: PostcardHotComment(
        id: 8,
        userId: 8,
        username: 'sentimental0610',
        avatar: null,
        content: '大家好这是第一条评论，沙发',
        createdAt: '2026-02-06T23:19:48',
        likeCount: 0,
        liked: false,
        hotScore: 0.0,
        cursor: '2026-02-06 23:19:48_8',
      ),
    ),
    PostcardDisplayCardData(
      id: 13,
      username: 'river_walker',
      avatar: null,
      imageUrl: '',
      createdAt: '2026-02-06T18:30:00',
      address: '重庆市南岸区',
      likeCount: 54,
      commentCount: 2,
      hotComment: null,
    ),
    PostcardDisplayCardData(
      id: 12,
      username: 'wanderer',
      avatar: null,
      imageUrl: '',
      createdAt: '2026-02-05T09:12:00',
      address: '青岛市市南区',
      likeCount: 132,
      commentCount: 20,
      hotComment: PostcardHotComment(
        id: 21,
        userId: 2,
        username: 'momo',
        avatar: null,
        content: '这个构图太有电影感了，色调也非常舒服，求拍摄机位！',
        createdAt: '2026-02-05T10:12:00',
        likeCount: 5,
        liked: false,
        hotScore: 9.4,
        cursor: '2026-02-05 10:12:00_21',
      ),
    ),
    PostcardDisplayCardData(
      id: 11,
      username: 'city_stroller',
      avatar: null,
      imageUrl: '',
      createdAt: '2026-02-04T13:40:00',
      address: '成都市武侯区',
      likeCount: 63,
      commentCount: 8,
      hotComment: PostcardHotComment(
        id: 20,
        userId: 6,
        username: 'skyline',
        avatar: null,
        content: '这条街晚上的灯光太漂亮了。',
        createdAt: '2026-02-04T14:05:00',
        likeCount: 2,
        liked: false,
        hotScore: 6.7,
        cursor: '2026-02-04 14:05:00_20',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      ),
                      const Expanded(
                        child: Text(
                          '评论区',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5ECF9),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${_cards.length} 条动态',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2F5D99),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '最新讨论',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: _cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = _cards[index];
                      return PostcardDisplayCard(
                        data: item,
                        liked: index.isEven,
                        onLikeTap: () {
                          debugPrint('POST /postcard/${item.id}/like');
                        },
                        onCommentTap: () {
                          debugPrint(
                            'GET /postcard/${item.id}/comments?sort=hot&size=10',
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 70,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.pushNamed(context, '/home');
                      }
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/首页-首页.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      debugPrint('切换到地图');
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/首页-地图.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      debugPrint('当前在讨论区');
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/首页-讨论区.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      debugPrint('切换到我的');
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/首页-我的.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
