class GeofenceModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;

  GeofenceModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory GeofenceModel.fromJson(Map<String, dynamic> json) => GeofenceModel(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radius: (json['radius'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      };
}
