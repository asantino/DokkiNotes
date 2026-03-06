import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class PinService {
  static final PinService _instance = PinService._internal();
  factory PinService() => _instance;
  PinService._internal();

  final _storage = const FlutterSecureStorage();
  static const _pinKey = 'dokki_user_pin';
  static const _pinRawKey = 'dokki_user_pin_raw';

  // Проверка, установлен ли PIN
  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null;
  }

  // Сохранить PIN (хешированный) и raw PIN
  Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hash);
    await _storage.write(key: _pinRawKey, value: pin);
  }

  // Проверить PIN
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return false;

    final inputHash = _hashPin(pin);
    return storedHash == inputHash;
  }

  // Удалить PIN и raw PIN
  Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _pinRawKey);
  }

  // Сохранить raw PIN для биометрии
  Future<void> setPinRaw(String pin) async {
    await _storage.write(key: _pinRawKey, value: pin);
  }

  // Получить raw PIN после успешной биометрии
  Future<String?> getPinRaw() async {
    return await _storage.read(key: _pinRawKey);
  }

  // Удалить raw PIN
  Future<void> deletePinRaw() async {
    await _storage.delete(key: _pinRawKey);
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
    return inputPin;
  }
}

final pinService = PinService();
