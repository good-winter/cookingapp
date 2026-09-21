// lib/features/cooking/data/mock_recipes.dart
import '../models/recipe.dart';

/// 模拟菜谱数据源。
///
/// 接入后端后，这个文件应该被一个 repository 取代（用 dio 调接口），
/// 上层的筛选逻辑（services/recipe_recommender.dart）和 UI 都不用动 ——
/// 「换数据来源」的改动应该收敛在这一个文件里。
const List<Recipe> mockRecipes = [
  Recipe('番茄炒蛋', '🍲', '10分钟', ['孕妇', '学生', '素食'], []),
  Recipe('红烧肉', '🥩', '45分钟', ['正常人'], ['猪肉']),
  Recipe('香煎鸡胸肉', '🍗', '15分钟', ['健身人群', '运动员'], []),
  Recipe('清蒸鲈鱼', '🐟', '20分钟', ['老人', '孕妇'], ['海鲜']),
  Recipe('麻婆豆腐', '🌶️', '15分钟', ['学生', '正常人'], ['辛辣']),
  Recipe('白灼西兰花', '🥦', '8分钟', ['健身人群', '素食', '老人'], []),
];
