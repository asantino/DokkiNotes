import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class PinService {
  static final PinService _instance = PinService._internal();
  factory PinService() => _instance;
  PinService._internal();

  final _storage = const FlutterSecureStorage();
  static const _pinKey = 'dokki_user_pin';

  // Проверка, установлен ли PIN
  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null;
  }

  // Сохранить PIN (хешированный)
  Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hash);
  }

  // Проверить PIN
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return false;

    final inputHash = _hashPin(pin);
    return storedHash == inputHash;
  }

  // Удалить PIN
  Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
  }

  // Хеширование PIN
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Получить PIN для шифрования (не хеш, а сам PIN)
  // ВНИМАНИЕ: используется только для шифрования
  Future<String?> getPinForEncryption(String inputPin) async {
    final isValid = await verifyPin(inputPin);
    if (!isValid) return null;
    return inputPin; // Возвращаем оригинальный PIN для использования в шифровании
  }
}

final pinService = PinService();
