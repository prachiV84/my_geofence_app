import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:my_geofence_app/models/geofence_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofence_foreground_service/geofence_foreground_service.dart';
import 'package:geofence_foreground_service/constants/geofence_event_type.dart';
import 'package:geofence_foreground_service/models/zone.dart';
import 'package:geofence_foreground_service/exports.dart';
import 'package:get_storage/get_storage.dart';

import 'geofence_background_handler.dart';

class GeofenceService extends GetxService {
  // Store all geofences (like a list on paper)
  final RxList<Geofence> geofences = <Geofence>[].obs;

  // Store current location
  final Rx<Position?> currentLocation = Rx(null);

  // Is tracking on?
  final RxBool isTracking = false.obs;

  late final FlutterLocalNotificationsPlugin _notificationPlugin;
  final Map<String, bool> _inside = <String, bool>{};
  DateTime? _lastCheckAt;
  final _box = GetStorage();
  Timer? _locationPollTimer;

  // ================================================
  // INITIALIZE (Run when app starts)
  // ================================================
  Future<void> initialize() async {
    await GetStorage.init();
    _loadGeofencesFromDisk();

    _notificationPlugin = FlutterLocalNotificationsPlugin();
    await _setupNotifications();
  }

  void _loadGeofencesFromDisk() {
    final raw = _box.read<List<dynamic>>('geofences');
    if (raw == null) return;
    final list = raw
        .whereType<Map>()
        .map((e) => Geofence.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    geofences.assignAll(list);
  }

  void _persistGeofences() {
    _box.write('geofences', geofences.map((g) => g.toJson()).toList());
  }

  // ================================================
  // SETUP NOTIFICATIONS
  // ================================================
  Future<void> _setupNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationPlugin.initialize(settings: settings);

    const androidChannel = AndroidNotificationChannel(
      'geofence_channel',
      'Geofence Alerts',
      description: 'Notifications when you enter/exit a geofence',
      importance: Importance.max,
    );
    await _notificationPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
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
      debugPrint('📍 Location: ${position.latitude}, ${position.longitude}');

      return position;
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
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
    _persistGeofences();
    _inside.remove(geofence.id);
    debugPrint('✅ Added geofence: $name');

    if (isTracking.value) {
      await GeofenceForegroundService().addGeofenceZone(
        zone: Zone(
          id: geofence.id,
          radius: geofence.radius,
          coordinates: [LatLng.degree(geofence.latitude, geofence.longitude)],
          triggers: const [GeofenceEventType.enter, GeofenceEventType.exit],
          notificationResponsivenessMs: 10 * 1000,
        ),
      );
    }
  }

  // ================================================
  // REMOVE GEOFENCE
  // ================================================
  void removeGeofence(String id) {
    geofences.removeWhere((g) => g.id == id);
    _persistGeofences();
    _inside.remove(id);
    debugPrint('✅ Removed geofence: $id');

    if (isTracking.value) {
      GeofenceForegroundService().removeGeofenceZone(zoneId: id);
    }
  }

  // ================================================
  // CHECK IF INSIDE ANY GEOFENCE
  // ================================================
  Future<void> checkGeofences() async {
    final now = DateTime.now();
    if (_lastCheckAt != null &&
        now.difference(_lastCheckAt!) < const Duration(seconds: 10)) {
      return;
    }
    _lastCheckAt = now;

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

      debugPrint(
        'Distance to ${geofence.name}: ${distance.toStringAsFixed(0)}m',
      );

      // If I'm within the radius
      final isInsideNow = distance <= geofence.radius;
      final wasInside = _inside[geofence.id];
      if (wasInside == null) {
        _inside[geofence.id] = isInsideNow;
        continue;
      }

      if (!wasInside && isInsideNow) {
        _inside[geofence.id] = true;
        await _showNotification(
          'Entered ${geofence.name}',
          'You entered ${geofence.name}',
        );
      } else if (wasInside && !isInsideNow) {
        _inside[geofence.id] = false;
        await _showNotification(
          'Exited ${geofence.name}',
          'You left ${geofence.name}',
        );
      }
    }
  }

  // ================================================
  // SHOW NOTIFICATION
  // ================================================
  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Alerts',
      channelDescription: 'Geofence notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  // ================================================
  // START TRACKING (CHECK EVERY 10 SECONDS)
  // ================================================
  Future<void> startTracking() async {
    if (geofences.isEmpty) {
      Get.snackbar('Error', 'Add a geofence first!');
      return;
    }

    final started = await GeofenceForegroundService().startGeofencingService(
      notificationChannelId: 'com.example.my_geofence_app.geofencing',
      contentTitle: 'Geofence tracking is active',
      contentText: 'Monitoring your saved geofences in background',
      serviceId: 525600,
      callbackDispatcher: geofenceCallbackDispatcher,
      isInDebugMode: true,
    );

    if (!started) {
      Get.snackbar('Error', 'Failed to start background geofencing service');
      return;
    }

    await GeofenceForegroundService().removeAllGeoFences();
    for (final g in geofences) {
      await GeofenceForegroundService().addGeofenceZone(
        zone: Zone(
          id: g.id,
          radius: g.radius,
          coordinates: [LatLng.degree(g.latitude, g.longitude)],
          triggers: [GeofenceEventType.enter, GeofenceEventType.exit],
          notificationResponsivenessMs: 10 * 1000,
        ),
      );
    }

    isTracking.value = true;
    debugPrint('🚀 Tracking started');

    await getCurrentLocation();
    _locationPollTimer?.cancel();
    _locationPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => getCurrentLocation(),
    );
  }

  // ================================================
  // STOP TRACKING
  // ================================================
  void stopTracking() {
    isTracking.value = false;
    _locationPollTimer?.cancel();
    _locationPollTimer = null;
    GeofenceForegroundService().stopGeofencingService();
    debugPrint('🛑 Tracking stopped');
  }
}
