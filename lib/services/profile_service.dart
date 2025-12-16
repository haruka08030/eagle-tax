import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eagle_tax/models/profile.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetches the profile for the current user.
  // Returns null if no profile is found.
  Future<Profile?> getProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      return Profile.fromJson(response);
    } catch (e) {
      // This can happen if the profile doesn't exist yet, which is not a critical error.
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }
}

