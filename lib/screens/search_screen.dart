import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../models/note.dart';
import 'editor_screen.dart';
// Удалил лишний импорт theme

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Note> _allNotes = [];
  List<Note> _results = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await DBService.db.getAllNotes();
    setState(() {
      _allNotes = notes;
    });
  }

  void _search(String query) {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _results = _allNotes.where((n) {
        return n.title.toLowerCase().contains(lower) ||
            n.content.toLowerCase().contains(lower);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final iconColor = Theme.of(context).iconTheme.color;
    // Исправил opacity
    final hintColor = Theme.of(context).hintColor.withValues(alpha: 0.5);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(
              color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "Search...",
            hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.bold),
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final note = _results[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(note: note)));
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? "No Title" : note.title,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: 0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (note.content.isNotEmpty) const SizedBox(height: 8),
                  if (note.content.isNotEmpty)
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor?.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
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
