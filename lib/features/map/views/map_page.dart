import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../viewmodels/map_viewmodel.dart';
import '../models/user_data.dart';
import '../models/location_data.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use context.watch<MapViewModel>() to listen to changes
    final viewModel = context.watch<MapViewModel>();
    final logger = Logger(); // Local logger for view-specific logs if needed

    logger.d("MapPage rebuilding. isLoading: ${viewModel.isLoading}, errorMessage: ${viewModel.errorMessage}");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          viewModel.appBarTitle,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Builder( // Use Builder to ensure context for Scaffold is available if needed
        builder: (context) {
          if (viewModel.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Authenticating and loading data..."),
                ],
              ),
            );
          }

          // Note: Error display is now part of _buildMapWithControls
          // We pass users and areas, even if empty on error,
          // and initialCenter (which will be fallback on error).
          // The showErrorOverlay and errorMessage will handle the visual error indication.
          return _buildMapWithControls(
            context, // Pass context for theme access if needed
            viewModel,
            viewModel.users,
            viewModel.areas,
            viewModel.initialMapCenter, // Use the calculated initial center
            viewModel.currentZoom, // Use currentZoom from ViewModel for initial map options
            showErrorOverlay: viewModel.errorMessage != null,
            errorMessage: viewModel.errorMessage,
          );
        },
      ),
    );
  }

  Widget _buildMapWithControls(
      BuildContext context, // Added context
      MapViewModel viewModel, // Pass viewModel for actions
      List<UserData> usersData,
      List<LocationData> areasData,
      LatLng initialCenter,
      double initialZoom,
      {bool showErrorOverlay = false,
      String? errorMessage}) {
    return Stack(
      children: [
        _buildMap(viewModel, usersData, areasData, initialCenter, initialZoom,
            showErrorOverlay: showErrorOverlay, errorMessage: errorMessage),
        Positioned(
          top: 20,
          right: 20,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: "zoomInBtn",
                tooltip: 'Zoom In',
                onPressed: viewModel.zoomIn, // Call ViewModel method
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: "zoomOutBtn",
                tooltip: 'Zoom Out',
                onPressed: viewModel.zoomOut, // Call ViewModel method
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMap(
      MapViewModel viewModel, // Pass viewModel for controller and event handling
      List<UserData> usersData,
      List<LocationData> areasData,
      LatLng initialCenter,
      double initialZoom, // This is the initial zoom for MapOptions
      {bool showErrorOverlay = false,
      String? errorMessage}) {
    final logger = Logger();
    logger.d("Building map for ${usersData.length} users and ${areasData.length} areas. Initial Center: $initialCenter, Initial Zoom: $initialZoom");

    List<CircleMarker> circles = areasData.map((area) {
      return CircleMarker(
        point: area.center,
        radius: area.radius,
        useRadiusInMeter: true,
        color: Colors.blue.withValues(alpha: 0.3), // Corrected withOpacity
        borderColor: Colors.blue,
        borderStrokeWidth: 2,
      );
    }).toList();

    List<Marker> markers = usersData.map((user) {
      final double markerSize = 10.0;
      return Marker(
        point: user.center,
        width: markerSize,
        height: markerSize,
        child: Tooltip(
          message: '${user.username}\nLat: ${user.center.latitude.toStringAsFixed(4)}, Lng: ${user.center.longitude.toStringAsFixed(4)}',
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.brown,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: viewModel.mapController, // Use ViewModel's controller
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: viewModel.currentZoom, // Use currentZoom for consistency on rebuilds
            onMapEvent: viewModel.handleMapEvent, // Delegate to ViewModel
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.peter.connect_flutter_frontend',
              tileProvider: CancellableNetworkTileProvider(),
            ),
            CircleLayer(circles: circles),
            MarkerLayer(markers: markers),
          ],
        ),
        if (showErrorOverlay)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.redAccent.withValues(alpha: 0.8), // Corrected withOpacity
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              child: Text(
                errorMessage ?? 'Error loading map data.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}