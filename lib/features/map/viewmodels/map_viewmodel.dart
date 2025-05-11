import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';

import '../../../core/services/pocketbase_service.dart';
import '../models/user_data.dart';
import '../models/location_data.dart';

class MapViewModel extends ChangeNotifier {
  final PocketBaseService _pbService;
  final Logger _logger = Logger(); // Or use _pbService.logger

  List<UserData> _users = [];
  List<LocationData> _areas = [];
  bool _isLoading = true;
  String? _errorMessage;
  double _currentZoom = 10.0;
  final MapController _mapController = MapController();
  Timer? _debounce;
  final LatLng _fallbackCenter = const LatLng(52.5200, 13.4050); // Berlin
  LatLng? _initialMapCenter;

  List<UserData> get users => _users;
  List<LocationData> get areas => _areas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get currentZoom => _currentZoom;
  MapController get mapController => _mapController;
  LatLng get initialMapCenter => _initialMapCenter ?? _fallbackCenter;
  String get appBarTitle => 'Map View (MVVM) | Zoom: ${_currentZoom.toStringAsFixed(1)}';


  MapViewModel({PocketBaseService? pocketBaseService})
      : _pbService = pocketBaseService ?? PocketBaseService() {
    _logger.i("MapViewModel initialized. Loading map data...");
    loadMapData();
  }

  Future<void> loadMapData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _pbService.authenticate();
      _logger.i("Authentication successful/valid, fetching map data...");

      final results = await Future.wait([
        _pbService.fetchAllUsersData(),
        _pbService.fetchAllAreasData(),
      ]);

      _users = results[0] as List<UserData>;
      _areas = results[1] as List<LocationData>;

      _logger.i("Successfully fetched ${_users.length} users and ${_areas.length} areas.");

      if (_users.isNotEmpty) {
        _initialMapCenter = _users[0].center;
      } else if (_areas.isNotEmpty) {
        _initialMapCenter = _areas[0].center;
      } else {
        _initialMapCenter = _fallbackCenter;
      }

    } catch (e, stackTrace) {
      _logger.e("Error loading map data", error: e, stackTrace: stackTrace);
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void handleMapEvent(MapEvent event) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (event.camera.zoom != _currentZoom) { // Only update if zoom actually changed
        _currentZoom = event.camera.zoom;
        _logger.d("Map zoom updated to: $_currentZoom");
        notifyListeners(); // For app bar title update
      }
    });
  }

  void zoomIn() {
    final targetZoom = _mapController.camera.zoom + 1.0;
    _mapController.move(_mapController.camera.center, targetZoom);
    // handleMapEvent will update _currentZoom via onMapEvent
  }

  void zoomOut() {
    final targetZoom = _mapController.camera.zoom - 1.0;
    _mapController.move(_mapController.camera.center, targetZoom);
    // handleMapEvent will update _currentZoom via onMapEvent
  }

  @override
  void dispose() {
    _logger.i("MapViewModel disposing.");
    _debounce?.cancel();
    _mapController.dispose(); // Dispose map controller
    super.dispose();
  }
}