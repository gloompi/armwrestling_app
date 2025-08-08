import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final randomDelay = Duration(seconds: 2 + (DateTime.now().millisecond % 4));
    _timer = Timer(randomDelay, () {
      setState(() {
        _timerRunning = false;
        _timerStatus = 'Go!';
      });
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
          leading: const Icon(Icons.analytics),
          title: const Text('Analytics'),
          onTap: () {
            // TODO: navigate to analytics page
          },
        ),
        ListTile(
          leading: const Icon(Icons.timer),
          title: const Text('Random start timer'),
          subtitle: Text(_timerStatus),
          onTap: _startRandomTimer,
        ),
      ],
    );
  }
}