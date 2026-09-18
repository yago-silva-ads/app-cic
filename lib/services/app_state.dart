import 'package:flutter/material.dart';
import 'storage_service.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// AppState — Estado Global da Aplicação (ValueNotifiers)
///
/// Controla tema (dark/light), aba ativa, e badges de notificação.
/// Persistência de tema via StorageService (SharedPreferences).
/// ═══════════════════════════════════════════════════════════════════════
class AppState {
  AppState._();

  static final GlobalKey<ScaffoldState> mainScaffoldKey = GlobalKey<ScaffoldState>();

  // ── Controle de Navegação ──
  static final ValueNotifier<int> pageIndexNotifier = ValueNotifier<int>(0);

  // ── Controle de Tema ──
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// Inicializa o tema salvo no SharedPreferences
  static void loadSavedTheme() {
    final saved = StorageService.getThemeMode();
    themeNotifier.value = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  /// Alterna entre claro e escuro e persiste a escolha
  static void toggleTheme() {
    if (themeNotifier.value == ThemeMode.light) {
      themeNotifier.value = ThemeMode.dark;
      StorageService.saveThemeMode('dark');
    } else {
      themeNotifier.value = ThemeMode.light;
      StorageService.saveThemeMode('light');
    }
  }

  // ── Badge de Alertas ──
  static final ValueNotifier<int> alertBadgeNotifier = ValueNotifier<int>(0);

  static void updateAlertBadge(int count) {
    alertBadgeNotifier.value = count;
  }
}
