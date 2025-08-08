import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'exercise_detail_page.dart';
import 'workout_session_page.dart';

/// A page that shows detailed information about a single video. It
/// displays a large hero image (using the preview_url or a placeholder),
/// title, description, and a list of exercises featured in the video. A
/// button allows playing the video via url_launcher. Related workouts
/// could be linked from here in the future.
class VideoDetailPage extends StatefulWidget {
  final String videoId;
  const VideoDetailPage({super.key, required this.videoId});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final SupabaseClient _client = Supabase.instance.client;
  Map<String, dynamic>? _video;
  List<Map<String, dynamic>> _exercises = [];
  bool _loading = true;

  /// Creates a temporary workout from the exercises in this video and starts
  /// a session. If the user is not signed in or there are no exercises
  /// associated with the video, a snackbar is shown instead. The workout
  /// is marked as private and named after the video title.
  Future<void> _startRelatedWorkout() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to start a workout.')),
      );
      return;
    }
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exercises to create a workout.')),
      );
      return;
    }
    try {
      // Create a new workout record
      final insert = await _client
          .from('workouts')
          .insert({
        'name': _video?['title'] ?? 'Video Workout',
        'description': _video?['description'] ?? '',
        'user_id': user.id,
        'is_public': false,
      }).select<Map<String, dynamic>>()
          .single();
      final workoutId = insert['id'] as String;
      // Insert each exercise into workout_exercises preserving order
      final rows = _exercises.asMap().entries.map((entry) => {
            'workout_id': workoutId,
            'exercise_id': entry.value['id'],
            'order': entry.key + 1,
          });
      await _client.from('workout_exercises').insert(rows.toList());
      if (!mounted) return;
      // Navigate to workout session page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkoutSessionPage(workoutId: workoutId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start workout')), 
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final videoRes = await _client
        .from('videos')
        .select<Map<String, dynamic>>()
        .eq('id', widget.videoId)
        .single();
    // Fetch related exercises through the junction table
    final relRows = await _client
        .from('exercise_videos')
        .select<List<Map<String, dynamic>>>('exercise_id')
        .eq('video_id', widget.videoId);
    final exerciseIds = relRows.map((r) => r['exercise_id'] as String).toList();
    List<Map<String, dynamic>> exercises = [];
    if (exerciseIds.isNotEmpty) {
      exercises = await _client
          .from('exercises')
          .select<List<Map<String, dynamic>>>(
              'id, name, description, recommended_sets, recommended_reps, preview_url')
          .in_('id', exerciseIds);
    }
    setState(() {
      _video = videoRes;
      _exercises = exercises;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Details'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _video == null
              ? const Center(child: Text('Video not found'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero image
                      _buildHero(context),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _video!['title'] as String? ?? '',
                              style: theme.textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            if ((_video!['description'] as String?)
                                    ?.isNotEmpty ??
                                false)
                              Text(
                                _video!['description'] as String? ?? '',
                                style: theme.textTheme.bodyMedium,
                              ),
                            const SizedBox(height: 16),
                            // Buttons: start related workout and play video
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _startRelatedWorkout,
                                    child: const Text('Start Related Workout'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final url = _video!['video_url'] as String?;
                                      if (url != null) {
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      }
                                    },
                                    child: const Text('Play Video'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text('Exercises in this video',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            if (_exercises.isEmpty)
                              const Text('No exercises associated with this video.')
                            else
                              Column(
                                children: [
                                  ..._exercises.map((ex) {
                                    final sets = ex['recommended_sets'];
                                    final reps = ex['recommended_reps'];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: ListTile(
                                        leading: ex['preview_url'] != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  ex['preview_url'],
                                                  width: 56,
                                                  height: 56,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : const Icon(Icons.fitness_center),
                                        title: Text(ex['name'] as String? ?? ''),
                                        subtitle: Text([
                                          if (sets != null) '${sets} sets',
                                          if (reps != null) '${reps} reps'
                                        ].join('  ')),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ExerciseDetailPage(
                                                exerciseId: ex['id'] as String,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            const SizedBox(height: 24),
                            // Placeholder for comments
                            const Text('Comments will be available soon.'),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  /// Builds the hero image for the video detail page. Uses the preview_url
  /// if available, otherwise a placeholder container. A gradient overlay
  /// darkens the bottom for text legibility. The hero could be replaced
  /// with an embedded video player in the future.
  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preview = _video!['preview_url'] as String?;
    return Stack(
      children: [
        preview != null
            ? Image.network(
                preview,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 240,
                  width: double.infinity,
                  color: colorScheme.surfaceVariant,
                  child: const Icon(Icons.play_circle_outline, size: 64),
                ),
              )
            : Container(
                height: 240,
                width: double.infinity,
                color: colorScheme.surfaceVariant,
                child: const Icon(Icons.play_circle_outline, size: 64),
              ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}