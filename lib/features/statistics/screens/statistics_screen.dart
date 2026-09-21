// lib/features/statistics/screens/statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // 模拟近两周的热量数据（14天）
  final List<double> _weeklyCalories = [1800, 2100, 1500, 1900, 2200, 1700, 1600, 2000, 1850, 2300, 1700, 1500, 1900, 2100];
  final List<String> _dates = ['09/07', '09/08', '09/09', '09/10', '09/11', '09/12', '09/13', '09/14', '09/15', '09/16', '09/17', '09/18', '09/19', '09/20'];

  // 模拟的营养比例数据 (碳水, 蛋白, 脂肪)
  final double _carbsRatio = 50;
  final double _proteinRatio = 25;
  final double _fatRatio = 25;

  // 模拟的历史记录
  final List<Map<String, String>> _historyRecords = [
    {'date': '09/20', 'name': '番茄炒蛋', 'calories': '180kcal'},
    {'date': '09/19', 'name': '香煎鸡胸肉', 'calories': '250kcal'},
    {'date': '09/18', 'name': '红烧肉', 'calories': '450kcal'},
    {'date': '09/17', 'name': '白灼西兰花', 'calories': '80kcal'},
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // 日期选择器入口
          TextButton.icon(
            onPressed: () {
              // TODO: 实现日期范围选择
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('日期选择功能开发中...')),
              );
            },
            icon: Icon(Icons.calendar_today, size: 16, color: scheme.onSurfaceVariant),
            label: Text('2026年9月', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 概览卡片
            Row(
              children: [
                _buildStatCard('今日摄入', '1800', 'kcal', const Color(0xFFFF7A00)), // 突出今日
                const SizedBox(width: 16),
                _buildStatCard('本周平均', '1950', 'kcal', const Color(0xFF2ECC71)),
              ],
            ),
            const SizedBox(height: 24),

            // 2. 近两周热量趋势 (柱状图)
            const Text('📈 近两周热量趋势', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow(context),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 3000,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          // 只显示部分日期，避免拥挤
                          if (value.toInt() % 2 == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _dates[value.toInt()],
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1000,
                    getDrawingHorizontalLine: (value) => FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(_weeklyCalories.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: _weeklyCalories[index],
                          color: const Color(0xFFFF7A00),
                          width: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3. 营养均衡度 (环形图)
            const Text('🍩 营养均衡度', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Container(
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow(context),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            color: const Color(0xFFFF7A00),
                            value: _carbsRatio,
                            title: '${_carbsRatio.toInt()}%',
                            radius: 30,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          PieChartSectionData(
                            color: const Color(0xFF2ECC71),
                            value: _proteinRatio,
                            title: '${_proteinRatio.toInt()}%',
                            radius: 30,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          PieChartSectionData(
                            color: const Color(0xFF3498DB),
                            value: _fatRatio,
                            title: '${_fatRatio.toInt()}%',
                            radius: 30,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(const Color(0xFFFF7A00), '碳水'),
                        const SizedBox(height: 8),
                        _buildLegendItem(const Color(0xFF2ECC71), '蛋白质'),
                        const SizedBox(height: 8),
                        _buildLegendItem(const Color(0xFF3498DB), '脂肪'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. 历史记录
            const Text('📋 历史记录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow(context),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _historyRecords.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final record = _historyRecords[index];
                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: Text('🍲', style: TextStyle(fontSize: 20))),
                    ),
                    title: Text(record['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text(record['date']!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    trailing: Text(record['calories']!, style: const TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // 5. 数据保存提示
            Center(
              child: TextButton.icon(
                onPressed: () {
                  // TODO: 「数据保存时间」属于服务端的数据保留策略，不是本地设置项，
                  //       所以没有放进设置页。等接口契约补上相关端点后再接
                  //       （见 docs/API_CONTRACT.md）。
                },
                icon: Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                label: Text(
                  '数据保存时间: 永久保存 (点击修改)',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 构建概览卡片
  Widget _buildStatCard(String title, String value, String unit, Color color) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(unit, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建图例
  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}