import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/prefs_service.dart';
import 'services/pin_service.dart';
import 'services/db_service.dart';
import 'services/auto_sync_service.dart';
import 'widgets/pin_input_dialog.dart';
import 'theme/dokki_theme.dart';
import 'services/purchase_service.dart';

void main() async {
  // 1. Обязательная привязка для работы асинхронных вызовов
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 ========== APP STARTUP ==========');

  // 2. Инициализация Supabase ДО загрузки настроек
  debugPrint('🔗 Initializing Supabase...');
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    debugPrint('✅ Supabase initialized');
  } catch (e) {
    debugPrint('❌ Supabase initialization error: $e');
  }

  debugPrint('🔄 Initializing preferences...');
  await prefs.init();
  debugPrint('✅ Preferences initialized');
  await PurchaseService.instance.initialize();
  debugPrint('✅ PurchaseService initialized');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  debugPrint('🎬 Launching app...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: prefs.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Dokki',
          debugShowCheckedModeBanner: false,
          theme: DokkiTheme.lightTheme,
          darkTheme: DokkiTheme.darkTheme,
          themeMode: currentMode,
          home: const AppInitScreen(),
        );
      },
    );
  }
}

// Экран инициализации - проверяет онбординг и PIN ДО загрузки HomeScreen
class AppInitScreen extends StatelessWidget {
  const AppInitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🏁 ========== AppInitScreen BUILD ==========');

    final isOnboardingCompleted = prefs.isOnboardingCompleted;
    debugPrint('📚 Onboarding completed: $isOnboardingCompleted');

    if (!isOnboardingCompleted) {
      debugPrint('➡️  Showing OnboardingScreen');
      return const OnboardingScreen();
    }

    debugPrint('✅ Onboarding completed, checking PIN...');
    return FutureBuilder<bool>(
      future: pinService.hasPin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          debugPrint('⏳ Waiting for PIN check result...');
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          );
        }

        final hasPin = snapshot.data!;
        debugPrint('🔐 Has PIN: $hasPin');

        if (hasPin) {
          debugPrint('➡️  Showing PinCheckScreen');
          return const PinCheckScreen();
        }

        debugPrint('➡️  No PIN, showing HomeScreen directly');
        return const HomeScreen();
      },
    );
  }
}

// Экран ввода PIN - показывается ТОЛЬКО когда PIN установлен
class PinCheckScreen extends StatefulWidget {
  const PinCheckScreen({super.key});

  @override
  State<PinCheckScreen> createState() => _PinCheckScreenState();
}

class _PinCheckScreenState extends State<PinCheckScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPin();
    });
  }

  Future<void> _requestPin() async {
    debugPrint('📱 PinCheckScreen: Starting PIN request');

    if (mounted) {
      setState(() => _isLoading = false);
    }

    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint('🔓 Showing PIN input dialog...');

    while (true) {
      if (!mounted) return;

      final pin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const PinInputDialog(
          title: 'Enter PIN',
          isConfirmation: false,
        ),
      );

      debugPrint('📝 PIN entered: ${pin != null ? "****" : "null"}');

      if (pin == null) {
        debugPrint('⚠️  PIN is null, retrying...');
        continue;
      }

      debugPrint('✅ Verifying PIN...');
      final isValid = await pinService.verifyPin(pin);
      debugPrint('🔑 PIN is valid: $isValid');

      if (isValid) {
        DBService.db.setCachedPin(pin);
        debugPrint('💾 PIN loaded into cache');

        debugPrint('🔄 Checking for updates...');
        final needsSync = await AutoSyncService().needsSync();
        debugPrint('📥 Needs sync: $needsSync');

        if (needsSync && mounted) {
          debugPrint('⬇️  Showing sync dialog...');

          final shouldSync = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              backgroundColor:
                  Theme.of(dialogContext).dialogTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.cloud_download,
                    size: 80,
                    color: DokkiColors.primaryTeal,
                  ),
                  const SizedBox(height: 24),
                  Icon(
                    CupertinoIcons.arrow_down,
                    size: 32,
                    color: Colors.grey.withValues(alpha: 0.7),
                  ),
                ],
              ),
              actionsPadding:
                  const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle, size: 48),
                      color: Colors.grey,
                      onPressed: () => Navigator.pop(dialogContext, false),
                    ),
                    const SizedBox(width: 48),
                    IconButton(
                      icon: const Icon(CupertinoIcons.checkmark_circle_fill,
                          size: 48),
                      color: DokkiColors.primaryTeal,
                      onPressed: () => Navigator.pop(dialogContext, true),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (shouldSync == true) {
            debugPrint('🧪 Running decryption test...');
            await DBService.db.testDecryption(pin);

            debugPrint('📥 Importing vault...');
            final success = await DBService.db.importEncryptedDatabase(pin);
            debugPrint('✅ Import success: $success');
          }
        }

        if (!mounted) return;
        debugPrint('🏠 Navigating to HomeScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        break;
      } else {
        debugPrint('❌ Wrong PIN, showing error');
        if (mounted) {
          await showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: const Padding(
                padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 80,
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: Colors.grey,
                    size: 48,
                  ),
                ),
              ],
            ),
          );
        }
        debugPrint('🔄 Retrying PIN input...');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
