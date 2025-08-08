import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'pages/home_page.dart';
import 'pages/exercises_page.dart';
import 'pages/workouts_page.dart';
import 'pages/videos_page.dart';
import 'pages/more_page.dart';
import 'pages/login_page.dart';

/// Entry point for the Armwrestling fitness application.
///
/// The application uses Supabase for authentication and data storage.
/// Be sure to replace the placeholder `supabaseUrl` and `supabaseAnonKey`
/// below with the values from your Supabase project's API settings.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://ldofopesenhkgwbmpffa.supabase.co';
  const supabaseAnonKey = '<YOUR_SUPABASE_ANON_KEY_HERE>';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const MyApp());
}

/// Root widget for the application. Sets up routing and theming.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Armwrestling Fitness',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const RootPage(),
      routes: {
        '/home': (_) => const HomePage(),
        '/exercises': (_) => const ExercisesPage(),
        '/workouts': (_) => const WorkoutsPage(),
        '/videos': (_) => const VideosPage(),
        '/more': (_) => const MorePage(),
      },
    );
  }
}

/// Decides whether to show the login screen or the main navigation
/// depending on whether a user is signed in.
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  // Supabase emits AuthState objects when the auth state changes. Use a generic
  // type here rather than AuthStateChangeEvent because the SDK does not
  // expose a class named `AuthStateChangeEvent` in v1.x. Listening on
  // `onAuthStateChange` with `dynamic` ensures compatibility across SDK
  // versions.
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    // Listen to authentication state changes so we rebuild when a user signs in
    // or out. Without this, the user would need to manually refresh the app
    // after logging in【481103789607762†L470-L476】.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Trigger a rebuild when the auth state changes. The callback receives
      // an AuthState object containing `event` and `session` properties. We
      // don't need those here; simply rebuild the widget tree if the widget
      // is still mounted.
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const LoginPage();
    }
    return const MainNavigation();
  }
}

/// Main bottom navigation scaffold.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;
  final _pages = const [
    HomePage(),
    ExercisesPage(),
    WorkoutsPage(),
    VideosPage(),
    MorePage(),
  ];
  final _titles = const [
    'Home',
    'Exercises',
    'Workouts',
    'Videos',
    'More',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Exercises'),
          BottomNavigationBarItem(icon: Icon(Icons.view_list), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'Videos'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}