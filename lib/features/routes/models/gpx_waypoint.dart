import 'package:gpx/gpx.dart';

class GpxWaypoint {
  final Wpt _wpt;
  double? course;
  int? satellites;

  GpxWaypoint(this._wpt, {this.course, this.satellites});

  Wpt get wpt => _wpt;

  // Convert a GpxWaypoint into a Map.
  Map<String, dynamic> toJson() => {
        'lat': _wpt.lat,
        'lon': _wpt.lon,
        'ele': _wpt.ele,
        'time': _wpt.time?.toIso8601String(),
        'name': _wpt.name,
        'desc': _wpt.desc,
        'sym': _wpt.sym,
        'course': course,
        'satellites': satellites,
      };

  // Create a GpxWaypoint from a Map.
  factory GpxWaypoint.fromJson(Map<String, dynamic> json) {
    final wpt = Wpt()
      ..lat = json['lat'] as double?
      ..lon = json['lon'] as double?
      ..ele = json['ele'] as double?
      ..time = json['time'] != null ? DateTime.parse(json['time'] as String) : null
      ..name = json['name'] as String?
      ..desc = json['desc'] as String?
      ..sym = json['sym'] as String?;
    return GpxWaypoint(
      wpt,
      course: json['course'] as double?,
      satellites: json['satellites'] as int?,
    );
  }
}
