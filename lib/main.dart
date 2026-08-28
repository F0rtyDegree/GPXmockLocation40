import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/routes/routes_screen.dart';

void main() {
  runApp(const MyApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'routes',
          builder: (context, state) => const RoutesScreen(),
        ),
        // Данный маршрут больше не используется для навигации,
        // так как MapScreen открывается из RoutesScreen через MaterialPageRoute
        // Но я оставлю его для возможного использования в будущем.
        GoRoute(
          path: 'map',
          // Для прямого открытия карты потребуется передача параметра.
          // Этот код потребует рефакторинга, если мы решим так делать.
          builder: (context, state) => const Scaffold(
            body: Center(
              child: Text('Карта не может быть отображена без маршрута'),
            ),
          ),
        ),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'GPX Viewer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoutesScreen(); // Просто отображаем экран маршрутов
  }
}
