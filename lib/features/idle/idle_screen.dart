import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class IdleScreen extends StatelessWidget {
  const IdleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Joystick'),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildMenuButton(
            context,
            icon: Icons.map,
            label: 'Map',
            onPressed: () => context.go('/map'),
          ),
          _buildMenuButton(
            context,
            icon: Icons.timeline,
            label: 'Routes',
            onPressed: () => context.go('/routes'),
          ),
          _buildMenuButton(
            context,
            icon: Icons.star,
            label: 'Favorites',
            onPressed: () => context.go('/favorites'),
          ),
          _buildMenuButton(
            context,
            icon: Icons.settings,
            label: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
          _buildMenuButton(
            context,
            icon: Icons.group,
            label: 'Group Sync',
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
