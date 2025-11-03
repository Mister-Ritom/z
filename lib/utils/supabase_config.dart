// Supabase Configuration
// Replace with your actual Supabase URL and Anon Key
class SupabaseConfig {
  static const String supabaseUrl = 'https://yhfbhjtudunmegnvxzee.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InloZmJoanR1ZHVubWVnbnZ4emVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwMTIzMzUsImV4cCI6MjA3NzU4ODMzNX0.r2A3dIThICPvOb_j_WHzyTwMcYD3qE972lMZAxPIISo';

  // For storage uploads, you may need a service role key
  // DO NOT expose this in production client-side code
  // Only use it server-side or with proper security
  static const String supabaseServiceKey = 'YOUR_SUPABASE_SERVICE_KEY';
}
