import 'package:supabase_flutter/supabase_flutter.dart';

class Database {
  static Supabase? _supabase;
  static Future<void> initialize() async {
    _supabase = await Supabase.initialize(
      url: 'https://acrjeiyscacdtyxxsxid.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjcmplaXlzY2FjZHR5eHhzeGlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxNjg0MzMsImV4cCI6MjA4NTc0NDQzM30.mCnA44xS3a1zLFjYYbbMBwdMVCLQYZ7yMPiWsfJeCms',
    );
  }

  static Supabase get supabase {
    if (_supabase == null) {
      throw Exception('Database not initialized');
    }
    return _supabase!;
  }

  static SupabaseClient get client {
    if (_supabase == null) {
      throw Exception('Database not initialized');
    }
    return _supabase!.client;
  }
}
