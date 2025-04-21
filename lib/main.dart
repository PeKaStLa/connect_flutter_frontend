import 'dart:convert'; // For jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async'; // Import for debounce

// --- UserData Class Definition ---
// Use this class specifically for user data
class UserData {
  final LatLng center;
  final String username;
  // final int id; // Optional: Add if you need the user ID later

  UserData({required this.center, required this.username /*, required this.id*/});
}
// --- End of UserData Class ---

// --- LocationData Class Definition ---
// Use this class for area data (includes radius)
class LocationData {
  final LatLng center;
  final double radius; // Radius in meters
  final String username; // Use 'username' to store the 'name' from the area JSON

  LocationData({required this.center, required this.radius, required this.username});
}
// --- End of LocationData Class ---


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Map Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // --- Future now holds results of BOTH fetches ---
  // It will be Future<List<dynamic>> where element 0 is List<UserData> and element 1 is List<LocationData>
  late Future<List<dynamic>> _mapDataFuture; // Renamed future

  // --- Keep zoom state ---
  double _currentZoom = 9.0; // Start zoomed out to see areas/users

  late MapController _mapController;
  Timer? _debounce;

  // Define fallback center
  final LatLng _fallbackCenter = const LatLng(-25.2744, 133.7751); // Center of Australia approx.

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // --- Fetch BOTH users and areas concurrently ---
    _mapDataFuture = Future.wait([
       _fetchAllUsersData(),   // Future<List<UserData>>
       _fetchAllAreasData(),   // Future<List<LocationData>>
    ]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // --- Function to fetch data for MULTIPLE USERS from a single endpoint ---
  Future<List<UserData>> _fetchAllUsersData() async {
    // Define the single endpoint URL for USERS
    // Adjust host/IP as needed (localhost, 10.0.2.2, network IP)
    const String apiUrl = 'http://localhost:8000/users'; // <--- Endpoint for USERS list

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> decodedList = jsonDecode(response.body);
        final List<UserData> users = [];

        for (var item in decodedList) {
          if (item is Map<String, dynamic> &&
              item.containsKey('latitude') &&
              item.containsKey('longitude') &&
              item.containsKey('username')) {

            final String? latStr = item['latitude'];
            final String? lngStr = item['longitude'];
            final String? username = item['username'];
            final int? id = item['id'];

            if (latStr != null && lngStr != null) {
              final double? lat = double.tryParse(latStr);
              final double? lng = double.tryParse(lngStr);

              if (lat != null && lng != null) {
                final fetchedLatLng = LatLng(lat, lng);
                print('Parsed User ${id ?? 'N/A'}: Lat: $lat, Lng: $lng, Name: $username');
                users.add(UserData(
                  center: fetchedLatLng,
                  username: username ?? "Unknown User ${id ?? 'N/A'}"
                ));
              } else {
                 print('Warning: Could not parse numeric data for user item: $item');
              }
            } else {
               print('Warning: Lat/Lng string is null for user item: $item');
            }
          } else {
             print('Warning: Skipping invalid item in users list: $item');
          }
        }
        print("Successfully parsed data for ${users.length} users.");
        return users;
      } else {
        print('Error: API request failed for users with status: ${response.statusCode}');
        print('Error body: ${response.body}');
        throw Exception('API request failed for users (Status: ${response.statusCode})');
      }
    } catch (e) {
      print("Error fetching or parsing users data: $e");
      return []; // Return empty list on error for this specific fetch
    }
  }
  // --- End fetchAllUsersData ---

  // --- Function to fetch data for MULTIPLE AREAS from a single endpoint ---
  Future<List<LocationData>> _fetchAllAreasData() async {
    // Define the single endpoint URL for AREAS
    // Adjust host/IP as needed (localhost, 10.0.2.2, network IP)
    const String apiUrl = 'http://localhost:8000/areas'; // <--- Endpoint for AREAS list

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> decodedList = jsonDecode(response.body);
        final List<LocationData> areas = [];

        for (var item in decodedList) {
          if (item is Map<String, dynamic> &&
              item.containsKey('latitude') &&
              item.containsKey('longitude') &&
              item.containsKey('radius') &&
              item.containsKey('name')) {

            final String? latStr = item['latitude'];
            final String? lngStr = item['longitude'];
            final String? radiusStr = item['radius'];
            final String? name = item['name'];
            final int? id = item['id'];

            if (latStr != null && lngStr != null && radiusStr != null) {
              final double? lat = double.tryParse(latStr);
              final double? lng = double.tryParse(lngStr);
              final double? radius = double.tryParse(radiusStr);

              if (lat != null && lng != null && radius != null) {
                final fetchedLatLng = LatLng(lat, lng);
                print('Parsed Area ${id ?? 'N/A'}: Lat: $lat, Lng: $lng, Radius: $radius, Name: $name');
                areas.add(LocationData(
                  center: fetchedLatLng,
                  radius: radius,
                  username: name ?? "Unknown Area ${id ?? 'N/A'}" // Store 'name' in 'username' field
                ));
              } else {
                 print('Warning: Could not parse numeric data for area item: $item');
              }
            } else {
               print('Warning: Lat/Lng/Radius string is null for area item: $item');
            }
          } else {
             print('Warning: Skipping invalid item in areas list: $item');
          }
        }
        print("Successfully parsed data for ${areas.length} areas.");
        return areas;
      } else {
        print('Error: API request failed for areas with status: ${response.statusCode}');
        print('Error body: ${response.body}');
        throw Exception('API request failed for areas (Status: ${response.statusCode})');
      }
    } catch (e) {
      print("Error fetching or parsing areas data: $e");
      return []; // Return empty list on error for this specific fetch
    }
  }
  // --- End fetchAllAreasData ---


  // --- Updated AppBar Title ---
  String _buildAppBarTitle() {
    // Reflect both data types being shown
    return 'Map View - Users & Areas | Zoom: ${_currentZoom.toStringAsFixed(1)}';
  }
  // --- End buildAppBarTitle ---

  // --- Function to handle map events (no change needed) ---
  void _handleMapEvent(MapEvent event) {
     if (_debounce?.isActive ?? false) _debounce!.cancel();
     _debounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _currentZoom = event.camera.zoom;
          });
          print('Map Event: ${event.runtimeType}, Source: ${event.source}, Zoom: ${event.camera.zoom}');
        }
     });
  }
  // --- End handleMapEvent ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          _buildAppBarTitle(), // Use updated title
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      // --- FutureBuilder now expects List<dynamic> ---
      body: FutureBuilder<List<dynamic>>( // Changed type parameter
        future: _mapDataFuture, // Use the combined future
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
             print("FutureBuilder Error: ${snapshot.error}");
             // Show map centered on fallback, pass empty lists
             return _buildMapWithControls(
                [], // Empty user list
                [], // Empty area list
                _fallbackCenter,
                _currentZoom,
                showErrorOverlay: true,
                errorMessage: "Failed to load map data: ${snapshot.error}"
              );
          } else if (snapshot.hasData) {
            // --- Safely extract the lists ---
            final List<dynamic> results = snapshot.data!;
            List<UserData> usersData = [];
            List<LocationData> areasData = [];

            if (results.length == 2 && results[0] is List<UserData> && results[1] is List<LocationData>) {
               usersData = results[0] as List<UserData>;
               areasData = results[1] as List<LocationData>;
               print("FutureBuilder received ${usersData.length} users and ${areasData.length} areas.");
            } else {
               // Handle unexpected result structure from Future.wait
               print("Error: Unexpected data structure from Future.wait. Results length: ${results.length}");
               if (results.isNotEmpty) print("Result[0] type: ${results[0].runtimeType}");
               if (results.length > 1) print("Result[1] type: ${results[1].runtimeType}");

               // Show map with error, pass empty lists
               return _buildMapWithControls(
                  [], [], _fallbackCenter, _currentZoom,
                  showErrorOverlay: true,
                  errorMessage: "Internal error processing map data."
               );
            }
            // ---------------------------------

            // Determine initial center (e.g., based on first user or fallback)
            final LatLng initialMapCenter = usersData.isNotEmpty ? usersData[0].center : _fallbackCenter;

            // Build map with controls using BOTH lists
            return _buildMapWithControls(
              usersData, // Pass the list of users
              areasData, // Pass the list of areas
              initialMapCenter,
              _currentZoom
            );
          } else {
            // Should not happen if future completes without error/data
             return _buildMapWithControls(
                [], [], _fallbackCenter, _currentZoom,
                showErrorOverlay: true,
                errorMessage: "No map data received."
              );
          }
        },
      ),
    );
  }

  // --- Wrapper Widget now accepts BOTH lists and initial center ---
  Widget _buildMapWithControls(List<UserData> usersData, List<LocationData> areasData, LatLng initialCenter, double initialZoom, {bool showErrorOverlay = false, String? errorMessage}) { // Added areasData
     return Stack(
       children: [
         // Pass BOTH lists and initial center down
         _buildMap(usersData, areasData, initialCenter, initialZoom, showErrorOverlay: showErrorOverlay, errorMessage: errorMessage), // Pass both lists

         // Zoom Buttons (no change needed here)
         Positioned(
           top: 20,
           right: 20,
           child: Column(
             children: [
               FloatingActionButton.small(
                 heroTag: "zoomInBtn",
                 tooltip: 'Zoom In',
                 onPressed: () {
                   final targetZoom = _mapController.camera.zoom + 1.0;
                   _mapController.move(_mapController.camera.center, targetZoom);
                 },
                 child: const Icon(Icons.add),
               ),
               const SizedBox(height: 8),
               FloatingActionButton.small(
                 heroTag: "zoomOutBtn",
                 tooltip: 'Zoom Out',
                 onPressed: () {
                   final targetZoom = _mapController.camera.zoom - 1.0;
                   _mapController.move(_mapController.camera.center, targetZoom);
                 },
                 child: const Icon(Icons.remove),
               ),
             ],
           ),
         ),
       ],
     );
  }
  // --- End buildMapWithControls ---


  // --- _buildMap now accepts BOTH lists and builds Markers AND Circles ---
  Widget _buildMap(List<UserData> usersData, List<LocationData> areasData, LatLng initialCenter, double initialZoom, {bool showErrorOverlay = false, String? errorMessage}) { // Added areasData
    print("Building map for ${usersData.length} users and ${areasData.length} areas. Initial Center: $initialCenter, Zoom: $initialZoom");

    // --- Create CircleMarkers from the area list ---
    List<CircleMarker> circles = areasData.map((area) { // Use areasData
      return CircleMarker(
        point: area.center,
        radius: area.radius,
        useRadiusInMeter: true,
        color: Colors.blue.withOpacity(0.3), // Area color
        borderColor: Colors.blue,
        borderStrokeWidth: 2,
      );
    }).toList();
    // --- END CircleMarker generation ---

    // --- Create Markers from the user list ---
    List<Marker> markers = usersData.map((user) { // Use usersData
       return Marker(
          point: user.center,
          width: 80,
          height: 80,
          child: Tooltip(
            message: '${user.username}\nLat: ${user.center.latitude.toStringAsFixed(4)}, Lng: ${user.center.longitude.toStringAsFixed(4)}',
            child: const Icon(Icons.person_pin_circle, color: Colors.deepPurple, size: 40), // User color/icon
          ),
       );
    }).toList();
    // --- END Marker generation ---


    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            onMapEvent: _handleMapEvent,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // IMPORTANT: Replace with your actual package name
              userAgentPackageName: 'com.peter.connect_flutter_frontend', // <-- Replace if needed
              tileProvider: CancellableNetworkTileProvider(),
            ),
            // --- Add BOTH layers ---
            CircleLayer(circles: circles),   // Display area circles
            MarkerLayer(markers: markers),   // Display user markers
            // -----------------------
          ],
        ),
        if (showErrorOverlay)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8.0),
              child: Text(
                errorMessage ?? 'Error loading map data.',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
  // --- End _buildMap ---

} // End _MapPageState
