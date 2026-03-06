import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'encryption_service.dart';
import 'db_service.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _supabase = Supabase.instance.client;
  final _secureStorage = const FlutterSecureStorage();
  static const _passwordKey = 'supabase_password';

  bool get isAuthenticated => _supabase.auth.currentUser != null;
  String? get currentUserId => _supabase.auth.currentUser?.id;
  String? get currentUserEmail => _supabase.auth.currentUser?.email;

  Future<bool> refreshSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return false;

      await _supabase.auth.refreshSession();
      if (_supabase.auth.currentUser == null) return false;

      final password = await _secureStorage.read(key: _passwordKey);
      if (password == null) {
        await _supabase.auth.signOut();
        return false;
      }

      encryptionService.init(password);
      DBService.db.setEncryptionKey(password);

      return true;
    } catch (e) {
      debugPrint('Session refresh error: $e');
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
      await _secureStorage.write(key: _passwordKey, value: password);
      encryptionService.init(password);
      DBService.db.setEncryptionKey(password);
    } catch (e) {
      throw Exception('Invalid email or password');
    }
  }

  Future<void> signOut() async {
    await _secureStorage.delete(key: _passwordKey);
    encryptionService.clearKey();
    await _supabase.auth.signOut();
  }
}
