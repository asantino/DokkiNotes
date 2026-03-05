class AppStrings {
  static String language = 'ru';

  static const Map<String, Map<String, String>> _values = {
    'ru': {
      'settings': 'Settings',
      'trash': 'Trash',
      'empty': 'Empty for now',
      'trash_empty': 'Trash is empty',
      'title_hint': 'Title',
      'content_hint': 'Start typing...',
      'delete': 'Delete',
      'restore': 'Restore',
      'delete_forever': 'Delete forever',
      'cancel': 'Cancel',
      'clean_all': 'Clear all',
      'pin': 'Pin',
      'share': 'Share',
      'timer': 'Deletion timer',
      '1h': '1 hour',
      '24h': '24 hours',
      'timer_off': 'Off',
      'data': 'DATA',
      'interface': 'INTERFACE',
      'theme': 'Theme',
      'theme_dark': 'Dark',
      'theme_light': 'Light',
      'lang': 'Language', // <-- Добавлено
      'lang_ru': 'Russian',
      'lang_en': 'English',
      'moved_trash': 'In trash',
      'pinned_msg': 'Pinned',
      'unpinned_msg': 'Unpinned',
      'search_hint': 'Search (#tag, text...)',
      'search_empty': 'Nothing found',
    },
    'en': {
      'settings': 'Settings',
      'trash': 'Trash',
      'empty': 'Nothing here yet',
      'trash_empty': 'Trash is empty',
      'title_hint': 'Title',
      'content_hint': 'Start typing...',
      'delete': 'Delete',
      'restore': 'Restore',
      'delete_forever': 'Delete forever',
      'cancel': 'Cancel',
      'clean_all': 'Delete All',
      'pin': 'Pin',
      'share': 'Share',
      'timer': 'Self-destruct timer',
      '1h': '1 hour',
      '24h': '24 hours',
      'timer_off': 'Disable',
      'data': 'DATA',
      'interface': 'INTERFACE',
      'theme': 'Theme',
      'theme_dark': 'Dark',
      'theme_light': 'Light',
      'lang': 'Language', // <-- Добавлено
      'lang_ru': 'Russian',
      'lang_en': 'English',
      'moved_trash': 'Moved to trash',
      'pinned_msg': 'Pinned',
      'unpinned_msg': 'Unpinned',
      'search_hint': 'Search (#tag, text...)',
      'search_empty': 'No results found',
    },
  };

  static String get(String key) {
    return _values[language]?[key] ?? key;
  }
}
