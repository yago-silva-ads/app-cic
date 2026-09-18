import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/storage_service.dart';
import 'services/app_state.dart';
import 'screens/auth/splash_screen.dart';
import 'package:flutter/services.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Entry Point - APP-CIC v2.0
///
/// Inicializa Firebase, Supabase, Storage Local e aplica o design system.
/// ═══════════════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fixar orientação em retrato
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Inicializa o cache local (SharedPreferences)
  await StorageService.init();

  // Carrega o tema salvo
  AppState.loadSavedTheme();


  // Inicializa Supabase
  // OBS: Como não temos as chaves do ambiente aqui (secrets.dart), usaremos um mock ou chaves placeholder.
  // IMPORTANTE: Para deploy, usar flutter_dotenv ou chaves injetadas no build.
  try {
    // Tente inicializar se tiver chaves no secrets.dart, ou coloque as suas chaves Supabase reais aqui.
    // await Supabase.initialize(
    //   url: 'YOUR_SUPABASE_URL',
    //   anonKey: 'YOUR_SUPABASE_ANON_KEY',
    // );
  } catch (e) {
    debugPrint('Erro ao inicializar Supabase: $e');
  }

  runApp(const AppCIC());
}

class AppCIC extends StatelessWidget {
  const AppCIC({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.themeNotifier,
      builder: (_, themeMode, __) {
        return MaterialApp(
          title: 'APP-CIC',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const SplashScreen(),
        );
      },
    );
  }
}