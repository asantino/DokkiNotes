import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'db_service.dart';
import '../models/note.dart';

class BackupService {
  // ЭКСПОРТ
  Future<void> exportNotes(BuildContext context) async {
    try {
      final notes = await DBService.db.getAllNotes();
      final trashNotes = await DBService.db.getTrashNotes();
      final allNotes = [...notes, ...trashNotes];

      // Исключаем ненужную проверку null — Note не может быть null
      final String jsonStr = jsonEncode(
        allNotes.map((n) => n.toMap()).toList(),
      );

      final now = DateTime.now();
      final fileName = "dokki_backup_${now.year}-${now.month}-${now.day}.json";

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles([XFile(file.path)],
          text: 'Dokki Backup');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  // ИМПОРТ (Принимает context, чтобы показать сообщение об ошибке/успехе)
  Future<void> importNotes(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // Здесь проверка на null у path остаётся, потому что path может быть null (API)
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final String jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);

        int count = 0;

        for (var item in jsonList) {
          final note = Note.fromMap(item);
          // Note.fromMap всегда возвращает Note, не null (если реализация корректная)
          final newNote = Note(
              title: note.title,
              content: note.content,
              createdAt: note.createdAt,
              expiresAt: note.expiresAt,
              isPinned: note.isPinned,
              isTrash: note.isTrash,
              isLocked: note.isLocked);

          await DBService.db.addNote(newNote);
          count++;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notes restored: $count'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import error: invalid file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
