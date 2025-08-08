import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Displays a list of your workouts as well as public workouts. Provides
/// filtering and pagination. Users can add a public workout to their own
/// collection and create new workouts from scratch.
class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> with SingleTickerProviderStateMixin {
  final SupabaseClient _client = Supabase.instance.client;
  late final TabController _tabController;
  final ScrollController _myController = ScrollController();
  final ScrollController _publicController = ScrollController();
  final List<Map<String, dynamic>> _myWorkouts = [];
  final List<Map<String, dynamic>> _publicWorkouts = [];
  bool _myLoading = false;
  bool _myHasMore = true;
  int _myPage = 0;
  bool _publicLoading = false;
  bool _publicHasMore = true;
  int _publicPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _myController.addListener(() => _onScroll(isMy: true));
    _publicController.addListener(() => _onScroll(isMy: false));
    _loadMore(isMy: true);
    _loadMore(isMy: false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _myController.dispose();
    _publicController.dispose();
    super.dispose();
  }

  Future<void> _loadMore({required bool isMy}) async {
    if (isMy) {
      if (_myLoading || !_myHasMore) return;
      setState(() => _myLoading = true);
      const limit = 20;
      final user = _client.auth.currentUser;
      if (user == null) return;
      final res = await _client
          .from('workouts')
          .select<List<Map<String, dynamic>>>()
          .eq('user_id', user.id)
          .range(_myPage * limit, _myPage * limit + limit - 1)
          .order('created_at', ascending: false);
      setState(() {
        _myWorkouts.addAll(res);
        _myHasMore = res.length == limit;
        _myPage++;
        _myLoading = false;
      });
    } else {
      if (_publicLoading || !_publicHasMore) return;
      setState(() => _publicLoading = true);
      const limit = 20;
      final res = await _client
          .from('workouts')
          .select<List<Map<String, dynamic>>>()
          .eq('is_public', true)
          .range(_publicPage * limit, _publicPage * limit + limit - 1)
          .order('created_at', ascending: false);
      setState(() {
        _publicWorkouts.addAll(res);
        _publicHasMore = res.length == limit;
        _publicPage++;
        _publicLoading = false;
      });
    }
  }

  void _onScroll({required bool isMy}) {
    final controller = isMy ? _myController : _publicController;
    if (controller.position.pixels >= controller.position.maxScrollExtent - 300) {
      _loadMore(isMy: isMy);
    }
  }

  void _addPublicWorkout(Map<String, dynamic> workout) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final newWorkout = Map<String, dynamic>.from(workout);
    newWorkout['user_id'] = user.id;
    newWorkout['is_public'] = false;
    newWorkout.remove('id');
    await _client.from('workouts').insert(newWorkout);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout added to your list')),
    );
    // Reload my workouts to show the new one
    setState(() {
      _myWorkouts.clear();
      _myPage = 0;
      _myHasMore = true;
    });
    _loadMore(isMy: true);
  }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Workouts'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'My Workouts'),
                Tab(text: 'Public'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildList(isMy: true),
              _buildList(isMy: false),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              // TODO: navigate to create workout page
            },
            child: const Icon(Icons.add),
          ),
        );
      }

  Widget _buildList({required bool isMy}) {
    final items = isMy ? _myWorkouts : _publicWorkouts;
    final hasMore = isMy ? _myHasMore : _publicHasMore;
    final controller = isMy ? _myController : _publicController;
    return ListView.builder(
      controller: controller,
      itemCount: items.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final workout = items[index];
        return ListTile(
          title: Text(workout['name'] as String? ?? 'Unnamed'),
          subtitle: Text(workout['description'] as String? ?? ''),
          trailing: isMy
              ? IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // TODO: edit workout
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addPublicWorkout(workout),
                ),
          onTap: () {
            // TODO: open workout details
          },
        );
      },
    );
  }
}