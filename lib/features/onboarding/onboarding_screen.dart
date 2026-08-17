
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  bool _isMockAppSelected = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadMockAppSelection();
  }

  Future<void> _checkPermissions() async {
    final location = await Permission.location.status;
    setState(() {
      _locationStatus = location;
    });
  }

  Future<void> _loadMockAppSelection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMockAppSelected = prefs.getBool('isMockAppSelected') ?? false;
    });
  }

  Future<void> _saveMockAppSelection(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isMockAppSelected', value);
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    setState(() {
      _locationStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _locationStatus.isGranted && _isMockAppSelected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Required Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'For the app to work correctly, please complete the following steps:',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildPermissionTile(
              'Location Permission',
              'Required to provide location data.',
              _locationStatus,
              _requestLocationPermission,
            ),
            const Divider(),
            CheckboxListTile(
              title: const Text('Mock Location App'),
              subtitle: const Text('I have selected this app as the mock location app in my phone\'s Developer Options.'),
              value: _isMockAppSelected,
              onChanged: (bool? value) {
                setState(() {
                  _isMockAppSelected = value ?? false;
                });
                _saveMockAppSelection(value ?? false);
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: allGranted ? () => context.go('/') : null,
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
