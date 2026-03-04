import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_geofence_app/models/geofence_model.dart';
import '../services/geofence_service.dart';

class GeofenceController extends GetxController {
  late GeofenceService geofenceService;

  // Data that UI can see and react to
  final RxList<Geofence> geofences = <Geofence>[].obs;
  final RxBool isTracking = false.obs;
  final Rx<Position?> currentLocation = Rx(null);
  final RxString statusMessage = 'Not Tracking'.obs;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  // Initialize service
  Future<void> _initialize() async {
    geofenceService = Get.find<GeofenceService>();

    // When service geofences change, update controller
    ever(geofenceService.geofences, (geofences) {
      this.geofences.value = geofences;
    });

    // When tracking changes, update controller
    ever(geofenceService.isTracking, (isTracking) {
      this.isTracking.value = isTracking;
      statusMessage.value = isTracking ? '🟢 Tracking' : '🔴 Not Tracking';
    });

    // When location changes, update controller
    ever(geofenceService.currentLocation, (location) {
      this.currentLocation.value = location;
    });
  }

  // ================================================
  // ADD GEOFENCE FROM UI
  // ================================================
  Future<void> addGeofence(
    String name,
    double latitude,
    double longitude,
    double radius,
  ) async {
    if (name.isEmpty) {
      Get.snackbar('Error', 'Name cannot be empty');
      return;
    }

    await geofenceService.addGeofence(name, latitude, longitude, radius);
    Get.snackbar('Success', 'Geofence "$name" added!');
  }

  // ================================================
  // REMOVE GEOFENCE
  // ================================================
  void removeGeofence(String id) {
    geofenceService.removeGeofence(id);
    Get.snackbar('Success', 'Geofence removed');
  }

  // ================================================
  // START TRACKING
  // ================================================
  void startTracking() {
    if (geofences.isEmpty) {
      Get.snackbar('Error', 'Add a geofence first!');
      return;
    }
    geofenceService.startTracking();
  }

  // ================================================
  // STOP TRACKING
  // ================================================
  void stopTracking() {
    geofenceService.stopTracking();
  }

  // ================================================
  // GET CURRENT LOCATION (For UI)
  // ================================================
  Future<Position?> getLocation() async {
    return await geofenceService.getCurrentLocation();
  }
}
