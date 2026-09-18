import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// StorageService — Wrapper de SharedPreferences para persistência local
///
/// Centraliza toda a lógica de cache local: tema, sessão, preferências.
/// ═══════════════════════════════════════════════════════════════════════
class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('StorageService não foi inicializado. Chame StorageService.init() no main().');
    }
    return _prefs!;
  }

  // ── Tema ──
  static const String _keyThemeMode = 'theme_mode';

  static Future<void> saveThemeMode(String mode) async {
    await prefs.setString(_keyThemeMode, mode);
  }

  static String getThemeMode() {
    return prefs.getString(_keyThemeMode) ?? 'dark';
  }

  // ── Lembrar Login ──
  static const String _keyRememberEmail = 'remember_email';
  static const String _keyRememberMe = 'remember_me';

  static Future<void> saveRememberMe(bool remember, String email) async {
    await prefs.setBool(_keyRememberMe, remember);
    if (remember) {
      await prefs.setString(_keyRememberEmail, email);
    } else {
      await prefs.remove(_keyRememberEmail);
    }
  }

  static bool getRememberMe() {
    return prefs.getBool(_keyRememberMe) ?? true;
  }

  static String? getSavedEmail() {
    return prefs.getString(_keyRememberEmail);
  }

  // ── Nome da Loja (cache local) ──
  static const String _keyStoreName = 'store_name';

  static Future<void> saveStoreName(String name) async {
    await prefs.setString(_keyStoreName, name);
  }

  static String getStoreName() {
    return prefs.getString(_keyStoreName) ?? 'Minha Loja';
  }

  // ── Limpar tudo (logout) ──
  static Future<void> clearAll() async {
    final rememberMe = getRememberMe();
    final savedEmail = getSavedEmail();
    await prefs.clear();
    // Preserva "lembrar de mim" mesmo após logout
    if (rememberMe && savedEmail != null) {
      await saveRememberMe(true, savedEmail);
    }
  }
}
