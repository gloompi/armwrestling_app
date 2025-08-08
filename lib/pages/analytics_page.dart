import 'package:flutter/material.dart';

/// A placeholder analytics page. In a full production app this page
/// would display charts and statistics about your workouts, exercises and
/// progress. For now it simply displays a message indicating that the
/// feature is under construction.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: const Center(
        child: Text(
          'Analytics will be available soon. Stay tuned!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}