import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../models/note.dart';
import 'db_service.dart';
import 'encryption_service.dart';

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  static const _fileName = 'dokkinotes_backup.enc';
  static final _scopes = ['https://www.googleapis.com/auth/drive.appdata'];

  final _googleSignIn = GoogleSignIn(scopes: _scopes);

  drive.DriveApi? _driveApi;

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;

      final auth = await account.authentication;
      final token = auth.accessToken;

      if (token == null) return false;

      final client = _AuthClient(token);
      _driveApi = drive.DriveApi(client);
      return true;
    } catch (e) {
      debugPrint('GoogleDrive signIn error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
  }

  Future<bool> isSignedIn() async {
    return _googleSignIn.isSignedIn();
  }

  Future<bool> uploadBackup(String encryptedJson) async {
    try {
      final api = _driveApi;
      if (api == null) return false;

      final bytes = utf8.encode(encryptedJson);
      final media = drive.Media(Stream.value(bytes), bytes.length);
      final meta = drive.File()
        ..name = _fileName
        ..parents = ['appDataFolder'];

      final existing = await _findBackupFile(api);

      // Лог состояния перед отправкой
      debugPrint('☁️ uploadBackup: bytes=${bytes.length}, existing=$existing');

      if (existing != null) {
        await api.files.update(drive.File(), existing, uploadMedia: media);
      } else {
        await api.files.create(meta, uploadMedia: media);
      }

      debugPrint('☁️ uploadBackup success');
      return true;
    } catch (e) {
      debugPrint('GoogleDrive upload error: $e');
      return false;
    }
  }

  Future<String?> downloadBackup() async {
    try {
      final api = _driveApi;
      if (api == null) return null;

      final fileId = await _findBackupFile(api);
      if (fileId == null) return null;

      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await response.stream.expand((x) => x).toList();
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('GoogleDrive download error: $e');
      return null;
    }
  }

  Future<String?> _findBackupFile(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_fileName'",
      $fields: 'files(id)',
    );
    return list.files?.firstOrNull?.id;
  }

  Future<bool> uploadNotes() async {
    debugPrint(
        '📤 uploadNotes: driveApi=${_driveApi != null}, keyInit=${encryptionService.isInitialized}');
    try {
      if (!encryptionService.isInitialized) return false;
      if (_driveApi == null) return false;

      final notes = await DBService.db.getAllNotes();
      final trashNotes = await DBService.db.getTrashNotes();
      final allNotes = [...notes, ...trashNotes];
      final jsonStr = jsonEncode(allNotes.map((n) => n.toMap()).toList());

      final encrypted = encryptionService.encryptText(jsonStr);
      return await uploadBackup(encrypted);
    } catch (e) {
      debugPrint('GoogleDrive uploadNotes error: $e');
      return false;
    }
  }

  Future<bool> downloadAndRestoreNotes() async {
    try {
      if (_driveApi == null) return false;

      final encrypted = await downloadBackup();
      if (encrypted == null) return false;

      final jsonStr = encryptionService.decryptText(encrypted);
      final List<dynamic> jsonList = jsonDecode(jsonStr);

      for (var item in jsonList) {
        final note = Note.fromMap(item);
        await DBService.db.addNote(Note(
          title: note.title,
          content: note.content,
          createdAt: note.createdAt,
          expiresAt: note.expiresAt,
          isPinned: note.isPinned,
          isTrash: note.isTrash,
          isLocked: note.isLocked,
        ));
      }
      return true;
    } catch (e) {
      debugPrint('GoogleDrive downloadAndRestoreNotes error: $e');
      return false;
    }
  }
}

class _AuthClient extends http.BaseClient {
  final String _token;
  final _inner = http.Client();
  _AuthClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}
