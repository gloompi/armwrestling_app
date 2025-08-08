import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    });
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
          title: const Text('Reaction timer'),
          subtitle: Text(_timerStatus),
          onTap: _startRandomTimer,
        ),
      ],
    );
  }
}