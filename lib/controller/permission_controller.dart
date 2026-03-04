import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionController extends GetxController {
  final RxBool isLoading = true.obs;

  final RxBool locationServiceEnabled = false.obs;
  final RxBool locationAlwaysGranted = false.obs;
  final RxBool notificationsGranted = false.obs;

  bool get allGranted =>
      locationServiceEnabled.value &&
      locationAlwaysGranted.value &&
      notificationsGranted.value;

  @override
  void onInit() {
    super.onInit();
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    isLoading.value = true;
    try {
      locationServiceEnabled.value = await Geolocator.isLocationServiceEnabled();

      final locAlways = await ph.Permission.locationAlways.status;
      locationAlwaysGranted.value = locAlways.isGranted;

      final notif = await ph.Permission.notification.status;
      // On Android < 13 this is typically granted by default; permission_handler
      // reports it as granted.
      notificationsGranted.value = notif.isGranted;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> requestLocationAlways() async {
    // 0) Make sure location services are on
    locationServiceEnabled.value = await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled.value) {
      await Geolocator.openLocationSettings();
      await refreshStatus();
      if (!locationServiceEnabled.value) return;
    }

    // 1) Request "When In Use" first (required before Always on iOS, and helps Android flow)
    final whenInUseStatus = await ph.Permission.locationWhenInUse.request();
    if (!whenInUseStatus.isGranted) {
      await refreshStatus();
      return;
    }

    // 2) Request "Always"
    final alwaysStatus = await ph.Permission.locationAlways.request();
    if (!alwaysStatus.isGranted) {
      // Android 11+ often forces background permission via settings.
      await refreshStatus();
      return;
    }

    await refreshStatus();
  }

  Future<void> requestNotifications() async {
    // iOS + Android 13+ need runtime permission.
    final status = await ph.Permission.notification.request();

    // Also ask via flutter_local_notifications (ensures proper iOS prompt + Android plugin path).
    if (!kIsWeb) {
      final plugin = FlutterLocalNotificationsPlugin();
      try {
        if (Platform.isIOS) {
          await plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              );
        } else if (Platform.isAndroid) {
          await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission();
        }
      } catch (_) {
        // Ignore; permission_handler status is our source of truth.
      }
    }

    notificationsGranted.value = status.isGranted;
    await refreshStatus();
  }

  Future<void> openSystemSettings() async {
    await ph.openAppSettings();
    await refreshStatus();
  }
}

