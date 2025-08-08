import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'exercise_detail_page.dart';

/// Displays a paginated, filterable list of exercises. Users can select a
/// category filter via horizontally scrollable chips and scroll through
/// exercises infinitely.
class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _exercises = [];
  final List<Map<String, dynamic>> _categories = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String? _selectedCategoryId;

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

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    const limit = 20;
    final query = _client.from('exercises').select<List<Map<String, dynamic>>>();
    if (_selectedCategoryId != null) {
      // Filter via a subquery on exercise_categories. In Supabase Flutter v1 the
      // `inFilter` method is not available; instead use `in_` to perform an
      // `IN` filter. See the Supabase docs for details【481103789607762†L470-L476】.
      final ids = await _exerciseIdsForCategory(_selectedCategoryId!);
      if (ids.isNotEmpty) {
        query.in_('id', ids);
      }
    }
    final res = await query.order('name').range(_page * limit, _page * limit + limit - 1);
    setState(() {
      _exercises.addAll(res);
      _page++;
      _hasMore = res.length == limit;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _exercises.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<List<String>> _exerciseIdsForCategory(String categoryId) async {
    final rows = await _client
        .from('exercise_categories')
        .select<List<Map<String, dynamic>>>()
        .eq('category_id', categoryId);
    return rows.map<String>((row) => row['exercise_id'] as String).toList();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_loading) {
      _loadMore();
    }
  }

  void _onSelectCategory(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _exercises.clear();
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
                  selected: _selectedCategoryId == null,
                  onSelected: (_) => _onSelectCategory(null),
                ),
              ),
              ..._categories.map((cat) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(cat['name'] as String? ?? ''),
                      selected: _selectedCategoryId == cat['id'],
                      onSelected: (_) => _onSelectCategory(cat['id'] as String),
                    ),
                  )),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _exercises.isEmpty && _loading
                ? ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return Shimmer.fromColors(
                        baseColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                        highlightColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                        child: Container(
                          height: 88,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _exercises.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _exercises.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final exercise = _exercises[index];
                      return SizedBox(
                        height: 88,
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(8),
                            leading: exercise['preview_url'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      exercise['preview_url'],
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.fitness_center,
                                              size: 40),
                                    ),
                                  )
                                : const Icon(Icons.fitness_center, size: 40),
                            title: Text(
                              exercise['name'] as String? ?? 'Unnamed',
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              exercise['description'] as String? ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              // Navigate to exercise details page
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ExerciseDetailPage(
                                    exerciseId: exercise['id'] as String,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}