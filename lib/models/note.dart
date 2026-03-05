class Note {
  final int? id;
  final String title;
  final String content;
  final String createdAt;
  final DateTime? expiresAt;
  final DateTime? destructTime;
  final int? isPinned;
  final int? isTrash;
  final int? isLocked;
  final bool isAiNote; // НОВОЕ ПОЛЕ

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.expiresAt,
    this.destructTime,
    this.isPinned = 0,
    this.isTrash = 0,
    this.isLocked = 0,
    this.isAiNote = false, // По умолчанию false
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt,
      'expires_at': expiresAt?.toIso8601String(),
      'destruct_time': destructTime?.toIso8601String(),
      'is_pinned': isPinned,
      'is_trash': isTrash,
      'is_locked': isLocked,
      'is_ai_note': isAiNote ? 1 : 0, // Сохраняем как int (0 или 1)
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: map['created_at'] ?? '',
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'])
          : null,
      destructTime: map['destruct_time'] != null
          ? DateTime.tryParse(map['destruct_time'])
          : null,
      isPinned: map['is_pinned'] ?? 0,
      isTrash: map['is_trash'] ?? 0,
      isLocked: map['is_locked'] ?? 0,
      isAiNote: map['is_ai_note'] == 1, // Превращаем 1 в true
    );
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    String? createdAt,
    DateTime? expiresAt,
    DateTime? destructTime,
    int? isPinned,
    int? isTrash,
    int? isLocked,
    bool? isAiNote, // Параметр для copyWith
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      destructTime: destructTime ?? this.destructTime,
      isPinned: isPinned ?? this.isPinned,
      isTrash: isTrash ?? this.isTrash,
      isLocked: isLocked ?? this.isLocked,
      isAiNote: isAiNote ?? this.isAiNote, // Обновляем или оставляем старое
    );
  }
}
