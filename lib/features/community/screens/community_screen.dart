// lib/features/community/screens/community_screen.dart
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 模拟数据源
  final List<Post> _posts = [
    Post(
      id: '1',
      userName: '美食家A',
      userAvatar: 'A',
      userTag: '孕妇',
      time: '刚刚',
      content: '今天用App的AI识别挑的西红柿，做的番茄炒蛋太香了！AI提示我孕妇要少吃某种香料，真的帮了大忙。',
      imageEmoji: '🍲',
      hashtags: ['孕妇餐', '快手菜', '番茄炒蛋'],
      likes: 128,
      comments: 45,
    ),
    Post(
      id: '2',
      userName: '健身狂人B',
      userAvatar: 'B',
      userTag: '健身人群',
      time: '1小时前',
      content: '求问：健身完吃这个热量超了吗？App统计说这顿大概350大卡，我觉得还行？',
      imageEmoji: '🥗',
      hashtags: ['减脂餐', '低卡', '健身'],
      likes: 12,
      comments: 89,
    ),
    Post(
      id: '3',
      userName: '厨房小白C',
      userAvatar: 'C',
      userTag: '学生',
      time: '2小时前',
      content: '跟着沉浸式做饭模式一步一步来，居然没翻车！语音播报太适合我这种手忙脚乱的人了。',
      imageEmoji: '🍳',
      hashtags: ['学生党', '新手做饭', '沉浸式做饭'],
      likes: 56,
      comments: 23,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('社区', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF7A00),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF7A00),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: '推荐'),
            Tab(text: '关注'),
            Tab(text: '同城'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostList(), // 推荐
          _buildPostList(), // 关注（暂时复用）
          _buildPostList(), // 同城（暂时复用）
        ],
      ),
      // 在 class _CommunityScreenState extends State<CommunityScreen> 中：

      // 修改 FAB 的点击逻辑
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 跳转到发布页面，并等待它返回数据
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );

          // 🛡️ 安全校验：如果页面在等待期间被销毁，直接 return
          if (!context.mounted) return;

          // 如果用户点击了发布并且带回了数据
          if (result != null) {
            setState(() {
              // 将新帖子插入到列表最前面
              _posts.insert(
                0,
                Post(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  userName: '我', // 当前用户
                  userAvatar: '我',
                  userTag: '学生', // 模拟当前用户标签
                  time: '刚刚',
                  content: result['content'],
                  imageEmoji: result['imageEmoji'],
                  hashtags: List<String>.from(result['tags']),
                  likes: 0,
                  comments: 0,
                ),
              );
            });

            // 提示发布成功
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('发布成功！'), backgroundColor: Color(0xFFFF7A00)),
            );
          }
        },
        backgroundColor: const Color(0xFFFF7A00),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  // 帖子列表构建
  Widget _buildPostList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80, left: 16, right: 16),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return PostCard(
          post: post,
          onLike: () {
            setState(() {
              post.isLiked = !post.isLiked;
              post.likes += post.isLiked ? 1 : -1;
            });
          },
          onFollow: () {
            setState(() {
              post.isFollowed = !post.isFollowed;
            });
          },
        );
      },
    );
  }
}