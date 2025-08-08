import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _exercises.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _exercises.length) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final exercise = _exercises[index];
              return ListTile(
                leading: exercise['preview_url'] != null
                    ? Image.network(exercise['preview_url'], width: 56, height: 56, fit: BoxFit.cover)
                    : const Icon(Icons.fitness_center),
                title: Text(exercise['name'] as String? ?? 'Unnamed'),
                subtitle: Text(exercise['description'] as String? ?? ''),
                onTap: () {
                  // TODO: navigate to detail page
                },
              );
            },
          ),
        ),
      ],
    );
  }
}