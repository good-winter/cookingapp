// lib/features/community/screens/create_post_screen.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<String> _selectedTags = [];

  // 预设的话题标签
  final List<String> _availableTags = ['快手菜', '减脂餐', '孕妇餐', '学生党', '烘焙', '沉浸式做饭'];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitPost() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写点什么再发布吧~')),
      );
      return;
    }
    // 返回上一页，并把填写的内容传回去
    Navigator.pop(context, {
      'content': _textController.text.trim(),
      'tags': _selectedTags,
      'imageEmoji': '🍱', // 暂时固定一个便当图标，后续可替换为真实图片
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // 背景色交给 scaffoldBackgroundColor，不再写死浅灰
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor(context),
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            '取消',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
          ),
        ),
        title: Text('发布动态', style: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('发布'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 文本输入区
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _textController,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: '分享你的做饭心得、成果或求助...',
                  border: InputBorder.none,
                  counterText: '', // 隐藏右下角字数统计
                ),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),

            // 2. 图片选择区 (模拟)
            const Text('添加图片', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 3, // 模拟最多选3张图
              itemBuilder: (context, index) {
                if (index == 0) {
                  // “+”号添加按钮
                  return GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('图片选择器开发中（后续可接入 image_picker）')),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant, style: BorderStyle.solid),
                      ),
                      child: Icon(Icons.add_a_photo_outlined, color: scheme.onSurfaceVariant, size: 30),
                    ),
                  );
                }
                // 已选图片占位
                return Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('🍲', style: TextStyle(fontSize: 40))),
                );
              },
            ),
            const SizedBox(height: 24),

            // 3. 话题标签选择
            const Text('添加话题', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text('#$tag'),
                  selected: isSelected,
                  selectedColor: AppTheme.softPrimary(context),
                  checkmarkColor: const Color(0xFFFF7A00),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFFFF7A00) : scheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            // 4. 提示文字
            Center(
              child: Text(
                '友善发言，分享美好食光 ✨',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}