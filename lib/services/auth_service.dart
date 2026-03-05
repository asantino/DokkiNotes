import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _supabase = Supabase.instance.client;

  bool get isAuthenticated => _supabase.auth.currentUser != null;
  String? get currentUserId => _supabase.auth.currentUser?.id;
  String? get currentUserEmail => _supabase.auth.currentUser?.email;

  Future<bool> refreshSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return false;
      await _supabase.auth.refreshSession();
      return _supabase.auth.currentUser != null;
    } catch (e) {
      await _supabase.auth.signOut();
      return false;
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Registration error: ${e.toString()}');
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Invalid email or password');
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
