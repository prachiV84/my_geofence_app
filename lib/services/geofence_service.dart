import 'dart:async';
import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/geofence_model.dart';

// ─────────────────────────────────────────────────────────────
// TOP-LEVEL CALLBACK (required by native_geofence)
// Must be a top-level function annotated with @pragma('vm:entry-point')
// ─────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> geofenceCallback(GeofenceCallbackParams params) async {
  debugPrint('🔔 Geofence callback: $params');

  final isEnter = params.event == GeofenceEvent.enter;
  
  // Extract human-readable name from the ID (Format: Name_Timestamp)
  String zoneName = 'Unknown Zone';
  if (params.geofences.isNotEmpty) {
    final fullId = params.geofences.first.id;
    if (fullId.contains('_')) {
      zoneName = fullId.split('_').first;
    } else {
      zoneName = fullId;
    }
  }

  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      channelKey: 'geofence_channel',
      title: isEnter ? '📍 You have arrived' : '🚪 You have left', // Premium wording
      body: isEnter
          ? 'You have arrived at "$zoneName"'
          : 'You left "$zoneName"',
      notificationLayout: NotificationLayout.Default,
      color: const Color(0xFF0066FF),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// GEOFENCE SERVICE
// ─────────────────────────────────────────────────────────────
class GeofenceService extends GetxService {
  static const _prefKey = 'geofences_v2';
  static const _enabledKey = 'geofencing_enabled';

  final RxList<GeofenceModel> geofences = <GeofenceModel>[].obs;
  final Rx<Position?> currentLocation = Rx<Position?>(null);
  final RxBool isGlobalEnabled = true.obs;

  StreamSubscription<Position>? _positionSub;
  SharedPreferences? _prefs;

  // ──────────────────────────────
  // INITIALIZE
  // ──────────────────────────────
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load global state
    isGlobalEnabled.value = _prefs?.getBool(_enabledKey) ?? true;
    
    _loadGeofences();
    await _setupNotifications();
    await NativeGeofenceManager.instance.initialize();
    
    // Automatically start tracking all saved geofences if enabled
    if (isGlobalEnabled.value) {
      await startTracking();
    }
  }

  // ──────────────────────────────
  // GLOBAL TOGGLE
  // ──────────────────────────────
  Future<void> setGlobalEnabled(bool enabled) async {
    isGlobalEnabled.value = enabled;
    await _prefs?.setBool(_enabledKey, enabled);
    
    if (enabled) {
      await startTracking();
      debugPrint('✅ Global Geofencing ENABLED');
    } else {
      await stopTracking();
      debugPrint('🛑 Global Geofencing DISABLED');
    }
  }

  // ──────────────────────────────
  // NOTIFICATIONS
  // ──────────────────────────────
  Future<void> _setupNotifications() async {
    await AwesomeNotifications().initialize(
      null, // use default app icon
      [
        NotificationChannel(
          channelKey: 'geofence_channel',
          channelName: 'Geofence Alerts',
          channelDescription: 'Notifications when you enter or exit a geofence',
          defaultColor: const Color(0xFF0066FF),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
      ],
    );
  }

  // ──────────────────────────────
  // PERSISTENCE (SharedPreferences)
  // ──────────────────────────────
  void _loadGeofences() {
    final raw = _prefs?.getString(_prefKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => GeofenceModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      geofences.assignAll(list);
    } catch (e) {
      debugPrint('⚠️ Failed to load geofences: $e');
    }
  }

  Future<void> _persistGeofences() async {
    final encoded = jsonEncode(geofences.map((g) => g.toJson()).toList());
    await _prefs?.setString(_prefKey, encoded);
  }

  // ──────────────────────────────
  // LOCATION
  // ──────────────────────────────
  Future<Position?> getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentLocation.value = pos;
      return pos;
    } catch (e) {
      debugPrint('❌ Location error: $e');
      return null;
    }
  }

  // ──────────────────────────────
  // ADD GEOFENCE
  // ──────────────────────────────
  Future<void> addGeofence(
    String name,
    double latitude,
    double longitude,
    double radius,
  ) async {
    final id = '${name}_${DateTime.now().millisecondsSinceEpoch}';
    final model = GeofenceModel(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
    );

    geofences.add(model);
    await _persistGeofences();

    // Register with native API only if globally enabled
    if (isGlobalEnabled.value) {
      await _registerNativeGeofence(model);
    }

    debugPrint('✅ Added geofence: $name (Registered: ${isGlobalEnabled.value})');
  }

  Future<void> _registerNativeGeofence(GeofenceModel model) async {
    final zone = Geofence(
      id: model.id,
      location: Location(
        latitude: model.latitude,
        longitude: model.longitude,
      ),
      radiusMeters: model.radius,
      triggers: const {GeofenceEvent.enter, GeofenceEvent.exit},
      iosSettings: const IosGeofenceSettings(initialTrigger: false),
      androidSettings: AndroidGeofenceSettings(
        initialTriggers: const {},
        expiration: const Duration(days: 30), // Extended expiration
        notificationResponsiveness: const Duration(seconds: 0), // Fastest response
      ),
    );
    await NativeGeofenceManager.instance.createGeofence(zone, geofenceCallback);
  }

  // ──────────────────────────────
  // REMOVE GEOFENCE
  // ──────────────────────────────
  Future<void> removeGeofence(String id) async {
    geofences.removeWhere((g) => g.id == id);
    await _persistGeofences();
    try {
      await NativeGeofenceManager.instance.removeGeofenceById(id);
    } catch (e) {
      debugPrint('⚠️ Error removing native geofence: $e');
    }
    debugPrint('✅ Removed geofence: $id');
  }

  // ──────────────────────────────
  // START TRACKING
  // ──────────────────────────────
  Future<void> startTracking() async {
    // 1. Register all saved geofences with native manager
    for (final g in geofences) {
      await _registerNativeGeofence(g);
    }

    // 2. Listen to live position stream for map updates
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      currentLocation.value = pos;
    });

    debugPrint('🚀 Tracking (Native Geofencing) ACTIVE');
  }

  // ──────────────────────────────
  // STOP TRACKING
  // ──────────────────────────────
  Future<void> stopTracking() async {
    _positionSub?.cancel();
    _positionSub = null;

    // Remove all native geofences from OS monitoring
    try {
      await NativeGeofenceManager.instance.removeAllGeofences();
    } catch (e) {
      debugPrint('⚠️ Error removing all native geofences: $e');
    }
    debugPrint('🛑 Tracking STOPPED');
  }

  @override
  void onClose() {
    _positionSub?.cancel();
    super.onClose();
  }
}
