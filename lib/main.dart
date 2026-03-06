import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_geofence_app/controller/permission_controller.dart';
import 'package:my_geofence_app/screens/geofence_screen.dart';
import 'package:my_geofence_app/screens/permission_screen.dart';
import 'package:my_geofence_app/services/geofence_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request notification permission from awesome_notifications
  await AwesomeNotifications().isNotificationAllowed().then((allowed) async {
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  // Dependency injection
  Get.put(GeofenceService());
  Get.put(PermissionController());

  // Initialize service (notifications + native geofence manager)
  await Get.find<GeofenceService>().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Geofencing App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const StartupGate(),
    );
  }
}

/// Routes the user:
/// - If location "Always" + notifications are granted → main app
/// - Otherwise → permission screen
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate>
    with WidgetsBindingObserver {
  late final PermissionController _permController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permController = Get.find<PermissionController>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _permController.refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_permController.isLoading.value) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return _permController.allGranted
          ? const GeofenceScreen()
          : const PermissionScreen();
    });
  }
}
