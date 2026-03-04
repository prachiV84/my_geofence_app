import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_geofence_app/controller/geofence_controller.dart';

class GeofenceScreen extends StatefulWidget {
  const GeofenceScreen({super.key});

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  final controller = Get.put(GeofenceController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Geofence App'),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // ========== STATUS SECTION ==========
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Status message
                    Obx(
                      () => Text(
                        controller.statusMessage.value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Current location
                    Obx(
                      () => controller.currentLocation.value != null
                          ? Text(
                              'Lat: ${controller.currentLocation.value!.latitude.toStringAsFixed(4)}\n'
                              'Lng: ${controller.currentLocation.value!.longitude.toStringAsFixed(4)}',
                              textAlign: TextAlign.center,
                            )
                          : const Text('Getting location...'),
                    ),
                    const SizedBox(height: 15),

                    // START/STOP button
                    Obx(
                      () => ElevatedButton(
                        onPressed: () {
                          if (controller.isTracking.value) {
                            controller.stopTracking();
                          } else {
                            controller.startTracking();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: controller.isTracking.value
                              ? Colors.red
                              : Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          controller.isTracking.value ? '⏹️ STOP' : '▶️ START',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ========== GEOFENCES LIST ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Geofences',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Obx(() => Text('(${controller.geofences.length})')),
              ],
            ),
          ),

          // List of geofences
          Expanded(
            child: Obx(
              () => controller.geofences.isEmpty
                  ? const Center(
                      child: Text(
                        'No geofences yet\nTap + to add one',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: controller.geofences.length,
                      padding: const EdgeInsets.all(16.0),
                      itemBuilder: (context, index) {
                        final geofence = controller.geofences[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              geofence.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Lat: ${geofence.latitude.toStringAsFixed(4)}\n'
                              'Lng: ${geofence.longitude.toStringAsFixed(4)}\n'
                              'Radius: ${geofence.radius.toStringAsFixed(0)}m',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                controller.removeGeofence(geofence.id);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),

      // ========== ADD BUTTON ==========
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGeofenceDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ========== DIALOG TO ADD GEOFENCE ==========
  void _showAddGeofenceDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final radiusController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➕ Add Geofence'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (e.g., Home)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lngController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: radiusController,
                decoration: const InputDecoration(
                  labelText: 'Radius (meters)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.addGeofence(
                nameController.text,
                double.parse(latController.text),
                double.parse(lngController.text),
                double.parse(radiusController.text),
              );
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
