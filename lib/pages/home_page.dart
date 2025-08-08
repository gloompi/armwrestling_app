import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

  Future<List<dynamic>> _fetchMyWorkouts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final response = await _client
        .from('workouts')
        .select<List<Map<String, dynamic>>>()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(10);
    return response;
  }

  Future<int> _fetchCompletedToday() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final response = await _client
        .from('completed_workouts')
        .select()
        .eq('user_id', user.id)
        .gte('completed_at', '$today 00:00:00')
        .lte('completed_at', '$today 23:59:59');
    return response.length;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today, ${DateFormat('EEEE, MMM d').format(DateTime.now())}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Your workouts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<dynamic>>(
            future: _fetchMyWorkouts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final workouts = snapshot.data ?? [];
              if (workouts.isEmpty) {
                return const Text('You have no workouts yet.');
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  final workout = workouts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(workout['name'] as String? ?? 'Unnamed'),
                      subtitle: Text(workout['description'] as String? ?? ''),
                      trailing: ElevatedButton(
                        onPressed: () {
                          // TODO: Navigate to workout start page.
                        },
                        child: const Text('Start'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          FutureBuilder<int>(
            future: _fetchCompletedToday(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox();
              }
              final count = snapshot.data ?? 0;
              return Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  title: const Text('Workouts completed today'),
                  trailing: Text('$count'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}