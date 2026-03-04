import 'package:geolocator/geolocator.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:my_geofence_app/models/geofence_model.dart';

class GeofenceService extends GetxService {
  // Store all geofences (like a list on paper)
  final RxList<Geofence> geofences = <Geofence>[].obs;

  // Store current location
  final Rx<Position?> currentLocation = Rx(null);

  // Is tracking on?
  final RxBool isTracking = false.obs;

  // // Notification plugin
  // late FlutterLocalNotificationsPlugin notificationPlugin;

  // ================================================
  // INITIALIZE (Run when app starts)
  // ================================================
  Future<void> initialize() async {
    print('🔧 Initializing Geofence Service...');

    // Setup notifications
    // await _setupNotifications();

    // Request permission
    await _requestLocationPermission();

    print('✅ Geofence Service Ready!');
  }

  // ================================================
  // SETUP NOTIFICATIONS
  // ================================================
  // Future<void> _setupNotifications() async {
  //   notificationPlugin = FlutterLocalNotificationsPlugin();

  //   // Android settings
  //   const AndroidInitializationSettings androidSettings =
  //       AndroidInitializationSettings('@mipmap/ic_launcher');

  //   // iOS settings
  //   const DarwinInitializationSettings iosSettings =
  //       DarwinInitializationSettings(
  //         requestAlertPermission: true,
  //         requestBadgePermission: true,
  //         requestSoundPermission: true,
  //       );

  //   // Combine
  //   const InitializationSettings settings = InitializationSettings(
  //     android: androidSettings,
  //     iOS: iosSettings,
  //   );

  //   await notificationPlugin.initialize(settings);
  // }

  // // ================================================
  // REQUEST LOCATION PERMISSION
  // ================================================
  Future<void> _requestLocationPermission() async {
    final status = await Geolocator.requestPermission();

    if (status == LocationPermission.denied) {
      print('❌ User denied location permission');
      Get.snackbar('Permission', 'Location permission denied');
    } else if (status == LocationPermission.deniedForever) {
      print('❌ User denied permission forever');
      Get.snackbar('Permission', 'Enable location in Settings');
      await Geolocator.openLocationSettings();
    } else {
      print('✅ Location permission granted!');
    }
  }

  // ================================================
  // GET CURRENT LOCATION
  // ================================================
  Future<Position?> getCurrentLocation() async {
    try {
      // Get location from GPS
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentLocation.value = position;
      print('📍 Location: ${position.latitude}, ${position.longitude}');

      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  // ================================================
  // ADD NEW GEOFENCE
  // ================================================
  Future<void> addGeofence(
    String name,
    double latitude,
    double longitude,
    double radius,
  ) async {
    // Create new geofence
    final geofence = Geofence(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
    );

    // Add to list
    geofences.add(geofence);
    print('✅ Added geofence: $name');
  }

  // ================================================
  // REMOVE GEOFENCE
  // ================================================
  void removeGeofence(String id) {
    geofences.removeWhere((g) => g.id == id);
    print('✅ Removed geofence: $id');
  }

  // ================================================
  // CHECK IF INSIDE ANY GEOFENCE
  // ================================================
  Future<void> checkGeofences() async {
    // Get where I am right now
    final position = await getCurrentLocation();
    if (position == null) return;

    // Check each geofence
    for (final geofence in geofences) {
      // Calculate distance from me to geofence center
      final distance = Geolocator.distanceBetween(
        position.latitude, // My location
        position.longitude,
        geofence.latitude, // Geofence location
        geofence.longitude,
      );

      print('Distance to ${geofence.name}: ${distance.toStringAsFixed(0)}m');

      // If I'm within the radius
      // if (distance <= geofence.radius) {
      //   await _showNotification(
      //     '📍 Entered ${geofence.name}',
      //     'You are inside ${geofence.name}',
      //   );
      // } else {
      //   await _showNotification(
      //     '📍 Left ${geofence.name}',
      //     'You left ${geofence.name}',
      //   );
      // }
    }
  }

  // ================================================
  // SHOW NOTIFICATION
  // ================================================
  // Future<void> _showNotification(String title, String body) async {
  //   const AndroidNotificationDetails androidDetails =
  //       AndroidNotificationDetails(
  //         'geofence_channel',
  //         'Geofence Alerts',
  //         channelDescription: 'Geofence notifications',
  //         importance: Importance.max,
  //         priority: Priority.high,
  //       );

  //   const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
  //     presentAlert: true,
  //     presentBadge: true,
  //     presentSound: true,
  //   );

  //   const NotificationDetails details = NotificationDetails(
  //     android: androidDetails,
  //     iOS: iosDetails,
  //   );

  //   await notificationPlugin.show(
  //     DateTime.now().millisecond,
  //     title,
  //     body,
  //     details,
  //   );
  // }

  // ================================================
  // START TRACKING (CHECK EVERY 10 SECONDS)
  // ================================================
  Future<void> startTracking() async {
    if (geofences.isEmpty) {
      Get.snackbar('Error', 'Add a geofence first!');
      return;
    }

    isTracking.value = true;
    print('🚀 Tracking started');

    // Keep checking while tracking is on
    while (isTracking.value) {
      await checkGeofences();

      // Wait 10 seconds before checking again
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  // ================================================
  // STOP TRACKING
  // ================================================
  void stopTracking() {
    isTracking.value = false;
    print('🛑 Tracking stopped');
  }
}
