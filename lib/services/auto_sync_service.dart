import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'db_service.dart';
import 'sync_status_service.dart';

/// Сервис автоматической синхронизации vault файла
/// Использует debounce для объединения множественных изменений
class AutoSyncService {
  // Singleton
  static final AutoSyncService _instance = AutoSyncService._internal();
  factory AutoSyncService() => _instance;
  AutoSyncService._internal();

  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(seconds: 10);

  /// Запускает синхронизацию с debounce
  /// Если вызывается несколько раз подряд, таймер сбрасывается
  void triggerSync() {
    // ШАГ 1: СРАЗУ обновляем статус (ДО таймера!)
    syncStatusService.updateStatus(SyncStatus.uploading);
    debugPrint('🔄 Status changed to UPLOADING');

    // ШАГ 2: Отменяем предыдущий таймер, если он был
    _debounceTimer?.cancel();

    // ШАГ 3: Запускаем новый таймер на 10 секунд
    _debounceTimer = Timer(_debounceDuration, () {
      debugPrint('⏰ Timer fired, starting export...');
      _performSync();
    });
  }

  /// Выполняет экспорт зашифрованной БД
  Future<void> _performSync() async {
    try {
      debugPrint('📤 ========== AUTO-SYNC START ==========');
      debugPrint('🔍 Getting cached PIN...');

      // Получаем PIN из кэша
      final pin = DBService.db.getCachedPin();

      if (pin == null) {
        debugPrint('❌ Auto-sync failed: No cached PIN');
        syncStatusService.updateStatus(SyncStatus.error);
        return;
      }

      debugPrint('✅ PIN retrieved from cache');
      debugPrint('🔐 Exporting encrypted database...');

      // Экспортируем зашифрованную БД
      final vaultPath = await DBService.db.exportEncryptedDatabase(pin);

      // ИСПРАВЛЕНО: prefer_if_null_operators
      debugPrint('🔍 Export result: ${vaultPath ?? "NULL"}');

      if (vaultPath != null) {
        debugPrint('✅ Export completed successfully');
        debugPrint('📁 Vault path: $vaultPath');

        // КРИТИЧНО: Устанавливаем статус SYNCED
        syncStatusService.updateStatus(SyncStatus.synced);
        debugPrint('🎉 Status updated to SYNCED');
        debugPrint('✅ ========== AUTO-SYNC SUCCESS ==========');
      } else {
        debugPrint('❌ Export failed: exportEncryptedDatabase returned null');
        debugPrint('⚠️  This means encryptFile() returned false');
        syncStatusService.updateStatus(SyncStatus.error);
        debugPrint('❌ ========== AUTO-SYNC FAILED (NULL) ==========');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ========== AUTO-SYNC EXCEPTION ==========');
      debugPrint('❌ Exception: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      syncStatusService.updateStatus(SyncStatus.error);
      debugPrint('❌ ========== AUTO-SYNC FAILED (EXCEPTION) ==========');
    }
  }

  /// Проверяет существование vault файла
  Future<bool> hasVaultFile() async {
    try {
      final dbPath = await getDatabasesPath();
      final vaultPath = join(dbPath, 'dokki_vault.enc');
      final vaultFile = File(vaultPath);
      return await vaultFile.exists();
    } catch (e) {
      debugPrint('❌ Error checking vault file: $e');
      return false;
    }
  }

  /// Получает дату изменения vault файла
  Future<DateTime?> getVaultTimestamp() async {
    try {
      final dbPath = await getDatabasesPath();
      final vaultPath = join(dbPath, 'dokki_vault.enc');
      final vaultFile = File(vaultPath);

      if (await vaultFile.exists()) {
        return await vaultFile.lastModified();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting vault timestamp: $e');
      return null;
    }
  }

  /// Получает дату изменения локальной БД
  Future<DateTime?> getLocalDbTimestamp() async {
    try {
      final dbPath = await getDatabasesPath();
      final localDbPath = join(dbPath, 'dokki_notes.db');
      final localDbFile = File(localDbPath);

      if (await localDbFile.exists()) {
        return await localDbFile.lastModified();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting local DB timestamp: $e');
      return null;
    }
  }

  /// Проверяет нужна ли синхронизация
  /// Возвращает true если vault файл новее локальной БД
  Future<bool> needsSync() async {
    try {
      final vaultTimestamp = await getVaultTimestamp();
      final localDbTimestamp = await getLocalDbTimestamp();

      // Если vault файла нет - синхронизация не нужна
      if (vaultTimestamp == null) {
        debugPrint('ℹ️  No vault file, sync not needed');
        return false;
      }

      // Если локальной БД нет - нужна синхронизация
      if (localDbTimestamp == null) {
        debugPrint('⚠️  No local DB, sync needed');
        return true;
      }

      // Сравниваем timestamp'ы
      final vaultIsNewer = vaultTimestamp.isAfter(localDbTimestamp);

      if (vaultIsNewer) {
        debugPrint('🔄 Vault is newer, sync needed');
        debugPrint('   Vault: $vaultTimestamp');
        debugPrint('   Local: $localDbTimestamp');
      } else {
        debugPrint('✓ Local DB is up to date');
      }

      return vaultIsNewer;
    } catch (e) {
      debugPrint('❌ Error checking sync status: $e');
      return false;
    }
  }

  /// Отменяет активный таймер синхронизации
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}

/// Глобальный экземпляр
final autoSyncService = AutoSyncService();
