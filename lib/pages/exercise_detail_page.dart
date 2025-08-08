import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'videos_page.dart' show VideoDetailDialog;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _exercise == null
              ? const Center(child: Text('Exercise not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_exercise!['preview_url'] != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _exercise!['preview_url'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: 200,
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              child: const Icon(Icons.fitness_center, size: 64),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        _exercise!['name'] as String? ?? 'Exercise',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _exercise!['description'] as String? ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      if (_exercise!['sets'] != null || _exercise!['reps'] != null) ...[
                        Text('Recommended:', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${_exercise!['sets'] != null ? '${_exercise!['sets']} sets' : ''}'
                          '${_exercise!['reps'] != null ? ' ${_exercise!['reps']} reps' : ''}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text('Related videos:', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ..._videos.map(
                        (video) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.play_circle_outline),
                          title: Text(video['title'] as String? ?? ''),
                          subtitle: Text(
                            video['description'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            // Could navigate to a video detail page but currently
                            // we just show a simple dialog using the existing
                            // VideoDetailDialog from videos_page.dart
                            showDialog(
                              context: context,
                              builder: (context) => VideoDetailDialog(
                                videoId: video['id'] as String,
                              ),
                            );
                          },
                        ),
                      ),
                      if (_videos.isEmpty)
                        const Text('No videos for this exercise'),
                    ],
                  ),
                ),
    );
  }
}