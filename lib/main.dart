import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_geofence_app/controller/permission_controller.dart';
import 'package:my_geofence_app/screens/geofence_screen.dart';
import 'package:my_geofence_app/screens/permission_screen.dart';
import 'package:my_geofence_app/services/geofence_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dependency injection (GetX)
  Get.put(GeofenceService());
  Get.put(PermissionController());

  // Notification init is safe even before permissions are granted.
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

class _StartupGateState extends State<StartupGate> with WidgetsBindingObserver {
  late final PermissionController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = Get.find<PermissionController>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return controller.allGranted
          ? const GeofenceScreen()
          : const PermissionScreen();
    });
  }
}
