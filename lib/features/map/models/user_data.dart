import 'package:latlong2/latlong.dart';

// Use this class specifically for user data
class UserData {
  final LatLng center;
  final String username;
  final String id; // Store PocketBase record ID

  UserData({required this.center, required this.username, required this.id});
}