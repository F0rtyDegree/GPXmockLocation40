import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:location_joystick/features/onboarding/onboarding_screen.dart';
import 'package:location_joystick/features/idle/idle_screen.dart';
import 'package:location_joystick/features/map/map_screen.dart'; // Import the new map screen

// Placeholder for the theme provider
class ThemeProvider with ChangeNotifier {
  final ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
}

// Placeholder screens
class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Routes')));
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Favorites')));
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')));
}

// GoRouter configuration
final _router = GoRouter(
  routes: [
    GoRoute(
        path: '/',
        builder: (context, state) => const IdleScreen(),
        routes: [
          GoRoute(
            path: 'map',
            builder: (context, state) => const MapScreen(), // Use the real map screen
          ),
          GoRoute(
            path: 'routes',
            builder: (context, state) => const RoutesScreen(),
          ),
          GoRoute(
            path: 'favorites',
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ]),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) async {
    final allPermissionsGranted = await _checkAllPermissions();
    final isOnboarding = state.fullPath == '/onboarding';

    if (!allPermissionsGranted && !isOnboarding) {
      return '/onboarding';
    }

    if (allPermissionsGranted && isOnboarding) {
      return '/';
    }

    return null;
  },
);

Future<bool> _checkAllPermissions() async {
  final locationStatus = await Permission.location.status;
  final overlayStatus = await Permission.systemAlertWindow.status;
  // Checking for mock location app is more complex, so we'll simplify for now.
  // We will consider it granted if the other two are.
  return locationStatus.isGranted && overlayStatus.isGranted;
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Location Joystick',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      themeMode: Provider.of<ThemeProvider>(context).themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
