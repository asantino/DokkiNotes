import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/prefs_service.dart';
import 'theme/dokki_theme.dart';
import 'services/purchase_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 ========== APP STARTUP ==========');

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

  await AuthService.instance.refreshSession();

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

    debugPrint('✅ Onboarding completed, showing HomeScreen');
    return const HomeScreen();
  }
}
