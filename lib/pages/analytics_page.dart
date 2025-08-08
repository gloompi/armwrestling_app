import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// Displays simple analytics about the user's workout history. This
/// implementation shows the number of workouts completed over the past
/// seven days using a bar chart. More charts and statistics can be added
/// later as the app evolves.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _loading = true;
  Map<DateTime, int> _countsByDay = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _countsByDay = {};
      });
      return;
    }
    // Determine the date range for the past 7 days.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    // Fetch all completed workouts for the user in the last 7 days.
    final res = await _client
        .from('completed_workouts')
        .select<List<Map<String, dynamic>>>('completed_at')
        .eq('user_id', user.id)
        .gte('completed_at', DateFormat('yyyy-MM-dd').format(start) + ' 00:00:00')
        .lte('completed_at', DateFormat('yyyy-MM-dd').format(today) + ' 23:59:59');
    // Group by date.
    final counts = <DateTime, int>{};
    for (var i = 0; i < 7; i++) {
      counts[start.add(Duration(days: i))] = 0;
    }
    for (final row in res) {
      final ts = DateTime.parse(row['completed_at'] as String);
      final date = DateTime(ts.year, ts.month, ts.day);
      if (counts.containsKey(date)) {
        counts[date] = counts[date]! + 1;
      }
    }
    setState(() {
      _countsByDay = counts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _countsByDay.isEmpty
              ? const Center(child: Text('No data available'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BarChart(
                    BarChartData(
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: Theme.of(context).colorScheme.surfaceVariant,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final index = value.toInt();
                              final date = _countsByDay.keys.elementAt(index);
                              final label = DateFormat('E').format(date);
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(label),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: _countsByDay.entries
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (entry) => BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.value.toDouble(),
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
    );
  }
}