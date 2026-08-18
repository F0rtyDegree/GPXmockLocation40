import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';
import 'package:permission_handler/permission_handler.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {

  Future<void> _importGpxFile() async {
    if (kDebugMode) {
      print('[GPX_IMPORT] Starting file import process...');
    }

    // Request storage permission
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        if (kDebugMode) {
          print('[GPX_IMPORT] Storage permission was denied.');
        }
        // Optionally, show a dialog to the user that permission is needed
        return;
      }
    }

    try {
      if (kDebugMode) {
        print('[GPX_IMPORT] Launching file picker...');
      }
      // Pick a file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        if (kDebugMode) {
          print('[GPX_IMPORT] User canceled the file picker or file path is null.');
        }
        return;
      }
      
      final file = result.files.single;

      if (!file.name.toLowerCase().endsWith('.gpx')) {
        if (kDebugMode) {
          print('[GPX_IMPORT] Invalid file type. Please select a .gpx file.');
        }
        // TODO: Show an error message to the user that the file type is invalid
        return;
      }

      if (kDebugMode) {
          print('[GPX_IMPORT] File picked: ${file.name}');
      }

      final path = file.path!;
      final gpxString = await File(path).readAsString();

      if (kDebugMode) {
        print('[GPX_IMPORT] File read successfully. Parsing content...');
      }
      
      final gpx = GpxReader().fromString(gpxString);
      
      final pointCount = gpx.wpts.length;
      if (kDebugMode) {
        print('[GPX_IMPORT] Successfully parsed GPX file: ${file.name}');
        print('[GPX_IMPORT] Found $pointCount waypoint points.');
      }

      // TODO: Save the parsed route and display it in the list

    } catch (e) {
      if (kDebugMode) {
        print('[GPX_IMPORT] An error occurred during the import process: $e');
      }
      // TODO: Show an error message to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Маршруты'),
      ),
      body: const Center(
        child: Text('Здесь будет список ваших маршрутов.'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _importGpxFile,
        tooltip: 'Импорт GPX',
        child: const Icon(Icons.add),
      ),
    );
  }
}
