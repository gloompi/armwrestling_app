import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'workout_session_page.dart';

/// Home page displaying workouts scheduled for the current day and offering
/// quick access to start or continue a workout. A summary of recent
/// activities is also displayed.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SupabaseClient _client;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
  }

  /// Fetches up to 10 workouts belonging to the current user, sorted by
  /// creation date descending. Returns an empty list if the user is not
  /// authenticated or has no workouts.
  Future<List<Map<String, dynamic>>> _fetchMyWorkouts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final response = await _client
        .from('workouts')
        .select<List<Map<String, dynamic>>>()
        .eq('user_id', user.id)
        .order('created_at', ascending: true);
    return response;
  }

  /// Counts the number of workouts (from completed_workouts) completed in
  /// the current week. If the table or data are unavailable, returns 0.
  Future<int> _fetchWorkoutsThisWeek() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startDate = DateFormat('yyyy-MM-dd').format(startOfWeek);
    try {
      final response = await _client
          .from('completed_workouts')
          .select()
          .eq('user_id', user.id)
          .gte('completed_at', '$startDate 00:00:00');
      return response.length;
    } catch (_) {
      return 0;
    }
  }

  /// Fetches the details of the first workout (assumed to be today's or next
  /// workout) and the previews for its first two exercises. Returns a
  /// structure containing the workout and a list of preview URLs.
  Future<Map<String, dynamic>?> _fetchNextWorkoutWithPreviews(
      List<Map<String, dynamic>> workouts) async {
    if (workouts.isEmpty) return null;
    final workout = workouts.first;
    final String workoutId = workout['id'] as String;
    // Fetch up to the first two exercises with their preview URLs
    final exRows = await _client
        .from('workout_exercises')
        .select<List<Map<String, dynamic>>>(
            'order, exercises!inner(preview_url, name)')
        .eq('workout_id', workoutId)
        .order('order')
        .limit(2);
    final previews = exRows
        .map<String?>((row) =>
            (row['exercises'] as Map<String, dynamic>)['preview_url'] as String?)
        .toList();
    final names = exRows
        .map<String?>((row) =>
            (row['exercises'] as Map<String, dynamic>)['name'] as String?)
        .toList();
    return {
      'workout': workout,
      'previews': previews,
      'names': names,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayName = DateFormat('EEEE').format(DateTime.now());
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchMyWorkouts(),
      builder: (context, workoutsSnapshot) {
        final workouts = workoutsSnapshot.data ?? [];
        return FutureBuilder<int>(
          future: _fetchWorkoutsThisWeek(),
          builder: (context, statsSnapshot) {
            final workoutsThisWeek = statsSnapshot.data ?? 0;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Text(
                    '$dayName, Ready to crush it?',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Workouts',
                          value: workouts.length.toString(),
                          backgroundColor: colorScheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          title: 'This Week',
                          value: workoutsThisWeek.toString(),
                          backgroundColor: colorScheme.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Avg Rest',
                          value: '60s',
                          backgroundColor: colorScheme.secondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (workouts.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WorkoutSessionPage(
                                    workoutId: workouts.first['id'] as String,
                                  ),
                                ),
                              );
                            }
                          },
                          child: _StatCard(
                            title: 'Start Workout',
                            value: '',
                            child: workouts.isNotEmpty &&
                                    workoutsSnapshot.connectionState ==
                                        ConnectionState.done
                                ? const Icon(Icons.play_arrow, size: 32)
                                : const SizedBox.shrink(),
                            backgroundColor: colorScheme.secondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Today's workout card (first workout)
                  if (workouts.isNotEmpty)
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _fetchNextWorkoutWithPreviews(workouts),
                      builder: (context, nextSnapshot) {
                        final next = nextSnapshot.data;
                        if (next == null) return const SizedBox.shrink();
                        final workout = next['workout'] as Map<String, dynamic>;
                        final previews = (next['previews'] as List<String?>)
                            .whereType<String>()
                            .toList();
                        final names = (next['names'] as List<String?>)
                            .whereType<String>()
                            .toList();
                        return _TodayWorkoutCard(
                          name: workout['name'] as String? ?? 'Workout',
                          description:
                              workout['description'] as String? ?? 'No description',
                          exerciseCount: previews.isNotEmpty
                              ? previews.length
                              : 0,
                          previewUrls: previews,
                          onStart: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WorkoutSessionPage(
                                  workoutId: workout['id'] as String,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  // Recent workouts list
                  Text(
                    'My Workouts',
                    style: theme.textTheme.titleMedium,
                  ),
                    const SizedBox(height: 8),
                  if (workoutsSnapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (workouts.isEmpty)
                    const Text('You have no workouts yet.')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: workouts.length,
                      itemBuilder: (context, index) {
                        final workout = workouts[index];
                        return Card(
                          margin:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              workout['name'] as String? ?? 'Unnamed',
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              workout['description'] as String? ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => WorkoutSessionPage(
                                      workoutId: workout['id'] as String,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Start'),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// A small card used on the home page to display a statistic or quick
/// action. It accepts an optional child to display instead of text
/// value (e.g. an icon).
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Widget? child;
  final Color backgroundColor;

  const _StatCard({
    required this.title,
    required this.value,
    this.child,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: theme.textTheme.bodySmall),
          child ?? Text(
            value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// A large card displaying details about the next (or today's) workout
/// including its name, a short description and preview images for the
/// first few exercises. A Start button allows the user to immediately
/// begin the workout.
class _TodayWorkoutCard extends StatelessWidget {
  final String name;
  final String description;
  final int exerciseCount;
  final List<String> previewUrls;
  final VoidCallback onStart;

  const _TodayWorkoutCard({
    required this.name,
    required this.description,
    required this.exerciseCount,
    required this.previewUrls,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '$exerciseCount exercises',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: previewUrls
                .take(3)
                .map((url) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: url.isNotEmpty
                            ? Image.network(
                                url,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 48,
                                height: 48,
                                color:
                                    colorScheme.surfaceVariant,
                              ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text('Start Workout'),
          ),
        ],
      ),
    );
  }
}