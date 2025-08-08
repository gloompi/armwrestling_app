import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'video_detail_page.dart';

/// Shows detailed information about a single exercise including its
/// description, recommended sets and reps, and related videos. Users can
/// see a preview image and tap on related videos for more context. In a
/// production app you might also embed video playback, but here we keep
/// things simple by displaying a list of related video titles.
class ExerciseDetailPage extends StatefulWidget {
  final String exerciseId;
  const ExerciseDetailPage({super.key, required this.exerciseId});

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  final SupabaseClient _client = Supabase.instance.client;
  Map<String, dynamic>? _exercise;
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;

  /// Helper to add this exercise to one of the user's workouts. Presents
  /// a bottom sheet listing the user's workouts and inserts a new row
  /// into the `workout_exercises` table when one is selected. Requires
  /// the user to be signed in and to own the target workout due to RLS.
  Future<void> _addToWorkout() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add exercises.')),
      );
      return;
    }
    // Load all workouts belonging to the current user
    final workouts = await _client
        .from('workouts')
        .select<List<Map<String, dynamic>>>()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    if (!mounted) return;
    if (workouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have no workouts yet. Create one first.')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Add to workout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...workouts.map((w) => ListTile(
                  title: Text(w['name'] as String? ?? 'Unnamed'),
                  subtitle: Text(
                    w['description'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    // determine next order value by selecting max order for this workout
                    final res = await _client
                        .from('workout_exercises')
                        .select<List<Map<String, dynamic>>>(
                            'order')
                        .eq('workout_id', w['id'] as String)
                        .order('order', ascending: false)
                        .limit(1);
                    int nextOrder = 1;
                    if (res.isNotEmpty && res[0]['order'] != null) {
                      nextOrder = (res[0]['order'] as int) + 1;
                    }
                    try {
                      await _client.from('workout_exercises').insert({
                        'workout_id': w['id'],
                        'exercise_id': widget.exerciseId,
                        'order': nextOrder,
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added to ${w['name']}')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not add exercise')),
                      );
                    }
                  },
                )),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Fetch the exercise details along with recommended sets/reps if present
    final exerciseRes = await _client
        .from('exercises')
        .select<Map<String, dynamic>>()
        .eq('id', widget.exerciseId)
        .single();
    // Fetch related videos via the exercise_videos relation table
    final relRows = await _client
        .from('exercise_videos')
        .select<List<Map<String, dynamic>>>()
        .eq('exercise_id', widget.exerciseId);
    final videoIds = relRows.map((r) => r['video_id'] as String).toList();
    List<Map<String, dynamic>> videos = [];
    if (videoIds.isNotEmpty) {
      videos = await _client
          .from('videos')
          .select<List<Map<String, dynamic>>>()
          .in_('id', videoIds);
    }
    setState(() {
      _exercise = exerciseRes;
      _videos = videos;
      _loading = false;
    });
  }

  /// Builds the hero section containing the preview image and an overlay
  /// with the exercise name, difficulty (if known), recommended sets
  /// and reps, and rest suggestion. Uses a dark gradient overlay for
  /// readability.
  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final previewUrl = _exercise!['preview_url'] as String?;
    final name = _exercise!['name'] as String? ?? 'Exercise';
    final sets = _exercise!['recommended_sets'] as int?;
    final reps = _exercise!['recommended_reps'] as int?;
    return Stack(
      children: [
        // Background image
        previewUrl != null
            ? Image.network(
                previewUrl,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 240,
                  color: colorScheme.surfaceVariant,
                  child: const Icon(Icons.fitness_center, size: 64),
                ),
              )
            : Container(
                height: 240,
                width: double.infinity,
                color: colorScheme.surfaceVariant,
                child: const Icon(Icons.fitness_center, size: 64),
              ),
        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.0),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (sets != null)
                      Text(
                        '$sets sets',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    if (sets != null && reps != null)
                      Text(' · ', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                    if (reps != null)
                      Text(
                        '$reps reps',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    Text(' · 60s rest',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _exercise == null
              ? const Center(child: Text('Exercise not found'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero section with image and overlay
                      _buildHero(context),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((_exercise!['description'] as String?)
                                    ?.isNotEmpty ??
                                false) ...[
                              Text('Description',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                _exercise!['description'] as String? ?? '',
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Related videos list
                            Text('Related Videos',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                            const SizedBox(height: 8),
                            if (_videos.isEmpty)
                              const Text('No related videos')
                            else
                              ..._videos.map(
                                (video) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.play_circle_outline),
                                  title:
                                      Text(video['title'] as String? ?? ''),
                                  subtitle: Text(
                                    video['description'] as String? ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    // Navigate to dedicated video detail page instead of dialog
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => VideoDetailPage(
                                          videoId: video['id'] as String,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _addToWorkout,
                                icon: const Icon(Icons.add),
                                label: const Text('Add to My Workouts'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}