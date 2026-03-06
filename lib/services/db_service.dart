import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note.dart';
import 'encryption_service.dart';
import 'pin_service.dart';
import 'auto_sync_service.dart';
import 'google_drive_service.dart';

class DBService {
  static Database? _database;
  static final DBService db = DBService._internal();

  String? _cachedKey;
  Timer? _syncDebounce;
  bool _googleSyncEnabled = false;

  factory DBService() => db;

  DBService._internal();

  void setEncryptionKey(String? key) {
    _cachedKey = key;
  }

  String? getEncryptionKey() {
    return _cachedKey;
  }

  void setGoogleSyncEnabled(bool value) {
    _googleSyncEnabled = value;
  }

  void _scheduleSync() {
    if (!_googleSyncEnabled) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 3), () async {
      final signedIn = await GoogleDriveService().isSignedIn();
      if (signedIn) await GoogleDriveService().uploadNotes();
    });
  }

  Future<void> loadPinFromStorage(String pin) async {
    // Временно оставляем для совместимости, но логика изменится
    _cachedKey = pin;
  }

  bool get hasKey => _cachedKey != null;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> reinit() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _database = await _initDB();
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dokki_notes.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            created_at TEXT,
            expires_at TEXT,
            destruct_time TEXT,
            is_pinned INTEGER DEFAULT 0,
            is_trash INTEGER DEFAULT 0,
            is_locked INTEGER DEFAULT 0,
            is_ai_note INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
                "ALTER TABLE notes ADD COLUMN is_locked INTEGER DEFAULT 0");
            await db.execute("ALTER TABLE notes ADD COLUMN destruct_time TEXT");
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute(
                "ALTER TABLE notes ADD COLUMN is_ai_note INTEGER DEFAULT 0");
            debugPrint('✅ Database migrated to version 3: added is_ai_note');
          } catch (e) {
            debugPrint('❌ Migration to v3 failed or column already exists: $e');
          }
        }
      },
    );
  }

  Future<int> addNote(Note note) async {
    final db = await database;
    final hasPin = await pinService.hasPin();

    int result;
    if (hasPin && hasKey) {
      final encryptedNote = Note(
        id: note.id,
        title: encryptionService.encryptText(note.title),
        content: encryptionService.encryptText(note.content),
        createdAt: note.createdAt,
        expiresAt: note.expiresAt,
        destructTime: note.destructTime,
        isPinned: note.isPinned,
        isTrash: note.isTrash,
        isLocked: note.isLocked,
        isAiNote: note.isAiNote,
      );
      result = await db.insert('notes', encryptedNote.toMap());
    } else {
      result = await db.insert('notes', note.toMap());
    }

    debugPrint('💾 Note saved (addNote), checking for sync...');
    debugPrint('🔐 Has PIN: $hasPin');

    if (hasPin) {
      debugPrint('🔄 Triggering auto-sync...');
      autoSyncService.triggerSync();
    } else {
      debugPrint('⏭️  No PIN, skipping sync');
    }

    _scheduleSync();
    return result;
  }

  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'is_trash = 0',
      orderBy: "is_pinned DESC, created_at DESC",
    );

    final notes = List.generate(maps.length, (i) => Note.fromMap(maps[i]));
    final hasPin = await pinService.hasPin();

    if (hasPin && hasKey) {
      return notes.map((note) {
        try {
          return Note(
            id: note.id,
            title: encryptionService.decryptText(note.title),
            content: encryptionService.decryptText(note.content),
            createdAt: note.createdAt,
            expiresAt: note.expiresAt,
            destructTime: note.destructTime,
            isPinned: note.isPinned,
            isTrash: note.isTrash,
            isLocked: note.isLocked,
            isAiNote: note.isAiNote,
          );
        } catch (e) {
          return note;
        }
      }).toList();
    }

    return notes;
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    final hasPin = await pinService.hasPin();

    int result;
    if (hasPin && hasKey) {
      final encryptedNote = Note(
        id: note.id,
        title: encryptionService.encryptText(note.title),
        content: encryptionService.encryptText(note.content),
        createdAt: note.createdAt,
        expiresAt: note.expiresAt,
        destructTime: note.destructTime,
        isPinned: note.isPinned,
        isTrash: note.isTrash,
        isLocked: note.isLocked,
        isAiNote: note.isAiNote,
      );
      result = await db.update(
        'notes',
        encryptedNote.toMap(),
        where: 'id = ?',
        whereArgs: [note.id],
      );
    } else {
      result = await db.update(
        'notes',
        note.toMap(),
        where: 'id = ?',
        whereArgs: [note.id],
      );
    }

    debugPrint('💾 Note saved (updateNote), checking for sync...');
    debugPrint('🔐 Has PIN: $hasPin');

    if (hasPin) {
      debugPrint('🔄 Triggering auto-sync...');
      autoSyncService.triggerSync();
    } else {
      debugPrint('⏭️  No PIN, skipping sync');
    }

    _scheduleSync();
    return result;
  }

  Future<void> checkSelfDestruction() async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE notes
      SET is_trash = 1, destruct_time = NULL
      WHERE is_trash = 0 AND destruct_time IS NOT NULL AND destruct_time < ?
      ''',
      [nowIso],
    );
    _scheduleSync();
  }

  Future<int> togglePin(int id) async {
    final db = await database;
    final list = await db.query('notes',
        columns: ['is_pinned'], where: 'id = ?', whereArgs: [id]);
    if (list.isNotEmpty) {
      int currentStatus = list.first['is_pinned'] as int? ?? 0;
      int newStatus = (currentStatus == 1) ? 0 : 1;
      int result = await db.update('notes', {'is_pinned': newStatus},
          where: 'id = ?', whereArgs: [id]);
      _scheduleSync();
      return result;
    }
    return 0;
  }

  Future<int> moveToTrash(int id) async {
    final db = await database;
    int result = await db.update('notes', {'is_trash': 1},
        where: 'id = ?', whereArgs: [id]);
    _scheduleSync();
    return result;
  }

  Future<List<Note>> getTrashNotes() async {
    final db = await database;
    final maps = await db.query('notes',
        where: 'is_trash = 1', orderBy: "created_at DESC");

    final notes = List.generate(maps.length, (i) => Note.fromMap(maps[i]));
    final hasPin = await pinService.hasPin();

    if (hasPin && hasKey) {
      return notes.map((note) {
        try {
          return Note(
            id: note.id,
            title: encryptionService.decryptText(note.title),
            content: encryptionService.decryptText(note.content),
            createdAt: note.createdAt,
            expiresAt: note.expiresAt,
            destructTime: note.destructTime,
            isPinned: note.isPinned,
            isTrash: note.isTrash,
            isLocked: note.isLocked,
            isAiNote: note.isAiNote,
          );
        } catch (e) {
          return note;
        }
      }).toList();
    }

    return notes;
  }

  Future<int> restoreNote(int id) async {
    final db = await database;
    int result = await db.update('notes', {'is_trash': 0},
        where: 'id = ?', whereArgs: [id]);
    _scheduleSync();
    return result;
  }

  Future<int> deleteNoteForever(int id) async {
    final db = await database;
    int result = await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    _scheduleSync();
    return result;
  }

  // TODO: Эти методы (export/import) все еще принимают 'pin'
  // и зависят от устаревших методов EncryptionService
  Future<String?> exportEncryptedDatabase(String pin) async {
    try {
      debugPrint('🔐 ========== EXPORT DATABASE START ==========');

      final dbPath = await getDatabasesPath();
      final dbFile = join(dbPath, 'dokki_notes.db');
      debugPrint('📂 DB file: $dbFile');

      final vaultPath = join(dbPath, 'dokki_vault.enc');
      debugPrint('📦 Vault file: $vaultPath');

      debugPrint('🔒 Calling encryptFile...');
      final success = await encryptionService.encryptFile(
        dbFile,
        vaultPath,
        pin,
      );
      debugPrint('🔍 encryptFile result: $success');

      if (success) {
        debugPrint('✅ Export successful, returning path');
        debugPrint('✅ ========== EXPORT DATABASE SUCCESS ==========');
        return vaultPath;
      }

      debugPrint('❌ Export failed: encryptFile returned false');
      debugPrint('❌ ========== EXPORT DATABASE FAILED ==========');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ ========== EXPORT DATABASE EXCEPTION ==========');
      debugPrint('❌ Export error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> testDecryption(String pin) async {
    final dbPath = await getDatabasesPath();
    final vaultPath = join(dbPath, 'dokki_vault.enc');
    final testPath = join(dbPath, 'test_decrypt.db');

    debugPrint('🧪 Testing decryption...');
    debugPrint('📂 Vault: $vaultPath');
    debugPrint('📂 Output: $testPath');

    final success = await encryptionService.decryptFile(
      vaultPath,
      testPath,
      pin,
    );

    debugPrint('✅ Decryption success: $success');

    if (success) {
      try {
        final testDb = await openDatabase(testPath);
        final count = await testDb.rawQuery('SELECT COUNT(*) FROM notes');
        debugPrint('📊 Notes in vault: $count');
        await testDb.close();

        await File(testPath).delete();
        debugPrint('🗑️  Test file deleted');
      } catch (e) {
        debugPrint('❌ Cannot open decrypted file: $e');
      }
    }
  }

  Future<bool> importEncryptedDatabase(String pin) async {
    try {
      final dbPath = await getDatabasesPath();
      final vaultPath = join(dbPath, 'dokki_vault.enc');
      final tempDbPath = join(dbPath, 'dokki_notes_temp.db');
      final dbFile = join(dbPath, 'dokki_notes.db');

      debugPrint('📥 Starting import...');

      if (_database != null) {
        await _database!.close();
        _database = null;
        debugPrint('🔒 Database closed');
      }

      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('🔓 Decrypting vault...');
      final success = await encryptionService.decryptFile(
        vaultPath,
        tempDbPath,
        pin,
      );

      if (!success) {
        debugPrint('❌ Decryption failed');
        return false;
      }

      debugPrint('🗑️  Deleting old database...');
      final oldDb = File(dbFile);
      if (await oldDb.exists()) {
        await oldDb.delete();
      }

      debugPrint('📦 Moving temp file...');
      await File(tempDbPath).copy(dbFile);
      await File(tempDbPath).delete();

      debugPrint('🔄 Reinitializing...');
      await database;

      debugPrint('✅ Import completed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Import error: $e');
      return false;
    }
  }
}
