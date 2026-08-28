import './gpx_waypoint.dart';

// Модель данных для хранения маршрута
class GpxRoute {
  String name;
  List<GpxWaypoint> points;

  GpxRoute({required this.name, required this.points});

  // Convert a GpxRoute into a Map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'points': points.map((p) => p.toJson()).toList(),
      };

  // Create a GpxRoute from a Map.
  factory GpxRoute.fromJson(Map<String, dynamic> json) {
    final pointsList = (json['points'] as List)
        .map((p) => GpxWaypoint.fromJson(p as Map<String, dynamic>))
        .toList();
    return GpxRoute(name: json['name'] as String, points: pointsList);
  }
}
