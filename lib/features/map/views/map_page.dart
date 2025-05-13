import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../viewmodels/map_viewmodel.dart';
import '../models/user_data.dart';
import '../models/location_data.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the ViewModel
    // final viewModel = Provider.of<MapViewModel>(context); // Not needed here due to Consumer
    // viewModel.loadInitialData(); // Data is loaded in constructor or an init method in ViewModel

    return Scaffold(
      appBar: AppBar(
        title: const Text('World Map'),
        actions: [
          Consumer<MapViewModel>( // Use Consumer for actions that depend on ViewModel state
            builder: (context, vm, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: vm.isLoading ? null : () => vm.refreshData(),
                tooltip: 'Refresh Data',
              );
            }
          )
        ],
      ),
      body: Consumer<MapViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoading && vm.users.isEmpty && vm.areas.isEmpty) { // Show loading only if no data is present yet
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.errorMessage != null && vm.users.isEmpty && vm.areas.isEmpty) { // Show error prominently if data fails to load initially
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${vm.errorMessage}', textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => vm.refreshData(),
                      child: const Text('Try Refreshing'),
                    )
                  ],
                ),
              ),
            );
          }
          // If there's an error but we have some stale data, we can show the map with an error snackbar or overlay.
          if (vm.errorMessage != null && (vm.users.isNotEmpty || vm.areas.isNotEmpty)) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ScaffoldMessenger.of(context).mounted) { // Check if mounted
                  ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove previous snackbar if any
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not refresh data: ${vm.errorMessage}'),
                      backgroundColor: Colors.orangeAccent,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
             });
          }

          return Stack( // Use Stack to overlay buttons on the map
            children: [
              FlutterMap(
                mapController: vm.mapController,
                options: MapOptions(
                  initialCenter: vm.initialCenter, // This will now be the device's location or default
                  initialZoom: 13.0, // Zoom in a bit more for local view
                  minZoom: 3,
                  maxZoom: 18,
                  onTap: (_, point) {
                    // Example: Log tapped coordinates
                    vm.pocketBaseService.logger.t('Map tapped at: ${point.latitude}, ${point.longitude}');
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app', // Replace with your app's package name
                  ),
                  // Display user markers
                  MarkerLayer(markers: _buildUserMarkers(context, vm.users)),
                  // Display area circles
                  CircleLayer(circles: _buildAreaCircles(context, vm.areas)),
                  // Optionally, a marker for the current user's initial position if desired
                  // This marker shows where the map initially centered based on GPS/default.
                  if (vm.initialCenter != const LatLng(37.7749, -122.4194) ) // Example: if not default San Francisco
                    MarkerLayer(markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: vm.initialCenter,
                        child: const Icon(Icons.my_location, color: Colors.blueAccent, size: 30.0)
                      )
                    ])
                ],
              ),
              Positioned( // Position the zoom buttons
                right: 10,
                bottom: 90, // Adjusted to be above the main FAB
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FloatingActionButton.small(
                      heroTag: "zoomInBtn", // Unique heroTag
                      onPressed: () {
                        final currentZoom = vm.mapController.camera.zoom;
                        if (currentZoom < (vm.mapController.camera.maxZoom ?? 18)) {
                           vm.mapController.move(vm.mapController.camera.center, currentZoom + 1);
                        }
                      },
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: "zoomOutBtn", // Unique heroTag
                      onPressed: () {
                        final currentZoom = vm.mapController.camera.zoom;
                        if (currentZoom > (vm.mapController.camera.minZoom ?? 3)) {
                          vm.mapController.move(vm.mapController.camera.center, currentZoom - 1);
                        }
                      },
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      // Floating action button for manually centering on current location (optional)
      floatingActionButton: FloatingActionButton(
        heroTag: "myLocationBtn", // Ensure unique heroTag
        onPressed: () {
          // This will re-fetch location and all data, then center the map.
          Provider.of<MapViewModel>(context, listen: false).refreshData();
        },
        tooltip: 'My Location / Refresh',
        child: Consumer<MapViewModel>( // Show loading indicator on FAB if refreshing
          builder: (context, vm, child) {
            return vm.isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.my_location);
          }
        ),
      ),
    );
  }

  List<Marker> _buildUserMarkers(BuildContext context, List<UserData> users) {
    final viewModel = Provider.of<MapViewModel>(context, listen: false);
    return users.map((user) {
      return Marker(
        width: 80.0, // Increased width for better text fit
        height: 80.0,
        point: user.center,
        child: GestureDetector(
          onTap: () {
            viewModel.pocketBaseService.logger.i("Tapped on user: ${user.username}");
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User: ${user.username} (ID: ${user.id})')),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_pin_circle, color: Colors.blue, size: 30.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user.username,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                )
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<CircleMarker> _buildAreaCircles(BuildContext context, List<LocationData> areas) {
    // final viewModel = Provider.of<MapViewModel>(context, listen: false); // Not needed for this simple list
    return areas.map((area) {
      return CircleMarker(
        point: area.center,
        radius: area.radius, // Radius in meters
        useRadiusInMeter: true,
        color: Colors.red.withValues(alpha:0.3),
        borderColor: Colors.red,
        borderStrokeWidth: 2,
        // onTap not directly available on CircleMarker, handle via MapOptions.onTap and check proximity if needed
        // For interactivity with circles, you'd typically check if the tap point is within any circle's bounds.
      );
    }).toList();
  }
}
