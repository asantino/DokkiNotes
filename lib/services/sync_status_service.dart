import 'dart:async';

enum SyncStatus {
  disabled, // Выключено
  synced, // Синхронизировано
  uploading, // Загрузка
  downloading, // Скачивание
  error, // Ошибка
}

class SyncStatusService {
  // Singleton
  static final SyncStatusService _instance = SyncStatusService._internal();
  factory SyncStatusService() => _instance;
  SyncStatusService._internal();

  // Stream controller для реактивности
  final _statusController = StreamController<SyncStatus>.broadcast();

  // Текущий статус
  SyncStatus _currentStatus = SyncStatus.disabled;

  // Геттер для потока статусов
  Stream<SyncStatus> get statusStream => _statusController.stream;

  // Геттер для текущего статуса
  SyncStatus get currentStatus => _currentStatus;

  // Обновить статус
  void updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  // Закрыть stream controller (вызывать при dispose приложения)
  void dispose() {
    _statusController.close();
  }
}

// Глобальный экземпляр для удобного доступа
final syncStatusService = SyncStatusService();
