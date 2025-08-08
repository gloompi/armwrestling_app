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
              'id, order, exercises!inner(id, name, description, recommended_sets, recommended_reps, preview_url)')
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

  /// Builds the hero section for the workout detail page. It displays the
  /// preview image of the first exercise if available. If no exercises
  /// exist or no preview is present, a placeholder box with an icon is
  /// shown. The hero provides a visual anchor at the top of the page.
  Widget _buildWorkoutHero(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Try to use the preview of the first exercise if available.
    String? previewUrl;
    if (_exerciseRows.isNotEmpty) {
      final ex = _exerciseRows.first['exercises'] as Map<String, dynamic>;
      previewUrl = ex['preview_url'] as String?;
    }
    return previewUrl != null
        ? Image.network(
            previewUrl,
            height: 240,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 240,
              width: double.infinity,
              color: colorScheme.surfaceVariant,
              child: const Icon(Icons.fitness_center, size: 64),
            ),
          )
        : Container(
            height: 240,
            width: double.infinity,
            color: colorScheme.surfaceVariant,
            child: const Icon(Icons.fitness_center, size: 64),
          );
  }

  /// Creates a new private copy of a public workout and its exercises.
  Future<void> _copyPublicWorkout() async {
    final user = _client.auth.currentUser;
    if (user == null || _workoutId == null) return;
    // Fetch current workout record
    final workout = await _client
        .from('workouts')
        .select<Map<String, dynamic>>()
        .eq('id', _workoutId)
        .single();
    // Insert a copy with the current user as owner and is_public=false
    final newWorkout = Map<String, dynamic>.from(workout);
    newWorkout.remove('id');
    newWorkout['user_id'] = user.id;
    newWorkout['is_public'] = false;
    final inserted = await _client
        .from('workouts')
        .insert(newWorkout)
        .select<Map<String, dynamic>>()
        .single();
    final newId = inserted['id'] as String;
    // Copy exercises
    final rows = await _client
        .from('workout_exercises')
        .select<List<Map<String, dynamic>>>('exercise_id, order')
        .eq('workout_id', _workoutId)
        .order('order');
    if (rows.isNotEmpty) {
      final copyRows = rows
          .map((row) => {
                'workout_id': newId,
                'exercise_id': row['exercise_id'],
                'order': row['order'],
              })
          .toList();
      try {
        await _client.from('workout_exercises').insert(copyRows);
      } catch (_) {
        // ignore
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your workouts')), 
      );
      // Navigate to the new workout detail page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutDetailPage(
            workoutId: newId,
            editable: true,
          ),
        ),
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
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero image using first exercise preview if available
                  _buildWorkoutHero(context),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title and description
                        if (widget.editable)
                          TextField(
                            controller: _nameController,
                            decoration:
                                const InputDecoration(labelText: 'Workout name'),
                            style: theme.textTheme.headlineSmall,
                          )
                        else
                          Text(
                            _nameController.text,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 8),
                        if (widget.editable)
                          TextField(
                            controller: _descriptionController,
                            decoration:
                                const InputDecoration(labelText: 'Description'),
                            maxLines: 3,
                          )
                        else
                          Text(
                            _descriptionController.text.isEmpty
                                ? 'No description'
                                : _descriptionController.text,
                            style: theme.textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 24),
                        // Exercise list
                        Text('Exercises',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (_exerciseRows.isEmpty)
                          Text('No exercises yet',
                              style: theme.textTheme.bodyMedium)
                        else
                          Column(
                            children: [
                              ..._exerciseRows.asMap().entries.map((entry) {
                                final index = entry.key;
                                final row = entry.value;
                                final ex = row['exercises'] as Map<String, dynamic>;
                                final sets = ex['recommended_sets'];
                                final reps = ex['recommended_reps'];
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: theme
                                          .colorScheme.primaryContainer,
                                      child: Text(
                                        '${index + 1}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                color: theme.colorScheme.onPrimaryContainer),
                                      ),
                                    ),
                                    title: Text(ex['name'] as String? ?? ''),
                                    subtitle: Text([
                                      if (sets != null) '${sets} sets',
                                      if (reps != null) '${reps} reps'
                                    ].join('  ')),
                                    trailing: widget.editable
                                        ? IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () => _removeExercise(row['id'] as String),
                                          )
                                        : null,
                                  ),
                                );
                              }),
                            ],
                          ),
                        if (widget.editable)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: OutlinedButton.icon(
                              onPressed:
                                  _workoutId == null ? null : _addExercise,
                              icon: const Icon(Icons.add),
                              label: const Text('Add exercise'),
                            ),
                          ),
                        const SizedBox(height: 24),
                        // Action buttons
                        if (_workoutId != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Start workout button
                              ElevatedButton.icon(
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
                              const SizedBox(height: 8),
                              // If not editable (public workout), allow user to
                              // copy to their workouts
                              if (!widget.editable)
                                ElevatedButton.icon(
                                  onPressed: _copyPublicWorkout,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add to My Workouts'),
                                ),
                            ],
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