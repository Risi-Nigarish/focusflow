class SupabaseConfig {
  // Replace these with your actual Supabase project credentials.
  // You can find them in your Supabase Dashboard under Project Settings -> API.
  static const String url = 'https://nvvuxbtodkamuxrhiqrj.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dnV4YnRvZGthbXV4cmhpcXJqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3MzA2ODEsImV4cCI6MjA5NjMwNjY4MX0.9GZce4z0M5rWayjEH6PjyZd3g-ez9ohcnBURpG7nc04';

  /// Helper getter to check if the credentials have been configured.
  static bool get isConfigured {
    return url != 'YOUR_SUPABASE_URL' && 
           anonKey != 'YOUR_SUPABASE_ANON_KEY' &&
           url.trim().isNotEmpty &&
           anonKey.trim().isNotEmpty &&
           url.startsWith('http');
  }
}
