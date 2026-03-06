import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_geofence_app/controller/geofence_controller.dart';
import 'package:my_geofence_app/models/geofence_model.dart';

class GeofenceScreen extends StatefulWidget {
  const GeofenceScreen({super.key});

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  final controller = Get.put(GeofenceController());

  // Default to a fallback position until GPS is ready
  static const _defaultCenter = LatLng(20.5937, 78.9629); // India centre

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Geofence App'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Global Geofence Toggle
          Obx(() => Row(
                children: [
                   Icon(
                    controller.geofenceService.isGlobalEnabled.value
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 20,
                    color: Colors.white70,
                  ),
                  Switch(
                    value: controller.geofenceService.isGlobalEnabled.value,
                    onChanged: (val) => controller.geofenceService.setGlobalEnabled(val),
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.greenAccent,
                  ),
                ],
              )),
          // My-location button
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Go to my location',
            onPressed: controller.goToMyLocation,
          ),
        ],
      ),

      body: Column(
        children: [
          // ── MAP ─────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: _MapView(controller: controller, defaultCenter: _defaultCenter),
          ),

          // ── GEOFENCE LIST ────────────────────────────────────
          Expanded(
            flex: 2,
            child: _GeofenceList(controller: controller),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
// MAP VIEW
// ─────────────────────────────────────────────────────────────
class _MapView extends StatelessWidget {
  const _MapView({required this.controller, required this.defaultCenter});
  final GeofenceController controller;
  final LatLng defaultCenter;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final devicePos = controller.currentLatLng.value;
      final selected = controller.selectedMapLatLng.value;
      final fences = controller.geofences.toList();

      return FlutterMap(
        mapController: controller.mapController,
        options: MapOptions(
          initialCenter: devicePos ?? defaultCenter,
          initialZoom: 15,
          onTap: (tapPosition, latlng) {
            // Save tap point, then show add-geofence dialog
            controller.selectedMapLatLng.value = latlng;
            _showAddDialog(context, latlng);
          },
        ),
        children: [
          // ── OpenStreetMap tiles (no API key needed) ──────────
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.my_geofence_app',
          ),

          // ── Geofence circles ─────────────────────────────────
          CircleLayer(
            circles: fences
                .map(
                  (g) => CircleMarker(
                    point: LatLng(g.latitude, g.longitude),
                    radius: g.radius,
                    useRadiusInMeter: true,
                    color: Colors.blue.withValues(alpha: 0.20),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                  ),
                )
                .toList(),
          ),

          // ── Geofence name markers ─────────────────────────────
          MarkerLayer(
            markers: [
              // Device location blue dot
              if (devicePos != null)
                Marker(
                  point: devicePos,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),

              // Selected (tapped) temporary marker
              if (selected != null)
                Marker(
                  point: selected,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.orange,
                    size: 40,
                  ),
                ),

              // One red-pin marker per geofence
              ...fences.map(
                (g) => Marker(
                  point: LatLng(g.latitude, g.longitude),
                  width: 120,
                  height: 50,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4)
                          ],
                        ),
                        child: Text(
                          g.name,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.location_pin, color: Colors.red, size: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Attribution ───────────────────────────────────────
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('OpenStreetMap contributors'),
            ],
          ),
        ],
      );
    });
  }

  void _showAddDialog(BuildContext context, LatLng latlng) {
    final nameController = TextEditingController();
    final radiusController = TextEditingController(text: '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('➕ Add Geofence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show the tapped coords (read-only info)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_pin, color: Colors.blue, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${latlng.latitude.toStringAsFixed(5)}, '
                      '${latlng.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name (e.g. Home)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius (metres)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.radar),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.find<GeofenceController>().selectedMapLatLng.value = null;
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final radius =
                  double.tryParse(radiusController.text) ?? 100;
              if (name.isEmpty) return;
              Get.find<GeofenceController>().addGeofence(
                name,
                latlng.latitude,
                latlng.longitude,
                radius,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GEOFENCE LIST (bottom panel)
// ─────────────────────────────────────────────────────────────
class _GeofenceList extends StatelessWidget {
  const _GeofenceList({required this.controller});
  final GeofenceController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fences = controller.geofences.toList();
      return Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.radar, size: 18, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  'Geofences (${fences.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                const Text(
                  'Tap map to add',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 8),
          Expanded(
            child: fences.isEmpty
                ? const Center(
                    child: Text(
                      '📍 Tap anywhere on the map to add a geofence',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: fences.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (_, i) => _FenceTile(
                      fence: fences[i],
                      controller: controller,
                    ),
                  ),
          ),
        ],
      );
    });
  }
}

class _FenceTile extends StatelessWidget {
  const _FenceTile({required this.fence, required this.controller});
  final GeofenceModel fence;
  final GeofenceController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.location_on, color: Colors.red),
        title: Text(fence.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${fence.latitude.toStringAsFixed(4)}, '
          '${fence.longitude.toStringAsFixed(4)}  •  '
          '${fence.radius.toStringAsFixed(0)} m',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => controller.removeGeofence(fence.id),
        ),
        onTap: () {
          // Pan map to this geofence
          controller.mapController.move(
            LatLng(fence.latitude, fence.longitude),
            16,
          );
        },
      ),
    );
  }
}
