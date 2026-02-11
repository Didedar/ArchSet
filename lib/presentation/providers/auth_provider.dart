import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/auth_service.dart';
import 'notes_provider.dart';

/// Provider for AuthService
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  final database = ref.watch(databaseProvider);
  return AuthService(database: database);
});
