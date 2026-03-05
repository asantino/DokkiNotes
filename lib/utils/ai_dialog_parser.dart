class AiDialogParser {
  /// Разбирает текст заметки на массив сообщений для OpenAI API.
  /// Возвращает максимум [maxMessages] последних сообщений.
  static List<Map<String, String>> parseConversation(String content,
      {int maxMessages = 10}) {
    final List<Map<String, String>> messages = [];

    // Регулярка ищет "You:" или "AI:", захватывает весь текст после них
    // вплоть до следующего "You:", "AI:" или конца строки (dotAll: true позволяет захватывать \n)
    final regex = RegExp(r'(You:|AI:)(.*?)(?=(You:|AI:|$))', dotAll: true);

    final matches = regex.allMatches(content);

    for (final match in matches) {
      final marker = match.group(1)?.trim();
      final text = match.group(2)?.trim();

      // Пропускаем пустые блоки
      if (text != null && text.isNotEmpty) {
        messages.add({
          'role': marker == 'You:' ? 'user' : 'assistant',
          'content': text,
        });
      }
    }

    // Возвращаем только последние N сообщений для экономии токенов
    if (messages.length > maxMessages) {
      return messages.sublist(messages.length - maxMessages);
    }

    return messages;
  }
}
