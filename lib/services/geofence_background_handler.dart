import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofence_foreground_service/constants/geofence_event_type.dart';
import 'package:geofence_foreground_service/geofence_foreground_service.dart';
import 'package:get_storage/get_storage.dart';

const _storageKeyGeofences = 'geofences';

@pragma('vm:entry-point')
void geofenceCallbackDispatcher() {
  GeofenceForegroundService().handleTrigger(
    backgroundTriggerHandler: (zoneId, triggerType) async {
      await GetStorage.init();
      final box = GetStorage();

      final raw = box.read<List<dynamic>>(_storageKeyGeofences) ?? const [];
      final geofenceName =
          raw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .firstWhere(
                    (e) => e['id'] == zoneId,
                    orElse: () => <String, dynamic>{},
                  )['name']
              as String? ??
          zoneId;

      final notifications = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await notifications.initialize(settings: initSettings);

      const channel = AndroidNotificationChannel(
        'geofence_channel',
        'Geofence Alerts',
        description: 'Notifications when you enter/exit a geofence',
        importance: Importance.max,
      );
      await notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      String title;
      String body;

      if (triggerType.isEnter) {
        title = 'Entered $geofenceName';
        body = 'You entered $geofenceName';
      } else if (triggerType.isExit) {
        title = 'Exited $geofenceName';
        body = 'You left $geofenceName';
      } else if (triggerType.isDwell) {
        title = 'Inside $geofenceName';
        body = 'You are still inside $geofenceName';
      } else {
        title = 'Geofence update';
        body = 'Zone: $geofenceName';
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'geofence_channel',
          'Geofence Alerts',
          channelDescription: 'Geofence notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await notifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: details,
      );

      return true;
    },
  );
}
