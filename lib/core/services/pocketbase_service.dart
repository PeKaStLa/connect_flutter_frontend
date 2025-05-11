import 'dart:convert'; // For jsonEncode in detailed logging
import 'package:pocketbase/pocketbase.dart';
import 'package:logger/logger.dart';
import 'package:latlong2/latlong.dart';

import '../../features/map/models/user_data.dart';
import '../../features/map/models/location_data.dart';
import '../utils/parsing_utils.dart';

// --- PocketBase Credentials ---
// NOTE: It's generally not secure to hardcode credentials directly in the source code
// Consider using environment variables or a secure configuration method for production.
const String _pbUserEmail = 'test@gmail.com';
const String _pbUserPassword = '1234567asdf'; // <-- Be careful with hardcoding passwords

class PocketBaseService {
  final PocketBase _pb = PocketBase('https://connect.pockethost.io/');
  final Logger _logger = Logger();

  PocketBase get client => _pb; // Expose client if needed elsewhere, though unlikely with service pattern
  Logger get logger => _logger; // Expose logger if needed by ViewModel directly

  Future<void> authenticate() async {
    try {
      if (!_pb.authStore.isValid) {
        _logger.i("Attempting PocketBase authentication with $_pbUserEmail...");
        final authData = await _pb.collection('users').authWithPassword(
              _pbUserEmail,
              _pbUserPassword,
            );
        _logger.i('Authentication successful. Token: ${authData.token}');
        _logger.d('Authenticated user model: ${authData.record}');
      } else {
        _logger.i("PocketBase auth token is still valid. Skipping re-authentication.");
        _logger.d('Current user model: ${_pb.authStore.record}');
      }
    } on ClientException catch (e) {
      _logger.e("PocketBase Authentication Failed: ${e.statusCode} ${e.response}", error: e.originalError, stackTrace: StackTrace.current);
      throw Exception('Auth Failed: ${e.response['message'] ?? 'Invalid credentials or server error'} (Status: ${e.statusCode})');
    } catch (e, stackTrace) {
      _logger.e("An unexpected error occurred during authentication", error: e, stackTrace: stackTrace);
      throw Exception('An unexpected error occurred during auth: $e');
    }
  }

  Future<List<UserData>> fetchAllUsersData() async {
    const String usersCollection = 'users';
    _logger.i("Fetching users from '$usersCollection' collection...");
    try {
      final List<RecordModel> records = await _pb.collection(usersCollection).getFullList(sort: '-created');
      _logger.i('PB-response (Users): Fetched ${records.length} records');

      _logger.d('--- Raw User Records Data ---');
      if (records.isEmpty) {
        _logger.d('(No user records found)');
      } else {
        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          try {
            _logger.t('User Record [$i] ID: ${record.id}, Data: ${jsonEncode(record.data)}');
          } catch (e) {
            _logger.w('User Record [$i] ID: ${record.id}, Data: ${record.data} (jsonEncode failed: $e)');
          }
        }
      }
      _logger.d('--- End Raw User Records Data ---');

      final List<UserData> users = [];
      for (var record in records) {
        final Map<String, dynamic> data = record.data;
        final dynamic latValue = data['latitude'];
        final dynamic lngValue = data['longitude'];
        final String? username = data['username']?.toString() ?? data['name']?.toString();
        final String recordId = record.id;
        final double? lat = ParsingUtils.parseDouble(latValue);
        final double? lng = ParsingUtils.parseDouble(lngValue);

        _logger.t('Parsing User ID: $recordId - LatValue: "$latValue" (${latValue?.runtimeType}), LngValue: "$lngValue" (${lngValue?.runtimeType}) -> Parsed Lat: $lat, Parsed Lng: $lng');

        if (lat != null && lng != null) {
          _logger.d('  -> SUCCESS: Adding user $recordId to map data.');
          users.add(UserData(
            center: LatLng(lat, lng),
            username: username ?? "User $recordId",
            id: recordId,
          ));
        } else {
          _logger.w('  -> WARNING: Skipping user $recordId due to invalid/missing lat/lng. Raw data: ${record.data}');
        }
      }
      _logger.i("Successfully processed ${records.length} user records. Added ${users.length} valid users to map data.");
      return users;
    } on ClientException catch (e, stackTrace) {
      _logger.e("PocketBase ClientException fetching users: ${e.statusCode} ${e.response}", error: e.originalError, stackTrace: stackTrace);
      throw Exception('PocketBase request failed for users (Status: ${e.statusCode}) - ${e.response['message'] ?? 'Unknown PocketBase Error'}');
    } catch (e, stackTrace) {
      _logger.e("Error fetching or parsing users data from PocketBase", error: e, stackTrace: stackTrace);
      throw Exception('Failed to process user data from PB: $e');
    }
  }

  Future<List<LocationData>> fetchAllAreasData() async {
    const String areasCollection = 'areas';
    _logger.i("Fetching areas from '$areasCollection' collection...");
    try {
      final List<RecordModel> records = await _pb.collection(areasCollection).getFullList();
      _logger.i('PB-response (Areas): Fetched ${records.length} records');

      _logger.d('--- Raw Area Records Data ---');
      // ... (similar detailed logging as for users) ...
      _logger.d('--- End Raw Area Records Data ---');

      final List<LocationData> areas = [];
      for (var record in records) {
        final Map<String, dynamic> data = record.data;
        final double? lat = ParsingUtils.parseDouble(data['latitude']);
        final double? lng = ParsingUtils.parseDouble(data['longitude']);
        final double? radius = ParsingUtils.parseDouble(data['radius']);
        final String? name = data['name']?.toString();
        final String recordId = record.id;

        if (lat != null && lng != null && radius != null) {
          areas.add(LocationData(
            center: LatLng(lat, lng),
            radius: radius,
            username: name ?? "Area $recordId",
            id: recordId,
          ));
        } else {
          _logger.w('  -> WARNING: Skipping area $recordId due to invalid/missing lat/lng/radius. Raw data: ${record.data}');
        }
      }
      _logger.i("Successfully processed ${records.length} area records. Added ${areas.length} valid areas to map data.");
      return areas;
    } on ClientException catch (e, stackTrace) {
      _logger.e("PocketBase ClientException fetching areas: ${e.statusCode} ${e.response}", error: e.originalError, stackTrace: stackTrace);
      throw Exception('PocketBase request failed for areas (Status: ${e.statusCode}) - ${e.response['message'] ?? 'Unknown PocketBase Error'}');
    } catch (e, stackTrace) {
      _logger.e("Error fetching or parsing areas data from PocketBase", error: e, stackTrace: stackTrace);
      throw Exception('Failed to process area data from PB: $e');
    }
  }
}