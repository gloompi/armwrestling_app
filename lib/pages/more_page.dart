import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_beep/flutter_beep.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/theme_controller.dart';
import 'appearance_page.dart';
import 'analytics_page.dart';

/// Miscellaneous page offering account settings, analytics and tools for
/// armwrestlers such as a random start timer to train reaction time.
class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  bool _timerRunning = false;
  Timer? _timer;
  String _timerStatus = 'Press Start to begin';

  // For continuous reaction timer
  bool _continuousRunning = false;
  Timer? _continuousTimer;
  String _continuousStatus = 'Tap to start continuous timer';

  void _startRandomTimer() {
    if (_timerRunning) return;
    setState(() {
      _timerRunning = true;
      _timerStatus = 'Get ready...';
    });
    // Pick a random delay between 2 and 5 seconds.
    final randomDelay =
        Duration(seconds: 2 + (DateTime.now().millisecond % 4));
    _timer = Timer(randomDelay, () {
      setState(() {
        _timerRunning = false;
        _timerStatus = 'Go!';
      });
      // Provide subtle haptic feedback when the user should react.
      HapticFeedback.lightImpact();
      // Play a beep sound so that the user can react without looking at the screen.
      FlutterBeep.beep();
    });
  }

  /// Starts or stops the continuous reaction timer. When running, it
  /// triggers at random intervals between 2 and 5 seconds, beeps and
  /// updates the status. Tapping the tile again stops the timer.
  void _toggleContinuousTimer() {
    if (_continuousRunning) {
      _continuousTimer?.cancel();
      setState(() {
        _continuousRunning = false;
        _continuousStatus = 'Tap to start continuous timer';
      });
      return;
    }
    setState(() {
      _continuousRunning = true;
      _continuousStatus = 'Waiting...';
    });
    void scheduleNext() {
      final delay = Duration(seconds: 2 + (DateTime.now().millisecond % 4));
      _continuousTimer = Timer(delay, () {
        if (!_continuousRunning) return;
        // Vibrate and beep when it's go time
        HapticFeedback.lightImpact();
        FlutterBeep.beep();
        setState(() {
          _continuousStatus = 'Go!';
        });
        // After a short moment, reset status and schedule next
        Timer(const Duration(seconds: 1), () {
          if (_continuousRunning) {
            setState(() {
              _continuousStatus = 'Waiting...';
            });
            scheduleNext();
          }
        });
      });
    }
    scheduleNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (user != null) ...[
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(user.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
          ),
        ] else ...[
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Sign in or create account'),
            onTap: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
        const Divider(),
        ListTile(
          leading: const Icon(Icons.color_lens),
          title: const Text('Appearance & Theme'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AppearancePage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.analytics),
          title: const Text('Analytics'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AnalyticsPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.timer),
          title: const Text('Reaction timer (single)'),
          subtitle: Text(_timerStatus),
          onTap: _startRandomTimer,
        ),
        ListTile(
          leading: const Icon(Icons.timelapse),
          title: const Text('Reaction timer (continuous)'),
          subtitle: Text(_continuousStatus),
          onTap: _toggleContinuousTimer,
        ),
      ],
    );
  }
}