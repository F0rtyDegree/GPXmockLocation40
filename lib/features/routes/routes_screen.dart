// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../map/map_screen.dart';
import 'models/gpx_route.dart';
import 'models/gpx_waypoint.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final List<GpxRoute> _routes = [];
  static const String _routesKey = 'gpx_routes';

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList(_routesKey) ?? [];
    setState(() {
      _routes.clear();
      for (var routeJson in routesJson) {
        try {
          final routeMap = jsonDecode(routeJson) as Map<String, dynamic>;
          _routes.add(GpxRoute.fromJson(routeMap));
        } catch (e) {
          if (kDebugMode) {
            print('[GPX_LOAD] Error decoding route: $e');
          }
        }
      }
    });
    if (kDebugMode) {
      print('[GPX_LOAD] Loaded ${_routes.length} routes.');
    }
  }

  Future<void> _saveRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = _routes.map((route) => jsonEncode(route.toJson())).toList();
    await prefs.setStringList(_routesKey, routesJson);
    if (kDebugMode) {
      print('[GPX_SAVE] Saved ${_routes.length} routes.');
    }
  }

  Future<void> _deleteRoute(GpxRoute route, int index) async {
    setState(() {
      _routes.remove(route);
    });
    await _saveRoutes();

    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Маршрут "${route.name}" удален'),
                action: SnackBarAction(
                    label: 'ОТМЕНА',
                    onPressed: () {
                        _undoDelete(route, index);
                    },
                ),
            ),
        );
    }
  }

  void _undoDelete(GpxRoute route, int index) {
    setState(() {
      _routes.insert(index, route);
    });
    _saveRoutes();
  }

  Future<String?> _getRouteNameFromDialog(String defaultName) async {
    final controller = TextEditingController(text: defaultName.replaceAll('.gpx', ''));
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Название маршрута'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Введите название'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importGpxFile() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        return;
      }
    }

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = result.files.single;

      if (!file.name.toLowerCase().endsWith('.gpx')) {
        return;
      }

      final path = file.path!;
      final gpxString = await File(path).readAsString();
      final gpx = GpxReader().fromString(gpxString);
      final int totalPointsBeforeFiltering;
      final List<GpxWaypoint> routePoints = [];

      // STRICTLY use track points (<trkpt>) and ignore standalone waypoints (<wpt>).
      if (gpx.trks.isNotEmpty) {
        int allPointsCount = 0;
        for (var track in gpx.trks) {
          for (var segment in track.trksegs) {
            allPointsCount += segment.trkpts.length;
            for (var wpt in segment.trkpts) {
               // Add point only if it's the first one or its coordinates are different from the previous one.
              if (routePoints.isEmpty || routePoints.last.wpt.lat != wpt.lat || routePoints.last.wpt.lon != wpt.lon) {
                routePoints.add(GpxWaypoint(wpt));
              }
            }
          }
        }
        totalPointsBeforeFiltering = allPointsCount;
      } else {
        totalPointsBeforeFiltering = 0;
      }

      if (kDebugMode) {
        print('[GPX_IMPORT] Filtered track points: ${routePoints.length} (out of $totalPointsBeforeFiltering original points)');
      }

      if (routePoints.length < 2) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('GPX файл не содержит валидного трека (меньше 2 уникальных точек).')),
            );
        }
        return;
      }

      // Calculate bearing (course) for each point
      final distance = const Distance();
      for (var i = 0; i < routePoints.length - 1; i++) {
        final p1 = routePoints[i];
        final p2 = routePoints[i + 1];
        final p1LatLng = LatLng(p1.wpt.lat!, p1.wpt.lon!);
        final p2LatLng = LatLng(p2.wpt.lat!, p2.wpt.lon!);
        var bearing = distance.bearing(p1LatLng, p2LatLng);
        if (bearing < 0) {
          bearing += 360;
        }
        p1.course = bearing;
      }
      // For the last point, use the bearing of the previous segment.
      if (routePoints.length > 1) {
          routePoints.last.course = routePoints[routePoints.length - 2].course;
      }

      final routeName = await _getRouteNameFromDialog(file.name);
      if (routeName == null || routeName.isEmpty) {
        return;
      }

      final newRoute = GpxRoute(name: routeName, points: routePoints);

      setState(() {
        _routes.add(newRoute);
      });
      await _saveRoutes();

    } catch (e) {
      if (kDebugMode) {
        print('[GPX_IMPORT] An error occurred during the import process: $e');
      }
    }
  }

  Future<void> _exportRoute(GpxRoute route) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Для экспорта нужно разрешение на доступ к хранилищу.')));
          }
          return;
        }
      }
    }

    final gpx = Gpx();
    gpx.metadata = Metadata(name: route.name);
    gpx.trks = [
      Trk(
        name: route.name,
        trksegs: [
          Trkseg(
            trkpts: route.points.map((p) {
              final wpt = p.wpt;
              final extensionsMap = <String, String>{};

              if (p.course != null) {
                extensionsMap['course'] = p.course.toString();
              }

              if (extensionsMap.isNotEmpty) {
                wpt.extensions = extensionsMap;
              }

              return wpt;
            }).toList(),
          ),
        ],
      ),
    ];

    final xmlString = GpxWriter().asString(gpx, pretty: true);
    final fileName = '${route.name.replaceAll(' ', '_')}.gpx';
    final Uint8List bytes = utf8.encode(xmlString);

    try {
      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить как GPX',
        fileName: fileName,
        bytes: (kIsWeb || Platform.isAndroid || Platform.isIOS) ? bytes : null,
        type: FileType.custom,
        allowedExtensions: ['gpx'],
      );

      if (path == null) {
        // User canceled the picker
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Экспорт отменен.')),
          );
        }
        return;
      }

      if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
        // This is a desktop platform, so we need to write the file manually.
        final file = File(path);
        await file.writeAsBytes(bytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Маршрут сохранен в: $path')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('An error occurred during export: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Маршруты'),
      ),
      body: _routes.isEmpty
          ? const Center(
              child: Text('Здесь будет список ваших маршрутов.'),
            )
          : ListView.builder(
              itemCount: _routes.length,
              itemBuilder: (context, index) {
                final route = _routes[index];
                return ListTile(
                  title: Text(route.name),
                  subtitle: Text('Точек: ${route.points.length}'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MapScreen(route: route),
                      ),
                    );
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteRoute(route, index);
                      } else if (value == 'export') {
                        _exportRoute(route);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'export',
                        child: Text('Экспорт'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Удалить'),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _importGpxFile,
        tooltip: 'Импорт GPX',
        child: const Icon(Icons.add),
      ),
    );
  }
}
