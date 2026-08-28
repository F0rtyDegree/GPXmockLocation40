
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../routes/models/gpx_route.dart';

class MapScreen extends StatefulWidget {
  final GpxRoute route;

  const MapScreen({super.key, required this.route});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _routePoints = [];
  LatLng? _currentLocation; // Placeholder for user's location

  @override
  void initState() {
    super.initState();
    _routePoints.addAll(widget.route.points
        .map((p) => LatLng(p.wpt.lat ?? 0.0, p.wpt.lon ?? 0.0)));

    // Example: Set initial user location (we'll make this dynamic later)
    if (_routePoints.isNotEmpty) {
      _currentLocation = _routePoints.first;
    }
  }

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
  }

  void _centerMap() {
    if (_routePoints.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_routePoints),
          padding: const EdgeInsets.all(50.0),
        ),
      );
    }
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
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _routePoints.isNotEmpty ? _routePoints.first : const LatLng(51.5, -0.09),
          initialZoom: 13.0,
          onMapReady: () {
            // Center the map once it's ready
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
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
