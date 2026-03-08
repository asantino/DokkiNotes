import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/pin_input_dialog.dart';

class PinService {
  static final PinService _instance = PinService._internal();
  factory PinService() => _instance;
  PinService._internal();

  final _storage = const FlutterSecureStorage();
  static const _pinKey = 'dokki_user_pin';
  static const _pinRawKey = 'dokki_user_pin_raw';

  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null;
  }

  static Future<bool> ensurePinExists(BuildContext context) async {
    final instance = PinService();
    if (await instance.hasPin()) return true;

    if (!context.mounted) return false;

    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PinInputDialog(isConfirmation: true),
    );

    if (pin == null || pin.length < 4) return false;

    await instance.setPin(pin);
    return true;
  }

  Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hash);
    await _storage.write(key: _pinRawKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return false;

    final inputHash = _hashPin(pin);
    return storedHash == inputHash;
  }

  Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _pinRawKey);
  }

  Future<void> setPinRaw(String pin) async =>
      await _storage.write(key: _pinRawKey, value: pin);
  Future<String?> getPinRaw() async => await _storage.read(key: _pinRawKey);
  Future<void> deletePinRaw() async => await _storage.delete(key: _pinRawKey);

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String?> getPinForEncryption(String inputPin) async {
    final isValid = await verifyPin(inputPin);
    if (!isValid) return null;
    return inputPin;
  }
}

final pinService = PinService();
