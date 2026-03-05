import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/note.dart';
import '../services/db_service.dart';
import '../theme/dokki_theme.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Note> _trashNotes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    final notes = await DBService.db.getTrashNotes();
    if (mounted) {
      setState(() {
        _trashNotes = notes;
        isLoading = false;
      });
    }
  }

  Future<void> _restore(Note note) async {
    await DBService.db.restoreNote(note.id!);
    _loadTrash();
  }

  Future<void> _deleteForever(Note note) async {
    await DBService.db.deleteNoteForever(note.id!);
    _loadTrash();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trash",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trashNotes.isEmpty
              ? Center(
                  child: Text(
                    "Trash is empty",
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _trashNotes.length,
                  itemBuilder: (context, index) {
                    final note = _trashNotes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      color: Theme.of(context).cardColor,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        title: Text(
                          note.title.isNotEmpty ? note.title : "Untitled",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          note.content.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Кнопка Восстановить
                            IconButton(
                              icon: const Icon(Icons.restore,
                                  color: DokkiColors.primaryTeal),
                              onPressed: () => _restore(note),
                            ),
                            // Кнопка Удалить навсегда
                            IconButton(
                              icon: const Icon(CupertinoIcons.trash_fill,
                                  color: Color(0xFFdf3b3b)),
                              onPressed: () => _deleteForever(note),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
