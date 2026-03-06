import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_geofence_app/models/geofence_model.dart';
import '../services/geofence_service.dart';

class GeofenceController extends GetxController {
  late GeofenceService geofenceService;

  // ── Reactive state ──────────────────────────────────────────
  final RxList<GeofenceModel> geofences = <GeofenceModel>[].obs;
  final Rx<Position?> currentLocation = Rx<Position?>(null);

  // ── Map observables ─────────────────────────────────────────
  /// Device latitude/longitude (updated live while tracking)
  final Rx<LatLng?> currentLatLng = Rx<LatLng?>(null);

  /// Point tapped on the map – cleared after a geofence is added
  final Rx<LatLng?> selectedMapLatLng = Rx<LatLng?>(null);

  /// flutter_map controller (programmatic camera moves)
  final MapController mapController = MapController();

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    geofenceService = Get.find<GeofenceService>();

    // Seed from service
    geofences.assignAll(geofenceService.geofences);
    _syncLatLng(geofenceService.currentLocation.value);

    // React to service changes
    ever<List<GeofenceModel>>(geofenceService.geofences,
        (list) => geofences.assignAll(list));

    ever<Position?>(geofenceService.currentLocation, (pos) {
      currentLocation.value = pos;
      _syncLatLng(pos);
    });

    // Fetch location immediately so the map has a starting centre
    await _refresh();
  }

  void _syncLatLng(Position? pos) {
    if (pos != null) {
      currentLatLng.value = LatLng(pos.latitude, pos.longitude);
    }
  }

  Future<void> _refresh() async {
    final pos = await geofenceService.getCurrentLocation();
    if (pos != null) {
      currentLatLng.value = LatLng(pos.latitude, pos.longitude);
    }
  }

  // ── "My location" FAB ───────────────────────────────────────
  Future<void> goToMyLocation() async {
    await _refresh();
    final latlng = currentLatLng.value;
    if (latlng != null) {
      mapController.move(latlng, 16);
    }
  }

  // ── Add geofence ────────────────────────────────────────────
  Future<void> addGeofence(
    String name,
    double latitude,
    double longitude,
    double radius,
  ) async {
    if (name.trim().isEmpty) {
      Get.snackbar('Error', 'Name cannot be empty',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await geofenceService.addGeofence(name.trim(), latitude, longitude, radius);
    selectedMapLatLng.value = null;
    Get.snackbar('✅ Added', 'Geofence "$name" added!',
        snackPosition: SnackPosition.BOTTOM);
  }

  // ── Remove geofence ─────────────────────────────────────────
  Future<void> removeGeofence(String id) async {
    await geofenceService.removeGeofence(id);
    Get.snackbar('Removed', 'Geofence deleted',
        snackPosition: SnackPosition.BOTTOM);
  }

  // No longer needed: startTracking and stopTracking are handled internally by the service.
}
