import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

/// Displays statistics and charts about the user's workouts and exercises.
/// Uses the fl_chart package to render a line chart showing how many
/// workouts were completed on each day and a bar chart indicating
/// which exercises are used most frequently. When no data is
/// available the page displays helpful messages.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _loading = true;
  // Data for line chart: each spot's x coordinate corresponds to an index in
  // _lineLabels; y is the count of workouts completed on that date.
  List<FlSpot> _lineSpots = [];
  List<String> _lineLabels = [];
  // Data for bar chart: each bar group has an x index and a list of rods.
  List<BarChartGroupData> _barGroups = [];
  List<String> _barLabels = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    try {
      // 1. Fetch completed workouts for the user. We assume the table
      // `completed_workouts` contains at least columns `completed_at` and
      // `workout_id` and is public for the user. Adjust the column names as
      // necessary according to your schema.
      final completions = await _client
          .from('completed_workouts')
          .select<List<Map<String, dynamic>>>(
              'completed_at, workout_id')
          .eq('user_id', user.id);
      // Group counts by date
      final Map<DateTime, int> dailyCounts = {};
      for (final rec in completions) {
        final ts = rec['completed_at'];
        if (ts == null) continue;
        DateTime dt;
        if (ts is String) {
          dt = DateTime.parse(ts);
        } else {
          dt = DateTime.fromMillisecondsSinceEpoch(ts as int);
        }
        final dateOnly = DateTime(dt.year, dt.month, dt.day);
        dailyCounts.update(dateOnly, (v) => v + 1, ifAbsent: () => 1);
      }
      // Sort by date ascending
      final sortedDates = dailyCounts.keys.toList()..sort();
      // Prepare line chart data
      final List<FlSpot> spots = [];
      final List<String> labels = [];
      for (int i = 0; i < sortedDates.length; i++) {
        final date = sortedDates[i];
        spots.add(FlSpot(i.toDouble(), dailyCounts[date]!.toDouble()));
        labels.add(DateFormat('MMM d').format(date));
      }
      // 2. Compute exercise frequency. For each completion, fetch associated
      // exercises via `workout_exercises`. This naive approach makes one
      // request per completion. For better performance you could create a
      // Postgres view or use stored procedures.
      final Map<String, int> exerciseCounts = {};
      for (final rec in completions) {
        final workoutId = rec['workout_id'];
        if (workoutId == null) continue;
        final exRows = await _client
            .from('workout_exercises')
            .select<List<Map<String, dynamic>>>('exercise_id')
            .eq('workout_id', workoutId);
        for (final row in exRows) {
          final exId = row['exercise_id'] as String?;
          if (exId != null) {
            exerciseCounts.update(exId, (v) => v + 1, ifAbsent: () => 1);
          }
        }
      }
      // Sort exercises by count descending and limit to top 5
      final sortedExerciseIds = exerciseCounts.keys.toList()
        ..sort((a, b) => exerciseCounts[b]!.compareTo(exerciseCounts[a]!));
      final topExerciseIds = sortedExerciseIds.take(5).toList();
      // Fetch exercise names
      List<String> labelsBar = [];
      List<BarChartGroupData> barGroups = [];
      if (topExerciseIds.isNotEmpty) {
        final exercises = await _client
            .from('exercises')
            .select<List<Map<String, dynamic>>>('id, name')
            .in_('id', topExerciseIds);
        final nameMap = {for (var ex in exercises) ex['id']: ex['name']};
        for (int i = 0; i < topExerciseIds.length; i++) {
          final id = topExerciseIds[i];
          final count = exerciseCounts[id]!.toDouble();
          barGroups.add(BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: count, width: 20)],
          ));
          labelsBar.add(nameMap[id] as String? ?? '');
        }
      }
      setState(() {
        _lineSpots = spots;
        _lineLabels = labels;
        _barGroups = barGroups;
        _barLabels = labelsBar;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  // Helper to build bottom axis titles for the line chart
  Widget _bottomLineTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= _lineLabels.length) return const SizedBox();
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        _lineLabels[index],
        style: const TextStyle(fontSize: 10),
      ),
    );
  }

  // Helper to build bottom axis titles for the bar chart
  Widget _bottomBarTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= _barLabels.length) return const SizedBox();
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        _barLabels[index],
        style: const TextStyle(fontSize: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lineSpots.isEmpty && _barGroups.isEmpty
              ? const Center(
                  child: Text('No workout data yet. Complete workouts to see your progress!'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_lineSpots.isNotEmpty) ...[
                        Text('Workouts over time', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: _lineSpots.length > 1 ? (_lineSpots.length - 1).toDouble() : 0,
                              minY: 0,
                              maxY: _lineSpots.map((s) => s.y).fold<double>(0, (prev, y) => y > prev ? y : prev) + 1,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _lineSpots,
                                  isCurved: true,
                                  barWidth: 3,
                                  color: Theme.of(context).colorScheme.primary,
                                  dotData: const FlDotData(show: false),
                                ),
                              ],
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: _bottomLineTitle,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: true, interval: 1),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_barGroups.isNotEmpty) ...[
                        Text('Top exercises', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              barGroups: _barGroups,
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: _bottomBarTitle,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: true, interval: 1),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: false),
                              maxY: _barGroups
                                      .map((g) => g.barRods.first.toY)
                                      .fold<double>(0, (prev, y) => y > prev ? y : prev) +
                                  1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}