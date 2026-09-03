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
  
  LatLng? _currentLocation;
  double? _currentAltitude;
  double? _currentBearing;
  int? _currentSatellites;

  Timer? _simulationTimer;
  bool _isSimulating = false;

  int _currentSegmentIndex = 0;
  double _distanceCoveredOnSegment = 0.0;
  // Default speed 5 km/h
  double _simulationSpeedKmph = 5.0;
  final Distance _distance = const Distance();

  @override
  void initState() {
    super.initState();
    _loadSpeed();

    if (widget.route.points.isNotEmpty) {
        final firstPoint = widget.route.points.first;
      _currentLocation = LatLng(firstPoint.wpt.lat ?? 0.0, firstPoint.wpt.lon ?? 0.0);
      _currentAltitude = firstPoint.wpt.ele ?? 0.0;
      _currentBearing = firstPoint.course ?? 0.0;
      _currentSatellites = firstPoint.satellites ?? 23;
    }
  }

  Future<void> _loadSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _simulationSpeedKmph = prefs.getDouble(_prefSpeedKey) ?? 5.0;
      });
    }
  }

  Future<void> _saveSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefSpeedKey, speed);
  }

  @override
  void dispose() {
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
    } else if (widget.route.points.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(widget.route.points.map((p) => LatLng(p.wpt.lat!, p.wpt.lon!)).toList()),
          padding: const EdgeInsets.all(50.0),
        ),
      );
    }
  }

  Future<void> _setMockLocation(LatLng location, double speedKmph, double altitude, double bearing, int satellites) async {
    try {
      final speedMps = speedKmph * 1000 / 3600;
      print('[NATIVE_CALL] setMockLocation: lat=${location.latitude}, lon=${location.longitude}, speed=$speedMps, altitude=$altitude, bearing=$bearing, satellites=$satellites');
      await _platform.invokeMethod('setMockLocation', {
        'lat': location.latitude,
        'lon': location.longitude,
        'speed': speedMps,
        'altitude': altitude,
        'bearing': bearing,
        'satellites': satellites,
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
    
    if (_currentSegmentIndex >= widget.route.points.length - 1) {
      _simulationTimer?.cancel();
      final lastWaypoint = widget.route.points.last;
      final lastLocation = LatLng(lastWaypoint.wpt.lat!, lastWaypoint.wpt.lon!);

      setState(() {
        _isSimulating = false;
        _currentLocation = lastLocation;
      });

      _setMockLocation(
          lastLocation, 
          0,
          lastWaypoint.wpt.ele ?? 0,
          _currentBearing ?? 0,
          _currentSatellites ?? 23
      );
      return;
    }

    final speedMps = _simulationSpeedKmph * 1000 / 3600;
    // Recalculate distance for 1 second interval
    final distanceThisTick = speedMps; 

    _distanceCoveredOnSegment += distanceThisTick;

    final startWaypoint = widget.route.points[_currentSegmentIndex];
    final endWaypoint = widget.route.points[_currentSegmentIndex + 1];
    final startPoint = LatLng(startWaypoint.wpt.lat!, startWaypoint.wpt.lon!);
    final endPoint = LatLng(endWaypoint.wpt.lat!, endWaypoint.wpt.lon!);
    final totalSegmentDistance = _distance(startPoint, endPoint);

    double t = totalSegmentDistance > 0 ? _distanceCoveredOnSegment / totalSegmentDistance : 1.0;

    while (t >= 1.0 && _currentSegmentIndex < widget.route.points.length - 1) {
        final coveredOnPrev = totalSegmentDistance;
        _distanceCoveredOnSegment -= coveredOnPrev;
        _currentSegmentIndex++;

        if (_currentSegmentIndex >= widget.route.points.length - 1) {
            final endLocation = LatLng(widget.route.points.last.wpt.lat!, widget.route.points.last.wpt.lon!);
            setState(() { _currentLocation = endLocation; });
            _setMockLocation(
                endLocation, 
                0, 
                widget.route.points.last.wpt.ele ?? 0,
                _currentBearing ?? 0,
                _currentSatellites ?? 23
            );
            _simulationTimer?.cancel();
            setState(() { _isSimulating = false; });
            return;
        }

        final newStartWpt = widget.route.points[_currentSegmentIndex];
        final newEndWpt = widget.route.points[_currentSegmentIndex + 1];
        final newTotalDist = _distance(LatLng(newStartWpt.wpt.lat!, newStartWpt.wpt.lon!), LatLng(newEndWpt.wpt.lat!, newEndWpt.wpt.lon!));
        t = newTotalDist > 0 ? _distanceCoveredOnSegment / newTotalDist : 1.0;
    }
    
    final currentStartWpt = widget.route.points[_currentSegmentIndex];
    final currentEndWpt = widget.route.points[_currentSegmentIndex + 1];
    
    final currentStartPoint = LatLng(currentStartWpt.wpt.lat!, currentStartWpt.wpt.lon!);
    final currentEndPoint = LatLng(currentEndWpt.wpt.lat!, currentEndWpt.wpt.lon!);
    
    final newLat = currentStartPoint.latitude + (currentEndPoint.latitude - currentStartPoint.latitude) * t;
    final newLon = currentStartPoint.longitude + (currentEndPoint.longitude - currentStartPoint.longitude) * t;
    final newLocation = LatLng(newLat, newLon);

    final newAltitude = currentStartWpt.wpt.ele ?? 234.0;

    final newBearing = currentStartWpt.course ?? _currentBearing ?? 0.0;
    final newSatellites = currentStartWpt.satellites ?? _currentSatellites ?? 23;

    setState(() {
      _currentLocation = newLocation;
      _currentAltitude = newAltitude;
      _currentBearing = newBearing;
      _currentSatellites = newSatellites;
    });

    _setMockLocation(newLocation, _simulationSpeedKmph, newAltitude, newBearing, newSatellites);
    _mapController.move(newLocation, _mapController.camera.zoom);
  }

  void _startStopSimulation() {
    if (widget.route.points.length < 2) return;

    if (_isSimulating) {
      _simulationTimer?.cancel();
      if (_currentLocation != null) {
        _setMockLocation(
          _currentLocation!, 
          0,
          _currentAltitude ?? 0.0,
          _currentBearing ?? 0.0,
          _currentSatellites ?? 23
        ); 
      }
      setState(() {
        _isSimulating = false;
      });
    } else {
      setState(() {
        if (_currentSegmentIndex >= widget.route.points.length - 1) {
          _currentSegmentIndex = 0;
          _distanceCoveredOnSegment = 0.0;
          final firstPoint = widget.route.points.first;
          _currentLocation = LatLng(firstPoint.wpt.lat!, firstPoint.wpt.lon!);
          _currentAltitude = firstPoint.wpt.ele ?? 0.0;
          _currentBearing = firstPoint.course ?? 0.0;
          _currentSatellites = firstPoint.satellites ?? 23;
        }
        _isSimulating = true;
      });
      // Timer ticks every 1 second
      _simulationTimer = Timer.periodic(const Duration(seconds: 1), _simulationTick);
    }
  }
  
  void _showSpeedInputDialog() {
    final TextEditingController speedController = TextEditingController(text: _simulationSpeedKmph.toStringAsFixed(0));
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
    final routeLatLngs = widget.route.points.map((p) => LatLng(p.wpt.lat!, p.wpt.lon!)).toList();

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
              initialCenter: routeLatLngs.isNotEmpty ? routeLatLngs.first : const LatLng(51.5, -0.09),
              initialZoom: 13.0,
              onMapReady: () {
                Future.delayed(const Duration(milliseconds: 200), _centerMap);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.gpx_mock_location',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routeLatLngs,
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
                      child: Transform.rotate(
                        angle: (_currentBearing ?? 0) * (3.141592653589793 / 180),
                        child: Container(
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.red,
                            size: 30.0,
                          ),
                        ),
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
