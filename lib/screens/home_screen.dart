import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:local_auth/local_auth.dart';
import '../models/note.dart';
import '../services/db_service.dart';
import '../services/prefs_service.dart';
import '../services/voice_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/railway_service.dart';
import '../services/pin_service.dart';
import '../widgets/pin_input_dialog.dart';
import '../theme/dokki_theme.dart';
import '../widgets/ai_mic_icon.dart';
import './settings_screen.dart';
import './editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _allNotes = [];
  List<Note> _filteredNotes = [];
  bool isLoading = false;
  String? _selectedTag;
  List<String> _availableTags = [];
  bool _isAuthenticating = false;

  Timer? _destructionTimer;
  final LocalAuthentication auth = LocalAuthentication();

  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    AuthService.instance.refreshSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });

    _destructionTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        DBService.db.checkSelfDestruction();
        _loadNotes();
      },
    );
  }

  @override
  void dispose() {
    _destructionTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    DBService.db.checkSelfDestruction();
    await _loadNotes();
  }

  void _refresh() {
    DBService.db.checkSelfDestruction();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (_allNotes.isEmpty) {
      setState(() {
        isLoading = true;
      });
    }
    final sortType = prefs.sortType;
    var notes = await DBService.db.getAllNotes();

    notes.sort((a, b) {
      final bool aPinned = a.isPinned == 1;
      final bool bPinned = b.isPinned == 1;

      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      if (sortType == 'az') {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      } else {
        return b.createdAt.compareTo(a.createdAt);
      }
    });

    if (mounted) {
      setState(() {
        _allNotes = notes;
        _extractTags();
        _applyFilter();
        isLoading = false;
      });
    }
  }

  void _extractTags() {
    final Set<String> tags = {};
    final regex = RegExp(r"#[a-zA-Z0-9a-яА-ЯёЁ_]+");
    for (var note in _allNotes) {
      final matches = regex.allMatches(note.content);
      for (var m in matches) {
        if (m.group(0) != null) tags.add(m.group(0)!);
      }
    }
    _availableTags = tags.toList()..sort();
  }

  void _applyFilter() {
    var tempNotes = _allNotes;

    if (_selectedTag != null) {
      tempNotes =
          tempNotes.where((n) => n.content.contains(_selectedTag!)).toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tempNotes = tempNotes.where((n) {
        final titleMatch = n.title.toLowerCase().contains(query);
        final contentMatch = n.content.toLowerCase().contains(query);
        return titleMatch || contentMatch;
      }).toList();
    }

    _filteredNotes = tempNotes;
  }

  void _onTagSelected(String tag) {
    setState(() {
      _selectedTag = (_selectedTag == tag) ? null : tag;
      _applyFilter();
    });
  }

  void _filterNotes(String query) {
    setState(() {
      _applyFilter();
    });
  }

  Future<bool> _authenticate() async {
    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    try {
      final hasDokkiPin = await pinService.hasPin();
      if (!hasDokkiPin) return false;

      try {
        final biometricAvailable = await auth.canCheckBiometrics;
        if (biometricAvailable) {
          final granted = await auth.authenticate(
            localizedReason: 'Access locked note',
            options: const AuthenticationOptions(
              stickyAuth: false,
              biometricOnly: true,
            ),
          );
          if (granted) {
            await Future.delayed(const Duration(milliseconds: 300));
            return true;
          }
        }
      } catch (_) {}

      if (!mounted) return false;
      final pin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PinInputDialog(
          isConfirmation: false,
          verifyPin: (input) async => await pinService.verifyPin(input),
        ),
      );
      // Если диалог вернул PIN, значит он уже прошел проверку внутри
      return pin != null;
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> _createAiNote() async {
    if (!AuthService.instance.isAuthenticated) {
      _showWarningDialog(Icons.person_off);
      return;
    }

    final balance = await RailwayService.instance.checkBalance();
    if (balance < 1) {
      _showWarningDialog(Icons.money_off);
      return;
    }

    StateSetter? dialogSetState;
    String dialogText = "Initializing...";
    bool isDialogShowing = false;

    void updateDialogText(String newText) {
      if (dialogSetState != null) {
        dialogSetState!(() {
          dialogText = newText;
        });
      }
    }

    void closeDialog() {
      if (isDialogShowing && mounted) {
        Navigator.of(context).pop();
        isDialogShowing = false;
      }
    }

    try {
      isDialogShowing = true;
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              dialogSetState = setState;
              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                content: Row(
                  children: [
                    const CircularProgressIndicator(
                        color: DokkiColors.primaryTeal),
                    const SizedBox(width: 20),
                    Expanded(child: Text(dialogText)),
                  ],
                ),
              );
            },
          );
        },
      );

      final initialized = await voiceService.initialize();
      if (!initialized) {
        closeDialog();
        return;
      }

      updateDialogText("Speak now...");

      final userMessage =
          await voiceService.startListening(onPartialResult: (text) {
        updateDialogText('Listening:\n"$text"');
      });

      if (userMessage.trim().isEmpty) {
        closeDialog();
        return;
      }

      updateDialogText("AI is thinking...");
      final aiResponse = await aiService.sendMessage(
        userMessage: userMessage,
        conversationHistory: [],
      );

      try {
        await RailwayService.instance.deductTokens(1, metadata: {
          'model': 'gpt-4o-mini',
          'message_length': userMessage.length,
        });
      } catch (_) {}

      String generatedTitle = userMessage;
      if (generatedTitle.isNotEmpty) {
        generatedTitle =
            generatedTitle[0].toUpperCase() + generatedTitle.substring(1);
      }
      if (generatedTitle.length > 30) {
        generatedTitle = "${generatedTitle.substring(0, 30)}...";
      }

      final content = "You: $userMessage\n\nAI: $aiResponse";

      final aiNote = Note(
        title: generatedTitle,
        content: content,
        createdAt: DateTime.now().toIso8601String(),
        isAiNote: true,
      );

      await DBService.db.addNote(aiNote);

      closeDialog();
      _refresh();

      final notesList = await DBService.db.getAllNotes();
      if (!mounted) return;
      if (notesList.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteEditorScreen(
              note: notesList.first,
              isAiMode: true,
            ),
          ),
        ).then((_) => _refresh());
      }
    } catch (e) {
      debugPrint("Error in _createAiNote: $e");
      closeDialog();
    } finally {
      closeDialog();
      await voiceService.stopListening();
    }
  }

  Widget _buildSlidableNote(BuildContext context, Note note) {
    final bool isLocked = note.isLocked == 1;
    final displayNote = isLocked
        ? Note(
            id: note.id,
            title: note.title,
            content: '',
            createdAt: note.createdAt,
            expiresAt: note.expiresAt,
            destructTime: note.destructTime,
            isPinned: note.isPinned,
            isTrash: note.isTrash,
            isLocked: 1,
            isAiNote: note.isAiNote,
          )
        : note;

    return _NoteCard(
      key: ValueKey(note.id),
      note: displayNote,
      isLocked: isLocked,
      onTap: () async {
        if (isLocked) {
          final granted = await _authenticate();
          if (!granted) return;
        }
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteEditorScreen(
              note: note,
              isAiMode: note.isAiNote == true,
            ),
          ),
        );
        _refresh();
      },
      onShare: () {
        Share.share("${note.title}\n${note.content}");
      },
      onPinToggle: () async {
        await DBService.db.togglePin(note.id!);
        _loadNotes();
      },
      onMoveToTrash: () async {
        await DBService.db.moveToTrash(note.id!);
        _loadNotes();
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        bottom: true,
        child: SizedBox(
          height: 50,
          child: _isSearchActive
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: '',
                            prefixIcon: Icon(Icons.search,
                                color: DokkiColors.primaryTeal),
                            border: InputBorder.none,
                          ),
                          onChanged: _filterNotes,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _isSearchActive = false;
                            _searchController.clear();
                            _applyFilter();
                          });
                        },
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search,
                          color: DokkiColors.primaryTeal),
                      onPressed: () => setState(() => _isSearchActive = true),
                    ),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _availableTags.length,
                        itemBuilder: (context, index) {
                          final tag = _availableTags[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(tag,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: DokkiColors.primaryTeal)),
                              selected: tag == _selectedTag,
                              onSelected: (_) => _onTagSelected(tag),
                              selectedColor: DokkiColors.primaryTeal
                                  .withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 70,
        title: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(
            'assets/logo.png',
            height: 40,
            errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.check_box,
                color: DokkiColors.primaryTeal,
                size: 58),
          ),
        ),
        actions: [
          IconButton(
            icon: const AiMicIcon(
              size: 28,
              color: Color(0xFFFFD700),
            ),
            onPressed: _createAiNote,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NoteEditorScreen(),
              ),
            ).then((_) => _refresh()),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            ).then((_) => _refresh()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _filteredNotes.isEmpty
                      ? const Center(
                          child: Icon(CupertinoIcons.doc,
                              size: 64, color: Colors.grey),
                        )
                      : ListView.builder(
                          itemCount: _filteredNotes.length,
                          itemBuilder: (context, index) => _buildSlidableNote(
                              context, _filteredNotes[index]),
                        ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  void _showWarningDialog(IconData icon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 56, color: Colors.redAccent),
                SizedBox(width: 32),
                Icon(Icons.money_off, size: 56, color: Colors.redAccent),
              ],
            ),
            const SizedBox(height: 24),
            IconButton(
              iconSize: 48,
              icon: const Icon(Icons.check_circle, color: Color(0xFF00BCD4)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final Future<void> Function() onPinToggle;
  final Future<void> Function() onMoveToTrash;

  const _NoteCard({
    super.key,
    required this.note,
    required this.isLocked,
    required this.onTap,
    required this.onShare,
    required this.onPinToggle,
    required this.onMoveToTrash,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPinned = note.isPinned == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).cardColor,
          border: isPinned
              ? Border.all(color: DokkiColors.primaryTeal, width: 2.0)
              : null,
        ),
        child: Slidable(
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                  onPressed: (_) => onShare(),
                  icon: CupertinoIcons.share,
                  backgroundColor: Colors.grey),
              SlidableAction(
                  onPressed: (_) => onPinToggle(),
                  icon: isPinned
                      ? CupertinoIcons.pin_slash_fill
                      : CupertinoIcons.pin_fill,
                  backgroundColor: Colors.blue),
              SlidableAction(
                  onPressed: (_) => onMoveToTrash(),
                  icon: CupertinoIcons.trash_fill,
                  backgroundColor: Colors.red),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (note.isAiNote)
                        const Icon(Icons.auto_awesome,
                            color: Color(0xFFFFD700), size: 18),
                      if (note.isAiNote) const SizedBox(width: 6),
                      Expanded(
                          child: Text(note.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 22),
                              maxLines: 1)),
                      if (isLocked)
                        const Icon(CupertinoIcons.lock_fill,
                            size: 16, color: Colors.grey),
                    ],
                  ),
                  if (!isLocked && note.content.isNotEmpty)
                    Text(note.content,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
