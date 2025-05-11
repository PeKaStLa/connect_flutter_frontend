import 'package:latlong2/latlong.dart';

// Use this class for area data (includes radius)
class LocationData {
  final LatLng center;
  final double radius; // Radius in meters
  final String username; //
  final String id; // Store PocketBase record ID

  LocationData({required this.center, required this.radius, required this.username, required this.id});
}