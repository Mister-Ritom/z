import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/storage_service.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  // Initialize Supabase if not already initialized
  // In a real app, you'd initialize this in main.dart
  try {
    return Supabase.instance.client;
  } catch (e) {
    // Fallback - you should initialize Supabase in main.dart
    throw Exception('Supabase not initialized. Initialize in main.dart first.');
  }
});

final storageServiceProvider = Provider<StorageService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return StorageService(supabase);
});
