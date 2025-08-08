import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'workout_session_page.dart';

/// A page for viewing or editing a workout. If [workoutId] is null,
/// the page creates a new workout when the user saves it. When
/// [editable] is false the workout details are read-only, which is
/// appropriate for public workouts. Users can add and remove exercises
/// from their own workouts and modify the name and description.
class WorkoutDetailPage extends StatefulWidget {
  final String? workoutId;
  final bool editable;

  const WorkoutDetailPage({super.key, required this.workoutId, required this.editable});

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  String? _workoutId;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _exerciseRows = [];

  @override
  void initState() {
    super.initState();
    _workoutId = widget.workoutId;
    if (_workoutId != null) {
      _loadWorkout();
    } else {
      // New workout: initialize empty state
      _loading = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkout() async {
    setState(() => _loading = true);
    try {
      // Fetch workout record
      final workout = await _client
          .from('workouts')
          .select<Map<String, dynamic>>()
          .eq('id', _workoutId)
          .single();
      // Fetch exercises joined with their details
      final rows = await _client
          .from('workout_exercises')
          .select<List<Map<String, dynamic>>>(
              'id, order, exercises!inner(id, name, description, recommended_sets, recommended_reps)')
          .eq('workout_id', _workoutId)
          .order('order', ascending: true);
      setState(() {
        _nameController.text = workout['name'] as String? ?? '';
        _descriptionController.text = workout['description'] as String? ?? '';
        _exerciseRows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  /// Saves the workout name and description. If this is a new workout it
  /// inserts a new row and stores the returned ID. Otherwise it updates
  /// the existing row. When creating a new workout the current user is
  /// assigned as the owner.
  Future<void> _saveWorkout() async {
    if (!_nameController.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a workout name.')),
      );
      return;
    }
    setState(() => _saving = true);
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save workouts.')),
      );
      return;
    }
    try {
      if (_workoutId == null) {
        // Create new workout
        final insert = await _client
            .from('workouts')
            .insert({
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'user_id': user.id,
          'is_public': false,
        }).select<Map<String, dynamic>>()
            .single();
        _workoutId = insert['id'] as String;
      } else {
        // Update existing workout
        await _client.from('workouts').update({
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
        }).eq('id', _workoutId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout saved')), 
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save workout')), 
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Opens a modal bottom sheet to select an exercise to add to this
  /// workout. When an exercise is selected it inserts a new row into
  /// `workout_exercises` with an order value after the current last.
  Future<void> _addExercise() async {
    final user = _client.auth.currentUser;
    if (user == null || _workoutId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the workout first.')),
      );
      return;
    }
    // Fetch all exercises for selection
    final exercises = await _client
        .from('exercises')
        .select<List<Map<String, dynamic>>>('id, name, description, recommended_sets, recommended_reps')
        .order('name');
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Select exercise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...exercises.map((ex) => ListTile(
                  title: Text(ex['name'] as String? ?? 'Exercise'),
                  subtitle: Text(
                    ex['description'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    // Determine next order
                    int nextOrder = 1;
                    if (_exerciseRows.isNotEmpty) {
                      final lastOrder = _exerciseRows.last['order'] as int?;
                      if (lastOrder != null) nextOrder = lastOrder + 1;
                    }
                    try {
                      await _client.from('workout_exercises').insert({
                        'workout_id': _workoutId,
                        'exercise_id': ex['id'],
                        'order': nextOrder,
                      });
                      // Reload exercises
                      await _loadWorkout();
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to add exercise')), 
                        );
                      }
                    }
                  },
                )),
          ],
        );
      },
    );
  }

  /// Removes an exercise from the workout by deleting the corresponding
  /// row in `workout_exercises`. After removal the list is reloaded.
  Future<void> _removeExercise(String id) async {
    if (_workoutId == null) return;
    try {
      await _client.from('workout_exercises').delete().eq('id', id);
      await _loadWorkout();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove exercise')), 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_workoutId == null ? 'New Workout' : 'Workout Details'),
        actions: [
          if (widget.editable)
            IconButton(
              onPressed: _saving ? null : _saveWorkout,
              icon: const Icon(Icons.save),
              tooltip: 'Save',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name field or label
                    if (widget.editable)
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          _nameController.text,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    // Description field or label
                    const SizedBox(height: 8),
                    if (widget.editable)
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          _descriptionController.text.isEmpty
                              ? 'No description'
                              : _descriptionController.text,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text('Exercises', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_exerciseRows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'No exercises yet',
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _exerciseRows.length,
                        itemBuilder: (context, index) {
                          final row = _exerciseRows[index];
                          final ex = row['exercises'] as Map<String, dynamic>;
                          final title = ex['name'] as String? ?? '';
                          final sets = ex['recommended_sets'];
                          final reps = ex['recommended_reps'];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(title),
                              subtitle: Text(
                                [
                                  if (sets != null) '${sets} sets',
                                  if (reps != null) '${reps} reps'
                                ].join('  '),
                              ),
                              trailing: widget.editable
                                  ? IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _removeExercise(row['id'] as String),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    if (widget.editable)
                      Column(
                        children: [
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _workoutId == null ? null : _addExercise,
                              icon: const Icon(Icons.add),
                              label: const Text('Add exercise'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    if (_workoutId != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _exerciseRows.isEmpty
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => WorkoutSessionPage(
                                        workoutId: _workoutId!,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Workout'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}