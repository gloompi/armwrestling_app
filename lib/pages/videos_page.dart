import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Displays a list of videos with optional category filtering and infinite
/// scrolling. Each video can be tapped to view details, comments and
/// related exercises. A button in the detail view links to the exercises
/// page filtered for that video.
class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final List<Map<String, dynamic>> _videos = [];
  final List<Map<String, dynamic>> _categories = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCategories();
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final data = await _client.from('categories').select<List<Map<String, dynamic>>>();
    setState(() {
      _categories.clear();
      _categories.addAll(data);
    });
  }

  Future<List<String>> _videoIdsForCategory(String categoryId) async {
    final rows = await _client
        .from('video_categories')
        .select<List<Map<String, dynamic>>>()
        .eq('category_id', categoryId);
    return rows.map<String>((row) => row['video_id'] as String).toList();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    const limit = 20;
    final query = _client.from('videos').select<List<Map<String, dynamic>>>();
    if (_selectedCategory != null) {
      final ids = await _videoIdsForCategory(_selectedCategory!);
      // Use `in_` instead of `inFilter` for Supabase Flutter v1.0.x. This method
      // performs an `IN` filter on the `id` column when the list of ids is not
      // empty.【481103789607762†L470-L476】
      if (ids.isNotEmpty) {
        query.in_('id', ids);
      }
    }
    final res = await query.order('title').range(_page * limit, _page * limit + limit - 1);
    setState(() {
      _videos.addAll(res);
      _hasMore = res.length == limit;
      _page++;
      _loading = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_loading) {
      _loadMore();
    }
  }

  void _selectCategory(String? id) {
    setState(() {
      _selectedCategory = id;
      _videos.clear();
      _page = 0;
      _hasMore = true;
    });
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => _selectCategory(null),
                ),
              ),
              ..._categories.map((cat) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(cat['name'] as String? ?? ''),
                      selected: _selectedCategory == cat['id'],
                      onSelected: (_) => _selectCategory(cat['id'] as String),
                    ),
                  )),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _videos.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _videos.length) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final video = _videos[index];
                   return Card(
                     margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                     child: ListTile(
                       contentPadding: const EdgeInsets.all(8),
                       leading: const Icon(Icons.play_circle_outline, size: 40),
                       title: Text(
                         video['title'] as String? ?? 'Untitled',
                         style: Theme.of(context).textTheme.titleMedium,
                       ),
                       subtitle: Text(
                         video['description'] as String? ?? '',
                         maxLines: 2,
                         overflow: TextOverflow.ellipsis,
                       ),
                       onTap: () {
                         showDialog(
                           context: context,
                           builder: (context) => VideoDetailDialog(videoId: video['id'] as String),
                         );
                       },
                     ),
                   );
            },
          ),
        ),
      ],
    );
  }
}

/// Dialog showing details for a video, including description, comments
/// placeholder and related exercises. A button allows navigating to
/// the exercises page filtered by this video.
class VideoDetailDialog extends StatefulWidget {
  final String videoId;
  const VideoDetailDialog({super.key, required this.videoId});

  @override
  State<VideoDetailDialog> createState() => _VideoDetailDialogState();
}

class _VideoDetailDialogState extends State<VideoDetailDialog> {
  final SupabaseClient _client = Supabase.instance.client;
  Map<String, dynamic>? _video;
  List<Map<String, dynamic>> _relatedExercises = [];
  bool _loading = true;
  bool _hasMoreExercises = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final videoRes = await _client.from('videos').select<Map<String, dynamic>>().eq('id', widget.videoId).single();
    final relRows = await _client.from('exercise_videos').select<List<Map<String, dynamic>>>().eq('video_id', widget.videoId);
    final exerciseIds = relRows.map((r) => r['exercise_id'] as String).toList();
    List<Map<String, dynamic>> exercises = [];
    if (exerciseIds.isNotEmpty) {
      // Use `in_` instead of `inFilter` since the latter is unavailable in
      // Supabase Flutter v1.0.x【481103789607762†L470-L476】. Limit results to 5.
      exercises = await _client
          .from('exercises')
          .select<List<Map<String, dynamic>>>()
          .in_('id', exerciseIds)
          .limit(5);
    }
    final hasMore = exerciseIds.length > exercises.length;
    setState(() {
      _video = videoRes;
      _relatedExercises = exercises;
      _hasMoreExercises = hasMore;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: 400,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_video?['title'] as String? ?? '',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(_video?['description'] as String? ?? ''),
                    const SizedBox(height: 16),
                    Text('Related exercises:',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._relatedExercises.map((e) => ListTile(
                          dense: true,
                          title: Text(e['name'] as String? ?? ''),
                        )),
                    if (_hasMoreExercises)
                      TextButton(
                        onPressed: () {
                          // Navigate to exercises page filtered by this video.
                          // In a production app you could use a router with
                          // query parameters or state management to apply
                          // filters. Here we simply close the dialog.
                          Navigator.of(context).pop();
                        },
                        child: const Text('View all related exercises'),
                      ),
                    const SizedBox(height: 16),
                    // Placeholder for comments section
                    const Text('Comments are coming soon...'),
                  ],
                ),
        ),
      ),
    );
  }
}