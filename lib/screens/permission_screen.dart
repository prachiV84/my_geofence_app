import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_geofence_app/controller/permission_controller.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PermissionController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Permissions'), centerTitle: true),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'To work reliably in foreground + background on iOS and Android, we need:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            FilledButton(
              onPressed: () async {
                await controller.requestLocationAlways();
                await controller.requestNotifications();
                await controller.refreshStatus();
              },
              child: const Text('Grant required permissions'),
            ),
            const SizedBox(height: 12),

            _PermissionTile(
              title: 'Location: Always',
              subtitle: controller.locationServiceEnabled.value
                  ? (controller.locationAlwaysGranted.value
                        ? 'Granted'
                        : 'Not granted')
                  : 'Location services are OFF',
              granted:
                  controller.locationServiceEnabled.value &&
                  controller.locationAlwaysGranted.value,
              buttonText: 'Grant',
              onPressed: controller.requestLocationAlways,
            ),
            const SizedBox(height: 12),
            _PermissionTile(
              title: 'Notifications',
              subtitle: controller.notificationsGranted.value
                  ? 'Granted'
                  : 'Not granted',
              granted: controller.notificationsGranted.value,
              buttonText: 'Enable',
              onPressed: controller.requestNotifications,
            ),

            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: controller.allGranted
                  ? null
                  : controller.openSystemSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings (if needed)'),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: controller.allGranted
                  ? () {
                      // Just pop/refresh; the StartupGate will swap screens.
                      controller.refreshStatus();
                    }
                  : null,
              child: const Text('Continue'),
            ),

            const SizedBox(height: 12),
            const Text(
              'Notes:\n'
              '- Android 11+ may require enabling “Allow all the time” in system settings.\n'
              '- iOS may show “Always” only after you allow “While Using” first.\n',
            ),
          ],
        );
      }),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final String buttonText;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          granted ? Icons.check_circle : Icons.error,
          color: granted ? Colors.green : Colors.orange,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: TextButton(
          onPressed: granted ? null : () => onPressed(),
          child: Text(buttonText),
        ),
      ),
    );
  }
}
