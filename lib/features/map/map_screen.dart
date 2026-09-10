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
  static const _prefUseTrackSpeedKey = 'use_track_speed';

  final MapController _mapController = MapController();
  
  LatLng? _currentLocation;
  double? _currentAltitude;
  double? _currentBearing;
  int? _currentSatellites;

  Timer? _simulationTimer;
  bool _isSimulating = false;

  int _currentSegmentIndex = 0;
  double _distanceCoveredOnSegment = 0.0;
  
  double _simulationSpeedKmph = 5.0;
  double _currentSpeedKmph = 0.0;
  bool _useTrackSpeed = false;
  bool _trackHasTimeData = false;
  DateTime? _simulationStartTime;

  final Distance _distance = const Distance();

  @override
  void initState() {
    super.initState();
    _loadPreferences();

    if (widget.route.points.isNotEmpty) {
      final firstPoint = widget.route.points.first;
      _currentLocation = LatLng(firstPoint.wpt.lat ?? 0.0, firstPoint.wpt.lon ?? 0.0);
      _currentAltitude = firstPoint.wpt.ele ?? 0.0;
      _currentBearing = firstPoint.course ?? 0.0;
      _currentSatellites = firstPoint.satellites ?? 23;

      // A track has time data if all points have a non-null time.
      _trackHasTimeData = widget.route.points.every((p) => p.wpt.time != null);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _simulationSpeedKmph = prefs.getDouble(_prefSpeedKey) ?? 5.0;
        _useTrackSpeed = prefs.getBool(_prefUseTrackSpeedKey) ?? false;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefSpeedKey, _simulationSpeedKmph);
    await prefs.setBool(_prefUseTrackSpeedKey, _useTrackSpeed);
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
    if (_useTrackSpeed && _trackHasTimeData) {
      _timeBasedSimulationTick(timer);
    } else {
      _fixedSpeedSimulationTick(timer);
    }
  }

  void _timeBasedSimulationTick(Timer timer) {
    if (!mounted || _simulationStartTime == null || !_isSimulating) {
      timer.cancel();
      return;
    }

    final routePoints = widget.route.points;
    // This assumes the first point has a time, which is checked by _trackHasTimeData
    final trackStartTime = routePoints.first.wpt.time!;
    final elapsedRealTime = DateTime.now().difference(_simulationStartTime!);
    final currentTargetTrackTime = trackStartTime.add(elapsedRealTime);

    // Find the current segment index based on the elapsed time
    while (_currentSegmentIndex < routePoints.length - 2 &&
          (routePoints[_currentSegmentIndex + 1].wpt.time?.isBefore(currentTargetTrackTime) ?? false)) {
      _currentSegmentIndex++;
    }
    
    // End of simulation
    if (currentTargetTrackTime.isAfter(routePoints.last.wpt.time!)) {
      _simulationTimer?.cancel();
      final lastWaypoint = routePoints.last;
      final lastLocation = LatLng(lastWaypoint.wpt.lat!, lastWaypoint.wpt.lon!);

      setState(() {
        _isSimulating = false;
        _currentLocation = lastLocation;
        _currentSegmentIndex = routePoints.length - 1; // Mark as finished
        _currentSpeedKmph = 0.0;
      });

      _setMockLocation(
          lastLocation, 0, lastWaypoint.wpt.ele ?? 0, _currentBearing ?? 0, _currentSatellites ?? 23);
      return;
    }

    final p1 = routePoints[_currentSegmentIndex];
    final p2 = routePoints[_currentSegmentIndex + 1];

    final segmentStartTime = p1.wpt.time!;
    final segmentEndTime = p2.wpt.time!;
    final segmentDuration = segmentEndTime.difference(segmentStartTime);

    double t = 0.0; // Interpolation factor
    if (segmentDuration.inMilliseconds > 0) {
      t = currentTargetTrackTime.difference(segmentStartTime).inMilliseconds / segmentDuration.inMilliseconds;
    }
    t = t.clamp(0.0, 1.0);

    final startPoint = LatLng(p1.wpt.lat!, p1.wpt.lon!);
    final endPoint = LatLng(p2.wpt.lat!, p2.wpt.lon!);

    final newLat = startPoint.latitude + (endPoint.latitude - startPoint.latitude) * t;
    final newLon = startPoint.longitude + (endPoint.longitude - startPoint.longitude) * t;
    final newLocation = LatLng(newLat, newLon);

    final distance = _distance(startPoint, endPoint);
    final speedMps = (segmentDuration.inSeconds > 0) ? distance / segmentDuration.inSeconds : 0.0;
    final speedKmph = speedMps * 3.6;

    final newAltitude = p1.wpt.ele ?? 234.0;
    final newBearing = p1.course ?? _currentBearing ?? 0.0;
    final newSatellites = p1.satellites ?? _currentSatellites ?? 23;

    setState(() {
      _currentLocation = newLocation;
      _currentAltitude = newAltitude;
      _currentBearing = newBearing;
      _currentSatellites = newSatellites;
      _currentSpeedKmph = speedKmph;
    });

    _setMockLocation(newLocation, speedKmph, newAltitude, newBearing, newSatellites);
    _mapController.move(newLocation, _mapController.camera.zoom);
  }

  void _fixedSpeedSimulationTick(Timer timer) {
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
            _setMockLocation(
                endLocation, 
                0, 
                widget.route.points.last.wpt.ele ?? 0,
                _currentBearing ?? 0,
                _currentSatellites ?? 23
            );
            _simulationTimer?.cancel();
            setState(() {
              _currentLocation = endLocation;
              _isSimulating = false;
              _currentSpeedKmph = 0.0;
            });
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
      _currentSpeedKmph = _simulationSpeedKmph;
    });

    _setMockLocation(newLocation, _simulationSpeedKmph, newAltitude, newBearing, newSatellites);
    _mapController.move(newLocation, _mapController.camera.zoom);
  }

  void _startStopSimulation() {
    if (widget.route.points.length < 2) return;

    if (_isSimulating) {
      // PAUSE
      _simulationTimer?.cancel();
      if (_currentLocation != null) {
        _setMockLocation(
          _currentLocation!,
          0,
          _currentAltitude ?? 0.0,
          _currentBearing ?? 0.0,
          _currentSatellites ?? 23,
        );
      }
      setState(() {
        _isSimulating = false;
        _currentSpeedKmph = 0.0;
      });
    } else {
      // PLAY (Restart simulation from the beginning)
      _currentSegmentIndex = 0;
      _distanceCoveredOnSegment = 0.0;
      final firstPoint = widget.route.points.first;
      setState(() {
        _currentLocation = LatLng(firstPoint.wpt.lat!, firstPoint.wpt.lon!);
        _currentAltitude = firstPoint.wpt.ele ?? 0.0;
        _currentBearing = firstPoint.course ?? 0.0;
        _currentSatellites = firstPoint.satellites ?? 23;
      });

      if (_useTrackSpeed && _trackHasTimeData) {
        _simulationStartTime = DateTime.now();
      }
      
      setState(() {
        _isSimulating = true;
      });

      _simulationTimer?.cancel();
      _simulationTimer = Timer.periodic(
        const Duration(seconds: 1),
        _simulationTick,
      );
    }
  }
  
  void _showSpeedInputDialog() {
    final TextEditingController speedController =
        TextEditingController(text: _simulationSpeedKmph.toStringAsFixed(0));
    
    bool dialogUseTrackSpeed = _useTrackSpeed;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Настройки скорости'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Скорость трека'),
                      Switch(
                        value: dialogUseTrackSpeed,
                        onChanged: _trackHasTimeData
                            ? (bool value) {
                                setDialogState(() {
                                  dialogUseTrackSpeed = value;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                  TextField(
                    controller: speedController,
                    enabled: !dialogUseTrackSpeed,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Скорость в км/ч'),
                    autofocus: true,
                  ),
                ],
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
                    setState(() {
                      _useTrackSpeed = dialogUseTrackSpeed;
                      if (!_useTrackSpeed && newSpeed != null && newSpeed > 0) {
                        _simulationSpeedKmph = newSpeed;
                      }
                      _savePreferences();
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeLatLngs = widget.route.points.map((p) => LatLng(p.wpt.lat!, p.wpt.lon!)).toList();

    String speedLabel;
    if (_isSimulating) {
      speedLabel = '${_currentSpeedKmph.toStringAsFixed(0)} км/ч';
    } else {
      if (_useTrackSpeed && _trackHasTimeData) {
        speedLabel = '0 км/ч';
      } else {
        speedLabel = '${_simulationSpeedKmph.toStringAsFixed(0)} км/ч';
      }
    }

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
                    speedLabel,
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
