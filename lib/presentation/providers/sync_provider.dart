import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/api_service.dart';

import 'notes_provider.dart';
import 'auth_provider.dart';

/// Provider for SyncService
final syncServiceProvider = Provider<SyncService>((ref) {
  // Use AuthService to create ApiService
  final authService = ref.watch(authServiceProvider);
  final apiService = ApiService(authService: authService);

  final database = ref.watch(databaseProvider);

  final service = SyncService(apiService: apiService, database: database);

  // Start monitoring connectivity when provider is initialized
  service.startMonitoring();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Stream of sync status
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.statusStream;
});

/// Stream of sync results
final syncResultProvider = StreamProvider<SyncResult>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.resultStream;
});
