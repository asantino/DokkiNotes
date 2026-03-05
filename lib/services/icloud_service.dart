import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class ICloudService {
  static final ICloudService _instance = ICloudService._internal();
  factory ICloudService() => _instance;
  ICloudService._internal();

  static const MethodChannel _channel =
      MethodChannel('kz.dokki.dokkinotes/icloud');

  // Проверка доступности iCloud
  Future<bool> isAvailable() async {
    if (!Platform.isIOS) return false;

    try {
      final bool? available = await _channel.invokeMethod('isAvailable');
      return available ?? false;
    } catch (e) {
      debugPrint('iCloud availability check error: $e');
      return false;
    }
  }

  // Загрузить файл в iCloud Drive
  Future<bool> uploadFile(String localPath) async {
    if (!Platform.isIOS) return false;

    try {
      final bool? result = await _channel.invokeMethod('uploadFile', {
        'localPath': localPath,
        'fileName': 'dokki_vault.enc',
      });
      return result ?? false;
    } catch (e) {
      debugPrint('iCloud upload error: $e');
      return false;
    }
  }

  // Скачать файл из iCloud Drive
  Future<String?> downloadFile() async {
    if (!Platform.isIOS) return null;

    try {
      final String? localPath = await _channel.invokeMethod('downloadFile', {
        'fileName': 'dokki_vault.enc',
      });
      return localPath;
    } catch (e) {
      debugPrint('iCloud download error: $e');
      return null;
    }
  }

  // Проверить наличие обновлений в iCloud
  Future<bool> checkForUpdates() async {
    if (!Platform.isIOS) return false;

    try {
      final bool? hasUpdates = await _channel.invokeMethod('checkForUpdates', {
        'fileName': 'dokki_vault.enc',
      });
      return hasUpdates ?? false;
    } catch (e) {
      debugPrint('iCloud check updates error: $e');
      return false;
    }
  }

  // Получить дату последнего изменения файла в iCloud
  Future<DateTime?> getLastModified() async {
    if (!Platform.isIOS) return null;

    try {
      final int? timestamp = await _channel.invokeMethod('getLastModified', {
        'fileName': 'dokki_vault.enc',
      });

      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      debugPrint('iCloud last modified error: $e');
      return null;
    }
  }

  // Удалить файл из iCloud
  Future<bool> deleteFile() async {
    if (!Platform.isIOS) return false;

    try {
      final bool? result = await _channel.invokeMethod('deleteFile', {
        'fileName': 'dokki_vault.enc',
      });
      return result ?? false;
    } catch (e) {
      debugPrint('iCloud delete error: $e');
      return false;
    }
  }

  // Синхронизация: загрузить БД в iCloud
  Future<bool> syncToCloud(String pin) async {
    try {
      // 1. Проверяем доступность iCloud
      final available = await isAvailable();
      if (!available) {
        debugPrint('iCloud not available');
        return false;
      }

      // 2. Экспортируем БД в зашифрованный файл
      // Этот метод должен быть вызван из DBService
      // final vaultPath = await DBService.db.exportEncryptedDatabase(pin);

      // 3. Загружаем в iCloud
      // if (vaultPath != null) {
      //   return await uploadFile(vaultPath);
      // }

      return false;
    } catch (e) {
      debugPrint('Sync to cloud error: $e');
      return false;
    }
  }

  // Синхронизация: скачать БД из iCloud
  Future<String?> syncFromCloud() async {
    try {
      // 1. Проверяем доступность iCloud
      final available = await isAvailable();
      if (!available) {
        debugPrint('iCloud not available');
        return null;
      }

      // 2. Скачиваем файл из iCloud
      final localPath = await downloadFile();

      return localPath;
    } catch (e) {
      debugPrint('Sync from cloud error: $e');
      return null;
    }
  }
}

final iCloudService = ICloudService();
