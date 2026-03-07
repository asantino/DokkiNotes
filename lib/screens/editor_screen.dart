import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/note.dart';
import '../services/db_service.dart';
import '../services/voice_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/railway_service.dart';
import '../services/pin_service.dart';
import '../resources/app_strings.dart';
import '../theme/dokki_theme.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final bool isAiMode;

  const NoteEditorScreen({
    super.key,
    this.note,
    this.isAiMode = false,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late HashtagEditingController _titleController;
  late HashtagEditingController _contentController;
  final _titleFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();

  DateTime? _expiresAt;
  DateTime? _destructTime;

  bool _isDirty = false;
  List<String> _existingTags = [];
  bool _showTagPanel = false;
  bool _isLocked = false;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _titleController = HashtagEditingController(text: widget.note?.title ?? '');
    _contentController =
        HashtagEditingController(text: widget.note?.content ?? '');
    _expiresAt = widget.note?.expiresAt;
    _destructTime = widget.note?.destructTime;

    if (widget.note?.isLocked != null) {
      final dynamic lock = widget.note!.isLocked;
      if (lock is bool) {
        _isLocked = lock;
      } else if (lock is int) {
        _isLocked = lock == 1;
      }
    } else {
      _isLocked = false;
    }

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    _loadExistingTags();
  }

  Future<void> _toggleLock() async {
    final hasDokkiPin = await pinService.hasPin();
    if (!hasDokkiPin && !_isLocked) return;

    setState(() {
      _isLocked = !_isLocked;
      _isDirty = true;
    });
  }

  Future<void> _loadExistingTags() async {
    final allNotes = await DBService.db.getAllNotes();
    final Set<String> tags = {};
    final RegExp regex = RegExp(r"#[a-zA-Z0-9a-яА-ЯёЁ_]+");

    for (var note in allNotes) {
      final matches = regex.allMatches(note.content);
      for (var m in matches) {
        if (m.group(0) != null) tags.add(m.group(0)!);
      }
    }

    if (mounted) {
      setState(() {
        _existingTags = tags.toList()..sort();
        _showTagPanel = _existingTags.isNotEmpty;
      });
    }
  }

  void _insertTag(String tag) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    int start = selection.start < 0 ? text.length : selection.start;
    final newTag = "$tag ";
    final newText = text.replaceRange(start, start, newTag);

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + newTag.length),
    );

    _isDirty = true;
  }

  void _onTextChanged() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  @override
  void dispose() {
    _stopListening();
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveAndExit() async {
    await _saveNote();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return;
    if (!_isDirty && widget.note != null) return;

    int lockedInt = _isLocked ? 1 : 0;

    if (widget.note == null) {
      final newNote = Note(
        title: title,
        content: content,
        createdAt: DateTime.now().toIso8601String(),
        expiresAt: _expiresAt,
        destructTime: _destructTime,
        isLocked: lockedInt,
        isAiNote: widget.isAiMode,
      );
      await DBService.db.addNote(newNote);
    } else {
      final updatedNote = Note(
        id: widget.note!.id,
        title: title,
        content: content,
        createdAt: widget.note!.createdAt,
        expiresAt: _expiresAt,
        destructTime: _destructTime,
        isPinned: widget.note!.isPinned,
        isTrash: widget.note!.isTrash,
        isLocked: lockedInt,
        isAiNote: widget.note!.isAiNote,
      );
      await DBService.db.updateNote(updatedNote);
    }
    _isDirty = false;
  }

  void _showSelfDestructMenu() async {
    final result = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      items: [
        const PopupMenuItem(
          value: '1h',
          child: Text('1h', style: TextStyle(fontSize: 16)),
        ),
        const PopupMenuItem(
          value: '24h',
          child: Text('24h', style: TextStyle(fontSize: 16)),
        ),
        const PopupMenuItem(
          value: 'remove',
          child: Icon(Icons.close, color: Colors.red, size: 24),
        ),
      ],
    );

    if (result != null) {
      setState(() {
        final now = DateTime.now();
        if (result == 'remove') {
          _destructTime = null;
        } else if (result == '1h') {
          _destructTime = now.add(const Duration(hours: 1));
        } else if (result == '24h') {
          _destructTime = now.add(const Duration(hours: 24));
        }
        _isDirty = true;
      });
    }
  }

  Future<void> _continueAiDialog() async {
    if (!AuthService.instance.isAuthenticated) return;

    final balance = await RailwayService.instance.checkBalance();
    if (balance < 2) return;

    StateSetter? dialogSetState;
    String dialogText = "Initializing...";
    bool isDialogShowing = false;

    void updateText(String text) {
      if (dialogSetState != null && mounted) {
        dialogSetState!(() => dialogText = text);
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
        builder: (context) => StatefulBuilder(
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
                  Expanded(
                      child: Text(dialogText,
                          style: const TextStyle(fontSize: 16))),
                ],
              ),
            );
          },
        ),
      );

      final initialized = await voiceService.initialize();
      if (!initialized) throw "Error";

      updateText("Speak now...");
      final userMessage = await voiceService.startListening(
          onPartialResult: (text) => updateText('Listening:\n"$text"'));

      if (userMessage.trim().isEmpty) {
        closeDialog();
        return;
      }

      updateText("AI is thinking...");
      final currentContent = _contentController.text;

      final List<Map<String, String>> history = [
        {'role': 'system', 'content': 'Context:\n$currentContent'}
      ];

      final aiResponse = await aiService.sendMessage(
        userMessage: userMessage,
        conversationHistory: history,
      );

      try {
        await RailwayService.instance.deductTokens(1, metadata: {
          'model': 'gpt-4o-mini',
          'message_length': userMessage.length,
        });
      } catch (_) {}

      final separator = currentContent.trim().isEmpty ? "" : "\n\n";
      final newContent =
          '$currentContent${separator}You: $userMessage\n\nAI: $aiResponse';

      setState(() {
        _contentController.text = newContent;
        _isDirty = true;
      });

      if (!context.mounted) return;
      await _saveNote();
    } catch (e) {
      debugPrint('AI Error: $e');
    } finally {
      closeDialog();
      await voiceService.stopListening();
    }
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available && mounted) _showVoiceInputDialog();
  }

  void _showVoiceInputDialog() {
    setState(() => _isListening = true);
    String recognizedText = '';
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.mic_circle_fill,
                  size: 80, color: DokkiColors.primaryTeal),
              const SizedBox(height: 20),
              Text(recognizedText.isEmpty ? 'Speak now...' : recognizedText,
                  textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'))
          ],
        ),
      ),
    ).then((_) => _stopListening());

    _speech.listen(
      localeId: 'ru_RU',
      onResult: (result) {
        recognizedText = result.recognizedWords;
        if (result.finalResult) {
          setState(() {
            _contentController.text =
                '${_contentController.text} $recognizedText';
            _isDirty = true;
          });
          if (!context.mounted) return;
          Navigator.pop(context);
        }
      },
    );
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveAndExit();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 30),
              onPressed: _saveAndExit),
          actions: [
            IconButton(
              icon: Icon(
                  _isLocked ? CupertinoIcons.lock : CupertinoIcons.lock_open,
                  color: _isLocked ? DokkiColors.primaryTeal : null,
                  size: 30),
              onPressed: _toggleLock,
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.timer, size: 30),
              color:
                  _destructTime == null ? Colors.grey : DokkiColors.primaryTeal,
              onPressed: _showSelfDestructMenu,
            ),
            widget.isAiMode
                ? IconButton(
                    onPressed: _continueAiDialog,
                    icon: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.mic_none_rounded,
                              color: Color(0xFFFFD700), size: 26),
                          Positioned(
                              top: -2,
                              right: -3,
                              child: Icon(Icons.auto_awesome,
                                  color: Color(0xFFFFD700), size: 12)),
                        ],
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(CupertinoIcons.mic_fill, size: 30),
                    onPressed: _startListening),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                cursorColor: DokkiColors.primaryTeal,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  hintText: AppStrings.get('title_hint'),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _contentFocusNode.requestFocus(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                      hintText: AppStrings.get('content_hint'),
                      border: InputBorder.none),
                ),
              ),
            ),
            if (_showTagPanel)
              Container(
                height: 50,
                decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.1)))),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _existingTags.length,
                  itemBuilder: (context, index) {
                    final tag = _existingTags[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(tag, style: const TextStyle(fontSize: 13)),
                        onPressed: () => _insertTag(tag),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ),
            if (bottomPadding == 0)
              SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class HashtagEditingController extends TextEditingController {
  HashtagEditingController({super.text});
  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final RegExp regex = RegExp(r"(#[a-zA-Z0-9a-яА-ЯёЁ_]+)");
    final List<TextSpan> spans = [];
    text.splitMapJoin(regex, onMatch: (m) {
      spans.add(TextSpan(
          text: m.group(0),
          style: style?.copyWith(
              color: DokkiColors.primaryTeal, fontWeight: FontWeight.bold)));
      return "";
    }, onNonMatch: (n) {
      spans.add(TextSpan(text: n, style: style));
      return "";
    });
    return TextSpan(style: style, children: spans);
  }
}
