import 'package:supabase_flutter/supabase_flutter.dart';

class Database {
  static Supabase? _supabase;
  static Future<void> initialize() async {
    _supabase = await Supabase.initialize(
      url: 'https://acrjeiyscacdtyxxsxid.supabase.co',
      anonKey: 'sb_publishable_5WHjxmL1vxLF2fk6DDuz1A__uIQVLI0',
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
