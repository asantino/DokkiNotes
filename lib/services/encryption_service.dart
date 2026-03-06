import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  enc.Key? _cachedKey;

  void init(String password) {
    _cachedKey = _generateKey(password);
  }

  void clearKey() {
    _cachedKey = null;
  }

  // Константы для алгоритма AES-256 (Исправлено на const согласно prefer_const_declarations)
  static const int _keyLength = 32;
  static const int _ivLength = 16;
  static const String _salt = 'dokki_salt_2026';
  static const int _iterations = 100000;

  // Генерация ключа из PIN/пароля через PBKDF2
  enc.Key _generateKey(String pin) {
    final saltBytes = utf8.encode(_salt);

    // Реализация усиления ключа через многократное хеширование
    List<int> key = utf8.encode(pin + String.fromCharCodes(saltBytes));
    for (int i = 0; i < _iterations; i++) {
      key = sha256.convert(key).bytes;
    }

    // Берем первые 32 байта для AES-256
    return enc.Key(Uint8List.fromList(key.take(_keyLength).toList()));
  }

  // Генерация случайного IV
  enc.IV _generateIV() {
    return enc.IV.fromSecureRandom(_ivLength);
  }

  // Шифрование файла
  Future<bool> encryptFile(
      String inputPath, String outputPath, String pin) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) return false;

      final bytes = await inputFile.readAsBytes();
      final key = _generateKey(pin);
      final iv = _generateIV();

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(bytes, iv: iv);

      final outputFile = File(outputPath);
      final outputBytes = Uint8List.fromList([
        ...iv.bytes,
        ...encrypted.bytes,
      ]);

      await outputFile.writeAsBytes(outputBytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Расшифровка файла
  Future<bool> decryptFile(
      String inputPath, String outputPath, String pin) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) return false;

      final bytes = await inputFile.readAsBytes();
      if (bytes.length < _ivLength) return false;

      final iv = enc.IV(Uint8List.fromList(bytes.take(_ivLength).toList()));
      final encryptedBytes = bytes.skip(_ivLength).toList();

      final key = _generateKey(pin);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(encryptedBytes)),
        iv: iv,
      );

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(decrypted);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Шифрование текста
  String encryptText(String text) {
    if (_cachedKey == null) {
      throw Exception('EncryptionService not initialized');
    }
    try {
      final iv = _generateIV();
      final encrypter =
          enc.Encrypter(enc.AES(_cachedKey!, mode: enc.AESMode.cbc));
// ...
      final encrypted = encrypter.encrypt(text, iv: iv);
      final combined = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
      return base64.encode(combined);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  // Расшифровка текста
  String decryptText(String encryptedText) {
    if (_cachedKey == null) {
      throw Exception('EncryptionService not initialized');
    }
    try {
      final combined = base64.decode(encryptedText);
      if (combined.length < _ivLength) throw Exception('Invalid data');
// ...
      final iv = enc.IV(Uint8List.fromList(combined.take(_ivLength).toList()));
      final encryptedBytes = combined.skip(_ivLength).toList();
      final encrypter =
          enc.Encrypter(enc.AES(_cachedKey!, mode: enc.AESMode.cbc));
      return encrypter.decrypt(
        enc.Encrypted(Uint8List.fromList(encryptedBytes)),
        iv: iv,
      );
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // Проверка правильности PIN
  Future<bool> verifyPinForFile(String encryptedPath, String pin) async {
    try {
      final inputFile = File(encryptedPath);
      if (!await inputFile.exists()) return false;

      final bytes = await inputFile.readAsBytes();
      if (bytes.length < _ivLength) return false;

      final iv = enc.IV(Uint8List.fromList(bytes.take(_ivLength).toList()));
      final encryptedBytes = bytes.skip(_ivLength).take(100).toList();

      final key = _generateKey(pin);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      try {
        encrypter.decryptBytes(
          enc.Encrypted(Uint8List.fromList(encryptedBytes)),
          iv: iv,
        );
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}

final encryptionService = EncryptionService();
