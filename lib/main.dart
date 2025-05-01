import 'dart:convert'; // Keep for now, might be needed elsewhere, but not for PB fetch
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
// import 'package:http/http.dart' as http; // No longer needed for users/areas
import 'dart:async'; // Import for debounce
import 'package:pocketbase/pocketbase.dart'; // Import PocketBase
import 'package:logger/logger.dart'; // Import the logger package

// --- PocketBase Instance ---
// NOTE: It's generally not secure to hardcode credentials directly in the source code
// Consider using environment variables or a secure configuration method for production.
const String _pbUserEmail = 'test@gmail.com';
const String _pbUserPassword = '1234567asdf'; // <-- Be careful with hardcoding passwords

final pb = PocketBase('https://connect.pockethost.io/');
// --- End PocketBase Instance ---

// --- Logger Instance ---
final logger = Logger();
// --- End Logger Instance ---


// --- UserData Class Definition ---
// Use this class specifically for user data
class UserData {
  final LatLng center;
  final String username;
  final String id; // Store PocketBase record ID

  UserData({required this.center, required this.username, required this.id}); // Added id
}
// --- End of UserData Class ---

// --- LocationData Class Definition ---
// Use this class for area data (includes radius)
class LocationData {
  final LatLng center;
  final double radius; // Radius in meters
  final String username; // Use 'username' to store the 'name' from the area JSON
  final String id; // Store PocketBase record ID

  LocationData({required this.center, required this.radius, required this.username, required this.id}); // Added id
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
  // --- Future now holds results of BOTH fetches, AFTER authentication ---
  late Future<List<dynamic>> _mapDataFuture;

  // --- Keep zoom state ---
  double _currentZoom = 10.0; // Start zoomed out to see areas/users

  late MapController _mapController;
  Timer? _debounce;

  // Define fallback center
  final LatLng _fallbackCenter = const LatLng(52.5200, 13.4050); // Berlin

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // --- Trigger authentication AND THEN data fetching ---
    _mapDataFuture = _authenticateAndFetchData(); // Assign the combined future
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    // Optional: Clear auth store on dispose if needed, depends on app flow
    // pb.authStore.clear();
    super.dispose();
  }

  // --- NEW: Function to Authenticate and then Fetch Data ---
  Future<List<dynamic>> _authenticateAndFetchData() async {
    try {
      // Check if already valid (optional, avoids re-auth if token is still good)
      if (!pb.authStore.isValid) {
         logger.i("Attempting PocketBase authentication with $_pbUserEmail...");
         final authData = await pb.collection('users').authWithPassword(
           _pbUserEmail,
           _pbUserPassword,
         );
         // You can access the authenticated user model via authData.record
         // and the token via authData.token
         logger.i('Authentication successful. Token: ${authData.token}');
         logger.d('Authenticated user model: ${authData.record}'); // Use debug for detailed info
      } else {
         logger.i("PocketBase auth token is still valid. Skipping re-authentication.");
         logger.d('Current user model: ${pb.authStore.record}'); // Use debug for detailed info
      }


      // Now that authentication is done (or was already valid), fetch the data
      logger.i("Authentication successful/valid, fetching map data...");
      // Use Future.wait to fetch both concurrently AFTER auth
      // The global 'pb' instance now holds the auth token
      logger.d("Fetching users and areas concurrently...");
      return await Future.wait([
        _fetchAllUsersData(),
        _fetchAllAreasData(),
      ]);

    } on ClientException catch (e) {
      logger.e("PocketBase Authentication or Fetch Failed: ${e.statusCode} ${e.response}");
      logger.e("PocketBase Authentication or Fetch Failed: ${e.statusCode} ${e.response}", error: e.originalError, stackTrace: StackTrace.current);
      // Rethrow a user-friendly exception for the FutureBuilder
      throw Exception('Auth/Fetch Failed: ${e.response['message'] ?? 'Invalid credentials or server error'} (Status: ${e.statusCode})');
    } catch (e) {
      logger.e("An unexpected error occurred during authentication or data fetch", error: e, stackTrace: StackTrace.current);
      // Rethrow for the FutureBuilder
      throw Exception('An unexpected error occurred during auth/fetch: $e');
    }
  }
  // --- End Authenticate and Fetch Data ---


  // --- Helper function to safely parse doubles from dynamic values ---
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    // *** Added check for empty string specifically ***
    if (value is String) {
      if (value.trim().isEmpty) return null; // Treat empty strings as null
      return double.tryParse(value);
    }
    return null;
  }
  // --- End helper function ---


  // --- Function to fetch data for MULTIPLE USERS from PocketBase ---
  Future<List<UserData>> _fetchAllUsersData() async {
    const String usersCollection = 'users';
    logger.i("Fetching users from '$usersCollection' collection...");
    try {
      final List<RecordModel> records = await pb.collection(usersCollection).getFullList(sort: '-created');
      logger.i('PB-response (Users): Fetched ${records.length} records');

      // --- Add detailed logging ---
      logger.d('--- Raw User Records Data ---');
      if (records.isEmpty) {
        logger.d('(No user records found)');
      } else {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          // Use jsonEncode for potentially better formatting of the map
          try {
            logger.t('User Record [$i] ID: ${record.id}, Data: ${jsonEncode(record.data)}'); // Use trace for very verbose data
          } catch (e) {
             logger.w('User Record [$i] ID: ${record.id}, Data: ${record.data} (jsonEncode failed: $e)');
          }
        }
      }
      logger.d('--- End Raw User Records Data ---');
      // --- End detailed logging ---

      final List<UserData> users = [];
      for (var record in records) {
        final Map<String, dynamic> data = record.data;
        final dynamic latValue = data['latitude'];
        final dynamic lngValue = data['longitude'];
        final String? username = data['username']?.toString() ?? data['name']?.toString();
        final String recordId = record.id;
        final double? lat = _parseDouble(latValue);
        final double? lng = _parseDouble(lngValue);

        // Add logging for parsed values BEFORE the check
        logger.t('Parsing User ID: $recordId - LatValue: "$latValue" (${latValue?.runtimeType}), LngValue: "$lngValue" (${lngValue?.runtimeType}) -> Parsed Lat: $lat, Parsed Lng: $lng');

        if (lat != null && lng != null) {
          logger.d('  -> SUCCESS: Adding user $recordId to map data.'); // Log success
          final fetchedLatLng = LatLng(lat, lng);
          users.add(UserData(
            center: fetchedLatLng,
            username: username ?? "User $recordId",
            id: recordId,
          ));
        } else {
           // This warning is still useful
           logger.w('  -> WARNING: Skipping user $recordId due to invalid/missing lat/lng. Raw data: ${record.data}');
           // The raw data was printed above, so no need to repeat it here unless needed
        }
      }
      logger.i("Successfully processed ${records.length} user records. Added ${users.length} valid users to map data.");
      return users;

    } on ClientException catch (e) {
      logger.e("PocketBase ClientException fetching users: ${e.statusCode} ${e.response}", error: e.originalError, stackTrace: StackTrace.current);
      throw Exception('PocketBase request failed for users (Status: ${e.statusCode}) - ${e.response['message'] ?? 'Unknown PocketBase Error'}');
    } catch (e) {
      logger.e("Error fetching or parsing users data from PocketBase", error: e, stackTrace: StackTrace.current);
      throw Exception('Failed to process user data from PB: $e');
    }
  }
  // --- End fetchAllUsersData ---

  // --- Function to fetch data for MULTIPLE AREAS from PocketBase ---
  Future<List<LocationData>> _fetchAllAreasData() async {
    const String areasCollection = 'areas';
    logger.i("Fetching areas from '$areasCollection' collection...");
    try {
      final List<RecordModel> records = await pb.collection(areasCollection).getFullList();
      logger.i('PB-response (Areas): Fetched ${records.length} records');

      // --- Add detailed logging ---
      logger.d('--- Raw Area Records Data ---');
       if (records.isEmpty) {
        logger.d('(No area records found)');
      } else {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
           // Use jsonEncode for potentially better formatting of the map
          try {
            logger.t('Area Record [$i] ID: ${record.id}, Data: ${jsonEncode(record.data)}'); // Use trace
          } catch (e) {
             logger.w('Area Record [$i] ID: ${record.id}, Data: ${record.data} (jsonEncode failed: $e)');
          }
        }
      }
      logger.d('--- End Raw Area Records Data ---');
      // --- End detailed logging ---

      final List<LocationData> areas = [];
      for (var record in records) {
        final Map<String, dynamic> data = record.data;
        final dynamic latValue = data['latitude'];
        final dynamic lngValue = data['longitude'];
        final dynamic radiusValue = data['radius'];
        final String? name = data['name']?.toString();
        final String recordId = record.id;
        final double? lat = _parseDouble(latValue);
        final double? lng = _parseDouble(lngValue);
        final double? radius = _parseDouble(radiusValue);

        // Add logging for parsed values BEFORE the check
        logger.t('Parsing Area ID: $recordId - LatValue: "$latValue" (${latValue?.runtimeType}), LngValue: "$lngValue" (${lngValue?.runtimeType}), RadiusValue: "$radiusValue" (${radiusValue?.runtimeType}) -> Parsed Lat: $lat, Parsed Lng: $lng, Parsed Radius: $radius');

        if (lat != null && lng != null && radius != null) {
           logger.d('  -> SUCCESS: Adding area $recordId to map data.'); // Log success
          final fetchedLatLng = LatLng(lat, lng);
          areas.add(LocationData(
            center: fetchedLatLng,
            radius: radius,
            username: name ?? "Area $recordId",
            id: recordId,
          ));
        } else {
          // This warning is still useful
           logger.w('  -> WARNING: Skipping area $recordId due to invalid/missing lat/lng/radius. Raw data: ${record.data}');
           // The raw data was printed above, so no need to repeat it here unless needed
        }
      }
      logger.i("Successfully processed ${records.length} area records. Added ${areas.length} valid areas to map data.");
      return areas;

    } on ClientException catch (e) {
      logger.e("PocketBase ClientException fetching areas: ${e.statusCode} ${e.response}", error: e.originalError, stackTrace: StackTrace.current);
      throw Exception('PocketBase request failed for areas (Status: ${e.statusCode}) - ${e.response['message'] ?? 'Unknown PocketBase Error'}');
    } catch (e) {
      logger.e("Error fetching or parsing areas data from PocketBase", error: e, stackTrace: StackTrace.current);
      throw Exception('Failed to process area data from PB: $e');
    }
  }
  // --- End fetchAllAreasData ---


  // --- Updated AppBar Title ---
  String _buildAppBarTitle() {
    // Reflect both data types being shown
    return 'Map View (PB Authenticated) | Zoom: ${_currentZoom.toStringAsFixed(1)}'; // Updated title
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
      // --- FutureBuilder now waits for _authenticateAndFetchData ---
      body: FutureBuilder<List<dynamic>>(
        future: _mapDataFuture, // Use the future that includes authentication
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show different message while authenticating/fetching
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
          } else if (snapshot.hasError) {
             logger.e("FutureBuilder Error in _mapDataFuture", error: snapshot.error, stackTrace: snapshot.stackTrace);
             // Error could be from Auth OR Fetch
             return _buildMapWithControls(
                [], [], _fallbackCenter, _currentZoom,
                showErrorOverlay: true,
                // Display the specific error message from the exception
                errorMessage: "Error: ${snapshot.error is Exception ? (snapshot.error as Exception).toString().replaceFirst('Exception: ', '') : snapshot.error.toString()}"
              );
          } else if (snapshot.hasData) {
            // --- Safely extract the lists (same logic as before) ---
            final List<dynamic> results = snapshot.data!;
            List<UserData> usersData = [];
            List<LocationData> areasData = [];

            if (results.length == 2 && results[0] is List<UserData> && results[1] is List<LocationData>) {
               usersData = results[0] as List<UserData>;
               areasData = results[1] as List<LocationData>;
               logger.i("FutureBuilder received ${usersData.length} users and ${areasData.length} areas after auth.");
            } else {
               logger.f("Fatal Error: Unexpected data structure from Future.wait after auth. Results: $results"); // Use fatal for critical errors
               return _buildMapWithControls(
                  [], [], _fallbackCenter, _currentZoom,
                  showErrorOverlay: true,
                  errorMessage: "Internal error processing map data after auth."
               );
            }
            // ---------------------------------

            final LatLng initialMapCenter = usersData.isNotEmpty
                ? usersData[0].center
                : areasData.isNotEmpty
                    ? areasData[0].center
                    : _fallbackCenter;

            return _buildMapWithControls(
              usersData,
              areasData,
              initialMapCenter,
              _currentZoom
            );
          } else {
             return _buildMapWithControls(
                [], [], _fallbackCenter, _currentZoom,
                showErrorOverlay: true,
                errorMessage: "No map data received after authentication."
              );
          }
        },
      ),
    );
  }

  // --- Wrapper Widget now accepts BOTH lists and initial center ---
  Widget _buildMapWithControls(List<UserData> usersData, List<LocationData> areasData, LatLng initialCenter, double initialZoom, {bool showErrorOverlay = false, String? errorMessage}) {
     return Stack(
       children: [
         _buildMap(usersData, areasData, initialCenter, initialZoom, showErrorOverlay: showErrorOverlay, errorMessage: errorMessage),
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
  Widget _buildMap(List<UserData> usersData, List<LocationData> areasData, LatLng initialCenter, double initialZoom, {bool showErrorOverlay = false, String? errorMessage}) {
    logger.i("Building map for ${usersData.length} users and ${areasData.length} areas. Initial Center: $initialCenter, Zoom: $initialZoom"); 

    List<CircleMarker> circles = areasData.map((area) {
      return CircleMarker(
        point: area.center,
        radius: area.radius,
        useRadiusInMeter: true,
        color: Colors.blue.withValues(alpha: 0.3),
        borderColor: Colors.blue,
        borderStrokeWidth: 2,
      );
    }).toList();

    List<Marker> markers = usersData.map((user) {
       final double markerSize = _currentZoom;
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
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: _currentZoom,
            onMapEvent: _handleMapEvent,
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
              color: Colors.redAccent.withValues(alpha: 0.8),
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
  // --- End _buildMap ---

} // End _MapPageState
