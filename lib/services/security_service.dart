import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  static const _passwordKey = 'dokki_master_password_hash';

  // --- 1. БИОМЕТРИЯ (local_auth 3.0.0) ---

  // Проверка доступности биометрии на устройстве
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      return false;
    }
  }

  // Включение/отключение биометрии в настройках
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      // Если пытаемся включить, сначала проверяем доступность
      if (enabled) {
        final available = await canCheckBiometrics();
        if (!available) return false;

        // Запрашиваем аутентификацию для подтверждения
        final authenticated = await authenticate();
        if (!authenticated) return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck || !isSupported) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Confirm identity',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // --- 2. УПРАВЛЕНИЕ ПАРОЛЕМ ---
  Future<bool> hasPassword() async {
    final hash = await _storage.read(key: _passwordKey);
    return hash != null;
  }

  Future<void> setPassword(String password) async {
    final hash = _hashPassword(password);
    await _storage.write(key: _passwordKey, value: hash);
  }

  Future<void> deletePassword() async {
    await _storage.delete(key: _passwordKey);
  }

  Future<bool> checkPassword(String inputPassword) async {
    final storedHash = await _storage.read(key: _passwordKey);
    if (storedHash == null) return false;
    final inputHash = _hashPassword(inputPassword);
    return storedHash == inputHash;
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // --- 3. ШИФРОВАНИЕ ---
  enc.Key _generateKey(String password) {
    final hash = _hashPassword(password);
    // Берем первые 32 байта хеша
    return enc.Key.fromUtf8(hash.substring(0, 32));
  }

  enc.IV _generateIV(String password) {
    final hash = _hashPassword(password);
    // Берем первые 16 байт хеша
    return enc.IV.fromUtf8(hash.substring(0, 16));
  }

  String encryptText(String plainText, String password) {
    if (plainText.isEmpty) return '';
    try {
      final key = _generateKey(password);
      final iv = _generateIV(password);
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.encrypt(plainText, iv: iv).base64;
    } catch (e) {
      return plainText;
    }
  }

  String decryptText(String encryptedText, String password) {
    if (encryptedText.isEmpty) return '';
    try {
      final key = _generateKey(password);
      final iv = _generateIV(password);
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt64(encryptedText, iv: iv);
    } catch (e) {
      return "Decryption error";
    }
  }
}
