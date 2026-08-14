
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _overlayStatus = PermissionStatus.denied;
  // Mock location doesn't have a status, it's a developer setting.
  // We'll need a different way to check it. For now, we'll just have a button to open the settings.

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final location = await Permission.location.status;
    final overlay = await Permission.systemAlertWindow.status;
    setState(() {
      _locationStatus = location;
      _overlayStatus = overlay;
    });
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    setState(() {
      _locationStatus = status;
    });
  }

  Future<void> _requestOverlayPermission() async {
    final status = await Permission.systemAlertWindow.request();
    setState(() {
      _overlayStatus = status;
    });
  }
  
  void _openDeveloperSettings() {
    // This is a bit tricky and platform-specific.
    // For now, we'll just show a dialog with instructions.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enable Mock Locations"),
        content: const Text("1. Go to your phone's Settings.\n2. Find 'Developer options'.\n3. Scroll down to 'Select mock location app' and choose 'Location Joystick'."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _locationStatus.isGranted && _overlayStatus.isGranted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Required Permissions'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'For the app to work correctly, please grant the following permissions:',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildPermissionTile(
              'Location',
              'Required to show the map and your position.',
              _locationStatus,
              _requestLocationPermission,
            ),
            _buildPermissionTile(
              'Display over other apps',
              'Required to show the joystick overlay.',
              _overlayStatus,
              _requestOverlayPermission,
            ),
            ListTile(
              title: const Text('Mock Location App'),
              subtitle: const Text('Required to simulate your location.'),
              trailing: ElevatedButton(
                onPressed: _openDeveloperSettings,
                child: const Text('Open Settings'),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: allGranted ? () => context.go('/idle') : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile(
      String title, String subtitle, PermissionStatus status, VoidCallback onPressed) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.isGranted ? Icons.check_circle : Icons.cancel,
            color: status.isGranted ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          if (!status.isGranted)
            ElevatedButton(
              onPressed: onPressed,
              child: const Text('Grant'),
            ),
        ],
      ),
    );
  }
}

