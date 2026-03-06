import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
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
      locationServiceEnabled.value =
          await Geolocator.isLocationServiceEnabled();

      final locAlways = await ph.Permission.locationAlways.status;
      locationAlwaysGranted.value = locAlways.isGranted;

      final notif = await ph.Permission.notification.status;
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

    // 1) Request "When In Use" first (required before Always on iOS)
    final whenInUseStatus = await ph.Permission.locationWhenInUse.request();
    if (!whenInUseStatus.isGranted) {
      await refreshStatus();
      return;
    }

    // 2) Request "Always"
    await ph.Permission.locationAlways.request();
    await refreshStatus();
  }

  Future<void> requestNotifications() async {
    // permission_handler for Android 13+ / iOS runtime
    await ph.Permission.notification.request();

    // Also ask via awesome_notifications (handles iOS native prompt)
    if (!kIsWeb) {
      try {
        if (Platform.isIOS) {
          await AwesomeNotifications()
              .requestPermissionToSendNotifications();
        }
      } catch (_) {
        // Ignore; permission_handler status is our source of truth.
      }
    }

    await refreshStatus();
  }

  Future<void> openSystemSettings() async {
    await ph.openAppSettings();
    await refreshStatus();
  }
}
