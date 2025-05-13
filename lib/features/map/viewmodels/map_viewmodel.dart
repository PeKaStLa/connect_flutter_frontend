import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../models/user_data.dart';
import '../models/location_data.dart';
import '../../../core/services/pocketbase_service.dart';

class MapViewModel extends ChangeNotifier {
  final PocketBaseService pocketBaseService;

  List<UserData> _users = [];
  List<LocationData> _areas = [];
  bool _isLoading = false;
  String? _errorMessage;
  // Default center, will be updated by device location if possible
  LatLng _initialCenter = const LatLng(37.7749, -122.4194); // Default to San Francisco
  final MapController _mapController = MapController();

  List<UserData> get users => _users;
  List<LocationData> get areas => _areas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  LatLng get initialCenter => _initialCenter; // Exposed for MapOptions
  MapController get mapController => _mapController;

  MapViewModel({required this.pocketBaseService}) {
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Notify UI that loading has started

    await _fetchDeviceLocationAndSetInitialCenter();
    await _loadMapData(); // Renamed from loadInitialData for clarity

    _isLoading = false;
    notifyListeners(); // Notify UI that loading is complete and data (or error) is available
  }

  Future<void> _fetchDeviceLocationAndSetInitialCenter() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      pocketBaseService.logger.i("Checking location services...");
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled. Showing default map location.';
        pocketBaseService.logger.w(_errorMessage);
        // Keep default _initialCenter
        return; // Don't proceed further if services are off
      }
      pocketBaseService.logger.i("Location services enabled.");

      pocketBaseService.logger.i("Checking location permission...");
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        pocketBaseService.logger.i("Location permission denied, requesting...");
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'Location permissions are denied. Showing default map location.';
          pocketBaseService.logger.w(_errorMessage);
          return; // Keep default _initialCenter
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _errorMessage = 'Location permissions are permanently denied, we cannot request permissions. Showing default map location.';
        pocketBaseService.logger.w(_errorMessage);
        return; // Keep default _initialCenter
      } 
      pocketBaseService.logger.i("Location permission granted: $permission");

      pocketBaseService.logger.i("Fetching current position...");
      // Consider adding a timeout here for Geolocator.getCurrentPosition
      Position position = await Geolocator.getCurrentPosition(
        //desiredAccuracy: LocationAccuracy.high,
        // timeLimit: const Duration(seconds: 10) // Optional: add a timeout
      );
      _initialCenter = LatLng(position.latitude, position.longitude);
      pocketBaseService.logger.i('Device location fetched: $_initialCenter');
      _errorMessage = null; // Clear any previous location-related error message
    } catch (e) {
      _errorMessage = 'Could not get device location: ${e.toString()}. Showing default map location.';
      pocketBaseService.logger.e('Error fetching device location: $e');
      // Keep default _initialCenter in case of error
    }
    // No notifyListeners() here, _initializeMap will handle it after all async ops.
  }

  Future<void> _loadMapData() async {
    // _isLoading and _errorMessage are managed by _initializeMap
    // No need to set them here unless it's a specific error for this part.
    
    try {
      pocketBaseService.logger.i("Loading map data (users and areas)...");
      if (!pocketBaseService.isLoggedIn) {
        _errorMessage = "User not logged in. Cannot fetch map data.";
        pocketBaseService.logger.e(_errorMessage);
        // Clear existing data if any, as we can't refresh it
        _users = [];
        _areas = [];
        return; // Exit if not logged in
      }

      final usersFuture = pocketBaseService.fetchAllUsersData();
      final areasFuture = pocketBaseService.fetchAllAreasData();

      // Wait for all futures to complete
      final results = await Future.wait([usersFuture, areasFuture]);

      _users = results[0] as List<UserData>;
      _areas = results[1] as List<LocationData>;
      
      // If _fetchDeviceLocationAndSetInitialCenter had an error,
      // _errorMessage might be set. We don't want to overwrite it
      // unless _loadMapData itself succeeds.
      // If _fetchDeviceLocationAndSetInitialCenter succeeded, _errorMessage would be null.
      if (_errorMessage == null || _errorMessage!.contains("Could not get device location")) {
        // Only clear error if it was a location error and data load succeeded,
        // or if there was no error at all.
         _errorMessage = null;
      }
      pocketBaseService.logger.i("Map data loaded: ${_users.length} users, ${_areas.length} areas.");

    } catch (e, stackTrace) {
      // This error is specific to loading map data (users/areas)
      final dataLoadError = "Failed to load map data: ${e.toString()}";
      pocketBaseService.logger.e(dataLoadError, error: e, stackTrace: stackTrace);
      // Append to existing error message if it's a location error, otherwise set it.
      if (_errorMessage != null && _errorMessage!.contains("Could not get device location")) {
        _errorMessage = "$_errorMessage\nAdditionally, $dataLoadError";
      } else {
        _errorMessage = dataLoadError;
      }
      // Optionally clear data if fetch fails, or keep stale data
      // _users = []; 
      // _areas = [];
    }
    // isLoading and notifyListeners handled by _initializeMap
  }

  // Call this to re-fetch everything: location and map data
  void refreshData() {
    pocketBaseService.logger.i("Map data refresh initiated by user.");
    _initializeMap(); // This will set loading, fetch location, fetch data, then notify
  }

  void moveMap(LatLng center, double zoom) {
    pocketBaseService.logger.d("Moving map to Center: $center, Zoom: $zoom");
    _mapController.move(center, zoom);
  }
}
