# Настройка iCloud Drive для DokkiNotes

## ШАГ 1: Открыть проект в Xcode

```bash
open ios/Runner.xcworkspace
```

## ШАГ 2: Настроить Signing & Capabilities

1. В Xcode выбери проект **Runner** (синяя иконка вверху слева)
2. Выбери target **Runner** (не Tests)
3. Перейди на вкладку **Signing & Capabilities**
4. Убедись что выбран твой **Team** (Apple Developer Account)

## ШАГ 3: Добавить iCloud Capability

1. На вкладке **Signing & Capabilities** нажми **+ Capability**
2. Найди и добавь **iCloud**
3. В появившихся настройках iCloud:
   - ✅ Включи **iCloud Documents**
   - ✅ Оставь контейнер: `iCloud.$(CFBundleIdentifier)`

## ШАГ 4: Проверить Runner.entitlements

Файл уже создан: `ios/Runner/Runner.entitlements`

Проверь что в проекте Xcode:
- В Project Navigator слева есть файл **Runner.entitlements**
- Если его нет - перетащи файл из Finder в проект

## ШАГ 5: Проверить Info.plist

Убедись что в `ios/Runner/Info.plist` есть Bundle Identifier:
```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
```

## ШАГ 6: Проверить AppDelegate.swift

Файл уже настроен с регистрацией ICloudHandler.

## ШАГ 7: Build настройки

1. В Xcode: Product → Clean Build Folder (⇧⌘K)
2. Затем: Product → Build (⌘B)

## ВАЖНО: Apple Developer Account

⚠️ **Для работы iCloud требуется:**
- Платный Apple Developer Account ($99/год)
- Авторизация в Xcode (Preferences → Accounts)

## Тестирование

После настройки запусти приложение:
```bash
flutter run
```

В коде проверь:
```dart
final available = await iCloudService.isAvailable();
print('iCloud available: $available');
```

## Troubleshooting

### Ошибка: "iCloud container not found"
- Проверь что Bundle ID совпадает с настройками в Apple Developer Portal
- Создай iCloud Container в Apple Developer Portal вручную

### Ошибка: "Signing requires a development team"
- Выбери Team в Signing & Capabilities
- Войди в Apple Developer Account в Xcode Preferences

### iCloud не синхронизирует
- Проверь что на устройстве включён iCloud Drive (Settings → iCloud)
- Проверь что приложению разрешён доступ к iCloud

## Файловая структура iCloud

Файлы будут храниться в:
```
iCloud Drive/
  └── DokkiNotes/
      └── Documents/
          └── dokki_vault.enc
```
