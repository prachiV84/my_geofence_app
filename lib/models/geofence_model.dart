// This is like a form for storing geofence info
class Geofence {
  String id; // Unique ID
  String name; // "My Home", "My Office"
  double latitude; // Map position (North/South)
  double longitude; // Map position (East/West)
  double radius; // Circle size in meters

  // Constructor = Way to create a Geofence
  Geofence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}
