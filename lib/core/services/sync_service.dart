import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/collection_event.dart';
import 'storage_service.dart';
import 'backend_auth_service.dart';

class SyncService {
  static const String apiBaseUrl = BackendAuthService.defaultApiBaseUrl;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _syncTimer;

  bool _isSyncing = false;
  Function(int)? onSyncProgress;
  Function(bool)? onSyncComplete;

  SyncService() {
    _init();
  }

  void _init() {
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        if (result != ConnectivityResult.none) {
          syncPendingEvents();
        }
      },
    );

    // Periodic sync every 5 minutes when connected
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncPendingEvents();
    });
  }

  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> syncPendingEvents() async {
    if (_isSyncing) return;

    final connected = await isConnected();
    if (!connected) return;

    _isSyncing = true;

    try {
      final unsyncedEvents = StorageService.getUnsyncedEvents();

      if (unsyncedEvents.isEmpty) {
        onSyncComplete?.call(true);
        return;
      }

      int syncedCount = 0;

      for (final event in unsyncedEvents) {
        try {
          final success = await _syncEvent(event);
          if (success) {
            syncedCount++;
            onSyncProgress?.call(syncedCount);
          }
        } catch (e) {
          print('Error syncing event ${event.id}: $e');
        }
      }

      onSyncComplete?.call(syncedCount == unsyncedEvents.length);
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _syncEvent(CollectionEvent event) async {
    try {
      final token = await BackendAuthService.getValidToken();
      final apiUrl =
          StorageService.getSetting('apiBaseUrl', defaultValue: apiBaseUrl);

      final payload = {
        'species': event.species,
        'quantity': event.weight ?? 0,
        'unit': 'kg',
        'latitude': event.latitude,
        'longitude': event.longitude,
        'altitude': event.altitude,
        'accuracy': event.latitudeAccuracy,
        'harvestDate': event.timestamp.toIso8601String().split('T')[0],
        'images': event.imagePaths,
        'moisture': event.moisture,
        'temperature': event.temperature,
        'humidity': event.humidity,
        'weatherConditions': event.weatherCondition,
        'commonName': event.commonName,
        'scientificName': event.scientificName,
        'harvestMethod': event.harvestMethod,
        'partCollected': event.partCollected,
        'locationName': event.locationName,
        'soilType': event.soilType,
        'notes': event.notes,
      };

      final response = await http
          .post(
            Uri.parse('$apiUrl/api/v1/collections'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final blockchainHash = responseData['blockchainHash'] ?? 'synced';

        await StorageService.markEventAsSynced(event.id, blockchainHash);
        return true;
      }

      return false;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchProvenanceData(String batchId) async {
    try {
      final token = await BackendAuthService.getValidToken();
      final apiUrl =
          StorageService.getSetting('apiBaseUrl', defaultValue: apiBaseUrl);

      // Check cache first
      final cached = StorageService.getCachedData(
        'provenance_$batchId',
        maxAge: const Duration(hours: 24),
      );

      if (cached != null) {
        return Map<String, dynamic>.from(cached);
      }

      final response = await http.get(
        Uri.parse('$apiUrl/api/v1/provenance/$batchId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Cache the response
        await StorageService.cacheData('provenance_$batchId', data);

        return data;
      }

      return null;
    } catch (e) {
      print('Fetch provenance error: $e');

      // Try to return cached data even if expired
      final cached = StorageService.getCachedData('provenance_$batchId');
      return cached != null ? Map<String, dynamic>.from(cached) : null;
    }
  }

  Future<void> recordScan(String batchId, String userId) async {
    try {
      final token = await BackendAuthService.getValidToken();
      final apiUrl =
          StorageService.getSetting('apiBaseUrl', defaultValue: apiBaseUrl);

      await http
          .post(
            Uri.parse('$apiUrl/api/v1/scans'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'batchId': batchId,
              'userId': userId,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Record scan error: $e');
      // Silently fail - not critical
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
  }
}
