import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/auth_service.dart';
import 'notes_provider.dart';

/// Provider for AuthService. Plain [Provider] (not ChangeNotifierProvider)
/// since AuthBloc now owns reactive auth state (Phase 2) -- this remains
/// only for the not-yet-migrated call sites that need a static reference
/// (sync_provider.dart, diary_edit_page.dart).
final authServiceProvider = Provider<AuthService>((ref) {
  final database = ref.watch(databaseProvider);
  return AuthService(database: database);
});
