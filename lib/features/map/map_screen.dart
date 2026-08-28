
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/models/gpx_route.dart';

class MapScreen extends StatefulWidget {
  final GpxRoute route;

  const MapScreen({super.key, required this.route});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _platform = MethodChannel('com.example.gpx_mock_location/mock_location');
  static const _prefSpeedKey = 'simulation_speed_kmph';

  final MapController _mapController = MapController();
  final List<LatLng> _routePoints = [];
  LatLng? _currentLocation;
  Timer? _simulationTimer;
  bool _isSimulating = false;

  int _currentSegmentIndex = 0;
  double _distanceCoveredOnSegment = 0.0;
  double _simulationSpeedKmph = 50.0;
  final Distance _distance = const Distance();

  @override
  void initState() {
    super.initState();
    print("[LIFECYCLE] initState");
    _loadSpeed();

    _routePoints.addAll(widget.route.points
        .map((p) => LatLng(p.wpt.lat ?? 0.0, p.wpt.lon ?? 0.0)));

    if (_routePoints.isNotEmpty) {
      _currentLocation = _routePoints.first;
    }
    print("Route loaded with ${_routePoints.length} points.");
  }

  Future<void> _loadSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _simulationSpeedKmph = prefs.getDouble(_prefSpeedKey) ?? 50.0;
        print("Loaded speed: $_simulationSpeedKmph km/h");
      });
    }
  }

  Future<void> _saveSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefSpeedKey, speed);
    print("Saved speed: $speed km/h");
  }

  @override
  void dispose() {
    print("[LIFECYCLE] dispose");
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
  }

  void _centerMap() {
    if (_isSimulating && _currentLocation != null) {
      _mapController.move(_currentLocation!, _mapController.camera.zoom);
    } else if (_routePoints.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_routePoints),
          padding: const EdgeInsets.all(50.0),
        ),
      );
    }
  }

  Future<void> _setMockLocation(LatLng location, double speedKmph) async {
    try {
      final speedMps = speedKmph * 1000 / 3600;
      print('  [NATIVE] Setting mock location: Lat: ${location.latitude}, Lon: ${location.longitude}, Speed: $speedMps m/s');
      await _platform.invokeMethod('setMockLocation', {
        'lat': location.latitude,
        'lon': location.longitude,
        'speed': speedMps,
      });
    } on PlatformException catch (e) {
      print("[NATIVE] FAILED to set mock location: '${e.message}'. Check mock location app setting in Developer Options.");
    }
  }

  void _simulationTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }

    print("--- Tick ---");
    
    if (_currentSegmentIndex >= _routePoints.length - 1) {
      print("End of route reached in tick. Stopping simulation.");
      _simulationTimer?.cancel();
      setState(() {
        _isSimulating = false;
        _currentLocation = _routePoints.last;
        _setMockLocation(_currentLocation!, 0); 
      });
      return;
    }

    final speedMps = _simulationSpeedKmph * 1000 / 3600;
    final distanceThisTick = speedMps * 0.1;

    _distanceCoveredOnSegment += distanceThisTick;

    final startPoint = _routePoints[_currentSegmentIndex];
    final endPoint = _routePoints[_currentSegmentIndex + 1];
    final totalSegmentDistance = _distance(startPoint, endPoint);

    double t = totalSegmentDistance > 0
        ? _distanceCoveredOnSegment / totalSegmentDistance
        : 1.0;
    
    print('  Segment: $_currentSegmentIndex, Covered: ${_distanceCoveredOnSegment.toStringAsFixed(2)}m, Total: ${totalSegmentDistance.toStringAsFixed(2)}m, t: ${t.toStringAsFixed(3)}');

    while (t >= 1.0 && _currentSegmentIndex < _routePoints.length - 1) {
        print('  >> Segment completed. Moving to next segment.');
        final coveredOnPrev = totalSegmentDistance;
        _distanceCoveredOnSegment -= coveredOnPrev;
        _currentSegmentIndex++;

        if (_currentSegmentIndex >= _routePoints.length - 1) {
            print("End of route reached while processing segments. Stopping.");
            final endLocation = _routePoints.last;
            setState(() { _currentLocation = endLocation; });
            _setMockLocation(endLocation, 0);
            _simulationTimer?.cancel();
            setState(() { _isSimulating = false; });
            return;
        }

        final newStart = _routePoints[_currentSegmentIndex];
        final newEnd = _routePoints[_currentSegmentIndex + 1];
        final newTotalDist = _distance(newStart, newEnd);
        t = newTotalDist > 0 ? _distanceCoveredOnSegment / newTotalDist : 1.0;
        print('  >> New Segment: $_currentSegmentIndex, Carry-over distance: ${_distanceCoveredOnSegment.toStringAsFixed(2)}m, New t: ${t.toStringAsFixed(3)}');
    }
    
    final currentStart = _routePoints[_currentSegmentIndex];
    final currentEnd = _routePoints[_currentSegmentIndex + 1];
    final newLat = currentStart.latitude + (currentEnd.latitude - currentStart.latitude) * t;
    final newLon = currentStart.longitude + (currentEnd.longitude - currentStart.longitude) * t;
    final newLocation = LatLng(newLat, newLon);

    print('  New Location: ${newLocation.latitude.toStringAsFixed(6)}, ${newLocation.longitude.toStringAsFixed(6)}');

    setState(() {
      _currentLocation = newLocation;
    });

    _setMockLocation(newLocation, _simulationSpeedKmph);
    _mapController.move(newLocation, _mapController.camera.zoom);
  }

  void _startStopSimulation() {
    if (_routePoints.length < 2) return;

    if (_isSimulating) {
      print(">>> STOPPING SIMULATION");
      _simulationTimer?.cancel();
      if (_currentLocation != null) {
        _setMockLocation(_currentLocation!, 0); 
      }
      setState(() {
        _isSimulating = false;
      });
    } else {
      print(">>> STARTING SIMULATION");
      setState(() {
        if (_currentSegmentIndex >= _routePoints.length - 1) {
          print(">>> Resetting simulation to start.");
          _currentSegmentIndex = 0;
          _distanceCoveredOnSegment = 0.0;
          _currentLocation = _routePoints.first;
        }
        _isSimulating = true;
      });
      _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), _simulationTick);
    }
  }
  
  void _showSpeedInputDialog() {
    final TextEditingController speedController =
        TextEditingController(text: _simulationSpeedKmph.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Введите скорость'),
          content: TextField(
            controller: speedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Скорость в км/ч'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                final double? newSpeed = double.tryParse(speedController.text);
                if (newSpeed != null && newSpeed > 0) {
                  setState(() {
                    _simulationSpeedKmph = newSpeed;
                    _saveSpeed(newSpeed);
                  });
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.route.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerMap,
            tooltip: 'Центрировать',
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _routePoints.isNotEmpty
                  ? _routePoints.first
                  : const LatLng(51.5, -0.09),
              initialZoom: 13.0,
              onMapReady: () {
                print("Map ready.");
                Future.delayed(const Duration(milliseconds: 200), _centerMap);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.gpx_mock_location',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                ],
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: _currentLocation!,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40.0,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16.0,
            left: 16,
            child: Material(
              color: Theme.of(context).cardColor,
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(8.0),
                onTap: _showSpeedInputDialog,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Text(
                    '${_simulationSpeedKmph.toStringAsFixed(0)} км/ч',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            heroTag: "btn_simulation",
            onPressed: _startStopSimulation,
            tooltip: _isSimulating ? 'Пауза' : 'Старт',
            child: Icon(_isSimulating ? Icons.pause : Icons.play_arrow),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "btn_zoom_in",
            onPressed: _zoomIn,
            tooltip: 'Приблизить',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "btn_zoom_out",
            onPressed: _zoomOut,
            tooltip: 'Отдалить',
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "btn_center",
            onPressed: _centerMap,
            tooltip: 'Центрировать',
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
