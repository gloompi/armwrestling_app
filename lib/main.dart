import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart' as provider;
import 'dart:async';
import 'pages/home_page.dart';
import 'pages/exercises_page.dart';
import 'pages/workouts_page.dart';
import 'pages/videos_page.dart';
import 'pages/more_page.dart';
import 'pages/login_page.dart';

// Theme support
import 'theme/theme_controller.dart';

// Data seeding utility to populate the database with example data on first run.
import 'data/sample_data_seeder.dart';

/// Entry point for the Armwrestling fitness application.
///
/// The application uses Supabase for authentication and data storage.
/// Be sure to replace the placeholder `supabaseUrl` and `supabaseAnonKey`
/// below with the values from your Supabase project's API settings.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://ldofopesehnkgwbmpffa.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxkb2ZvcGVzZWhua2d3Ym1wZmZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ2NDA5NjgsImV4cCI6MjA3MDIxNjk2OH0.wlRHtXpg3gMv7_l3e4WX9EZZ0VGOr5aG4h99LLtfdpY';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  // Load persisted theme preferences before running the app so that the UI
  // uses the correct colour scheme on startup.
  final themeController = ThemeController();
  await themeController.load();
  runApp(
    provider.ChangeNotifierProvider<ThemeController>.value(
      value: themeController,
      child: const MyApp(),
    ),
  );
}

/// Root widget for the application. Sets up routing and theming.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = provider.Provider.of<ThemeController>(context);
    return MaterialApp(
      title: 'Armwrestling Fitness',
      themeMode: themeController.mode,
      theme: themeController.lightTheme,
      darkTheme: themeController.darkTheme,
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
      // When a new session becomes available (user logs in) seed sample data.
      final current = Supabase.instance.client.auth.currentSession;
      if (current != null) {
        SampleDataSeeder.seedIfNeeded();
      }
    });

    // If the user is already logged in when the app starts, kick off
    // seeding of sample data in the background. The seeding function
    // internally checks a flag in SharedPreferences to avoid inserting
    // duplicate records.
    final existingSession = Supabase.instance.client.auth.currentSession;
    if (existingSession != null) {
      // Call without awaiting to avoid blocking initState
      SampleDataSeeder.seedIfNeeded();
    }
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
  // Start on the Home page (index 2) because the order of pages has changed.
  int _index = 2;
  // Reorder pages so that the bottom navigation appears as:
  // Exercises, Workouts, Home, Videos, More. The index of Home is 2.
  final _pages = const [
    ExercisesPage(),
    WorkoutsPage(),
    HomePage(),
    VideosPage(),
    MorePage(),
  ];
  final _titles = const [
    'Exercises',
    'Workouts',
    'Home',
    'Videos',
    'More',
  ];

  /// Builds a navigation drawer with links to each section of the app. The
  /// drawer is available from any page via the hamburger icon in the app bar.
  Widget _buildDrawer(BuildContext context) {
    // Fetch the current user to display email or a placeholder. If there is
    // no logged in user (shouldn't happen because RootPage gates access),
    // show "Guest". Supabase may return null if the session expired.
    final user = Supabase.instance.client.auth.currentUser;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text(''),
            accountEmail: Text(user?.email ?? 'Guest'),
            currentAccountPicture: const CircleAvatar(
              child: Icon(Icons.person),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text('Exercises'),
            onTap: () {
              setState(() => _index = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.view_list),
            title: const Text('Workouts'),
            onTap: () {
              setState(() => _index = 1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              setState(() => _index = 2);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Videos'),
            onTap: () {
              setState(() => _index = 3);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.more_horiz),
            title: const Text('More'),
            onTap: () {
              setState(() => _index = 4);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The app bar shows the current page title and automatically displays
      // a hamburger icon when a drawer is provided. Tapping the icon opens
      // the navigation drawer defined below.
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: _buildDrawer(context),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        showUnselectedLabels: true,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Exercises',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.view_list),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            // Make the home icon larger to stand out as the central tab. Use
            // `activeIcon` for an even larger size when selected.
            icon: const Icon(Icons.home, size: 32),
            activeIcon: const Icon(Icons.home, size: 40),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'Videos',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}