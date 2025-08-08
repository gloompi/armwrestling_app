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
  bool _running = false;
  bool _paused = false;

  // Duration of each exercise segment and rest segment in seconds. In a
  // future version these could come from the workout or exercise
  // definitions. For now they are fixed.
  final int _exerciseDuration = 30;
  final int _restDuration = 15;

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
            // join exercises to include name, description and preview_url
            '*, exercises!inner(name, description, preview_url)')
        .eq('workout_id', widget.workoutId)
        .order('order', ascending: true);
    setState(() {
      _exercises = rows;
      _loading = false;
    });
  }

  /// Starts or resumes the timer. While the timer is running the screen
  /// remains awake via [WakelockPlus]. When the countdown reaches zero it
  /// transitions into a rest period or advances to the next exercise.
  void _startOrResume() {
    if (_running) return;
    setState(() {
      _running = true;
      _paused = false;
    });
    WakelockPlus.enable();
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

  /// Pauses the current countdown. The timer is cancelled but the session
  /// state is preserved so it can be resumed later. The device screen will
  /// be allowed to sleep while paused.
  void _pause() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _paused = true;
    });
    WakelockPlus.disable();
  }

  /// Advances to the next exercise or ends the session if there are no
  /// remaining exercises. Resets the timer and rest state accordingly.
  void _advanceExercise() {
    // Cancel any existing timer before moving to the next exercise to avoid
    // overlapping timers that cause the countdown to tick too fast.
    _timer?.cancel();
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _isRest = false;
        _secondsLeft = 30;
      });
      // Automatically resume running for the next exercise
      _running = false;
      _paused = false;
      _startOrResume();
    } else {
      _timer?.cancel();
      WakelockPlus.disable();
      setState(() {
        _sessionFinished = true;
        _running = false;
      });
      // TODO: record completion or show a summary
    }
  }

  /// Goes back to the previous exercise if possible. Resets the timer and
  /// rest state. If the current exercise is the first one this does
  /// nothing.
  void _previousExercise() {
    _timer?.cancel();
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isRest = false;
        _secondsLeft = _exerciseDuration;
        _sessionFinished = false;
      });
      _running = false;
      _paused = false;
      _startOrResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout Session')),
        body: const Center(child: CircularProgressIndicator()),
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
    final currentExercisesMap = current['exercises'] as Map<String, dynamic>;
    final currentName = currentExercisesMap['name'] as String? ?? 'Exercise';
    final currentPreviewUrl = currentExercisesMap['preview_url'] as String?;
    final currentSets = currentExercisesMap['recommended_sets'] as int?;
    final currentReps = currentExercisesMap['recommended_reps'] as int?;
    final nextName = _currentIndex + 1 < _exercises.length
        ? (((_exercises[_currentIndex + 1]['exercises'] as Map<String, dynamic>)['name']) as String? ?? '')
        : null;
    final nextPreviewUrl = _currentIndex + 1 < _exercises.length
        ? (_exercises[_currentIndex + 1]['exercises'] as Map<String, dynamic>)['preview_url'] as String?
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Session')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _sessionFinished
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Workout complete!',
                    style: TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Finish'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Exercise name or rest label and optional sets/reps
                  Text(
                    _isRest ? 'Rest' : currentName,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (!_isRest && (currentSets != null || currentReps != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          if (currentSets != null) '${currentSets} sets',
                          if (currentReps != null) '${currentReps} reps'
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Countdown ring with timer
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: CircularProgressIndicator(
                              value: 1 -
                                  _secondsLeft /
                                      (_isRest ? _restDuration : _exerciseDuration),
                              strokeWidth: 8,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant,
                              valueColor: AlwaysStoppedAnimation(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(_secondsLeft),
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Small preview of current exercise during exercise phase
                  if (!_isRest && currentPreviewUrl != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            currentPreviewUrl,
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (nextName != null)
                          Text(
                            'Next: $nextName',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  if (_isRest && nextName != null)
                    Text(
                      'Next: $nextName',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 24),
                  // Controls row: previous, play/pause/resume, next
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        iconSize: 32,
                        onPressed: _previousExercise,
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(
                          _running
                              ? Icons.pause
                              : (_paused ? Icons.play_arrow : Icons.play_arrow),
                        ),
                        iconSize: 48,
                        onPressed: _running ? _pause : _startOrResume,
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        iconSize: 32,
                        onPressed: _advanceExercise,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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