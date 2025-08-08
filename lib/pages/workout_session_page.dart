import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Page that guides the user through a workout session. It displays each
/// exercise in the workout one by one with a countdown timer for both the
/// exercise and a rest period. A preview of the next exercise is also
/// shown. When all exercises have been completed the page pops and a
/// callback could be used to mark the workout as finished.
class WorkoutSessionPage extends StatefulWidget {
  final String workoutId;
  const WorkoutSessionPage({super.key, required this.workoutId});

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String, dynamic>> _exercises = [];
  int _currentIndex = 0;
  bool _loading = true;
  Timer? _timer;
  int _secondsLeft = 30;
  bool _isRest = false;
  bool _sessionFinished = false;

  @override
  void initState() {
    super.initState();
    // Keep the device screen awake during a workout session. This will be
    // released in dispose() below.
    WakelockPlus.enable();
    _loadExercises();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Release wakelock when leaving the page or when the session ends.
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    // Fetch exercises for this workout ordered by the order column. Join with
    // exercises table to get names and descriptions.
    final rows = await _client
        .from('workout_exercises')
        .select<List<Map<String, dynamic>>>(
            '*, exercises!inner(name, description)')
        .eq('workout_id', widget.workoutId)
        .order('order', ascending: true);
    setState(() {
      _exercises = rows;
      _loading = false;
    });
  }

  void _startOrResume() {
    // Start or resume the countdown timer. When the timer completes, either
    // transition to rest period or move to the next exercise.
    if (_timer != null && _timer!.isActive) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        if (_isRest) {
          _advanceExercise();
        } else {
          setState(() {
            _isRest = true;
            _secondsLeft = 15; // rest period length
          });
          _startOrResume();
        }
      }
    });
  }

  void _advanceExercise() {
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _isRest = false;
        _secondsLeft = 30;
      });
      _startOrResume();
    } else {
      setState(() {
        _sessionFinished = true;
      });
      // Optionally record completion here
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: AppBar(title: Text('Workout Session')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // If there are no exercises, show a message
    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout Session')),
        body: const Center(child: Text('No exercises in this workout.')),
      );
    }
    final current = _exercises[_currentIndex];
    final currentName = (current['exercises'] as Map<String, dynamic>)['name'] as String? ?? 'Exercise';
    final nextName = _currentIndex + 1 < _exercises.length
        ? (( _exercises[_currentIndex + 1]['exercises'] as Map<String, dynamic>)['name'] as String? ?? '')
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Session')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _sessionFinished
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Workout complete!', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Finish'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isRest ? 'Rest' : currentName,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _formatTime(_secondsLeft),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _startOrResume,
                    child: const Text('Start / Resume'),
                  ),
                  const SizedBox(height: 24),
                  if (nextName != null)
                    Text(
                      'Next: $nextName',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}