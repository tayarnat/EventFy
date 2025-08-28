// lib/core/config/supabase_config.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://tpippisenkavuokfqves.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRwaXBwaXNlbmthdnVva2ZxdmVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYyNTk3OTYsImV4cCI6MjA3MTgzNTc5Nn0.22WACob6GQeUlPe8x2wY2GcXo8EWLtbwBlBvc6WoFkc';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}

// Getter global para facilitar acesso
SupabaseClient get supabase => Supabase.instance.client;