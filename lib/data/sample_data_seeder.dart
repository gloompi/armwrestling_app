import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Seeds the Supabase database with some example data for testing and
/// demonstration purposes. The seeding is idempotent: it runs only once
/// per device by recording a flag in [SharedPreferences]. It also
/// automatically links exercises to categories, videos to exercises and
/// workouts to exercises. If any of the inserts fail (for example due
/// to row-level security restrictions), errors are caught and ignored
/// so that the seeding process does not disrupt the normal app flow.
class SampleDataSeeder {
  static const _prefKey = 'sample_data_seeded_v1';

  /// Runs the seeding logic if it has not been run before. Returns
  /// immediately if the flag is already set. Requires an authenticated
  /// user for inserting workouts because the `workouts` table is
  /// restricted by row-level security. Exercises, videos and categories
  /// are public by default.
  static Future<void> seedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) {
      return;
    }
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    try {
      // 1. Insert categories
      final categoriesRes = await client
          .from('categories')
          .insert([
            {'name': 'Arm wrestling techniques'},
            {'name': 'Strength training'},
            {'name': 'Endurance training'},
          ])
          .select();
      final catArmId = categoriesRes[0]['id'] as String;
      final catStrengthId = categoriesRes[1]['id'] as String;
      final catEnduranceId = categoriesRes[2]['id'] as String;

      // 2. Insert exercises
      final exercisesRes = await client
          .from('exercises')
          .insert([
            {
              'name': 'Bicep Curl',
              'description': 'Basic exercise to build biceps.',
              'sets': 3,
              'reps': 10,
              'preview_url': null,
            },
            {
              'name': 'Hammer Curl',
              'description': 'Works brachioradialis and forearms.',
              'sets': 3,
              'reps': 8,
              'preview_url': null,
            },
            {
              'name': 'Wrist Curl',
              'description': 'Strengthens wrists.',
              'sets': 4,
              'reps': 12,
              'preview_url': null,
            },
          ])
          .select();
      final exBicepId = exercisesRes[0]['id'] as String;
      final exHammerId = exercisesRes[1]['id'] as String;
      final exWristId = exercisesRes[2]['id'] as String;

      // 3. Link exercises to categories (many-to-many)
      await client.from('exercise_categories').insert([
        {'exercise_id': exBicepId, 'category_id': catStrengthId},
        {'exercise_id': exHammerId, 'category_id': catStrengthId},
        {'exercise_id': exWristId, 'category_id': catEnduranceId},
      ]);

      // 4. Insert videos
      final videosRes = await client
          .from('videos')
          .insert([
            {
              'title': 'Arm Wrestling Basics',
              'description': 'Learn the basics of arm wrestling technique.',
              'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            },
            {
              'title': 'Advanced Arm Wrestling',
              'description': 'Advanced strategies and training tips.',
              'video_url': 'https://www.youtube.com/watch?v=Y2E4C5sYS58',
            },
          ])
          .select();
      final vidBasicsId = videosRes[0]['id'] as String;
      final vidAdvancedId = videosRes[1]['id'] as String;

      // 5. Link videos to exercises (exercise_videos)
      await client.from('exercise_videos').insert([
        {'exercise_id': exBicepId, 'video_id': vidBasicsId},
        {'exercise_id': exHammerId, 'video_id': vidAdvancedId},
      ]);

      // 6. Optionally link videos to categories
      await client.from('video_categories').insert([
        {'video_id': vidBasicsId, 'category_id': catArmId},
        {'video_id': vidAdvancedId, 'category_id': catStrengthId},
      ]);

      // 7. Insert workouts for the current user if logged in. Mark them as
      // public so other users can view them. Use a deterministic order.
      if (user != null) {
        final workoutsRes = await client
            .from('workouts')
            .insert([
              {
                'name': 'Beginner Arm Wrestling Workout',
                'description': 'A simple workout for beginners.',
                'is_public': true,
                'user_id': user.id,
              },
              {
                'name': 'Strength Focused Workout',
                'description': 'Workout focusing on biceps and forearms.',
                'is_public': true,
                'user_id': user.id,
              },
            ])
            .select();
        final beginnerId = workoutsRes[0]['id'] as String;
        final strengthId = workoutsRes[1]['id'] as String;
        // Link exercises to workouts via workout_exercises
        await client.from('workout_exercises').insert([
          {
            'workout_id': beginnerId,
            'exercise_id': exBicepId,
            'order': 1,
          },
          {
            'workout_id': beginnerId,
            'exercise_id': exHammerId,
            'order': 2,
          },
          {
            'workout_id': beginnerId,
            'exercise_id': exWristId,
            'order': 3,
          },
          {
            'workout_id': strengthId,
            'exercise_id': exHammerId,
            'order': 1,
          },
          {
            'workout_id': strengthId,
            'exercise_id': exBicepId,
            'order': 2,
          },
        ]);
      }

      // Record that seeding has completed
      await prefs.setBool(_prefKey, true);
    } catch (e) {
      // Ignore errors; seeding is non-essential.
    }
  }
}