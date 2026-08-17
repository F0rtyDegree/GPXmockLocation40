import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LatLng _initialMarkerPosition = const LatLng(55.7522, 37.6156); // Red Square

  LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    _initLocationService();
  }

  void _initLocationService() async {
    final location = Location();
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Check if location service is enabled
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return; // Exit if user doesn't enable service
      }
    }

    // Check for location permissions
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return; // Exit if user doesn't grant permission
      }
    }

    // Listen for location changes
    location.onLocationChanged.listen((LocationData currentLocation) {
      if (mounted) {
        setState(() {
          _currentLocation = currentLocation;
        });
      }
    });
  }

  void _centerOnUserLocation() {
    final location = _currentLocation;
    if (location != null) {
      // The latitude and longitude fields are non-nullable doubles.
      // A null check on 'location' is sufficient.
      _mapController.move(
        LatLng(location.latitude, location.longitude),
        15.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Marker> markers = [
      Marker(
        width: 80.0,
        height: 80.0,
        point: _initialMarkerPosition,
        child: const Icon(
          Icons.location_pin,
          color: Colors.red,
          size: 40.0,
        ),
      ),
    ];

    final location = _currentLocation;
    // The latitude and longitude fields are non-nullable doubles.
    // A null check on 'location' is sufficient.
    if (location != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: LatLng(location.latitude, location.longitude),
          child: const Icon(
            Icons.person_pin_circle,
            color: Colors.blue,
            size: 40.0,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialMarkerPosition,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            right: 16.0,
            bottom: 16.0,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'center_on_user',
                  onPressed: _centerOnUserLocation,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
