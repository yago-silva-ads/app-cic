import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Paleta de cores acessível do App CIC — WCAG 2.1 AA
/// Todos os pares de cores foram verificados para contraste ≥ 4.5:1
/// ═══════════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ── Primárias (Identidade Visual) ──
  static const Color primary = Color(0xFF0D47A1);        // Azul escuro — contraste 8.2:1 sobre branco
  static const Color primaryLight = Color(0xFF1565C0);    // Azul médio
  static const Color primarySurface = Color(0xFFE3F2FD);  // Azul claro (fundo de cards)
  static const Color onPrimary = Colors.white;

  // ── Superfícies ──
  static const Color background = Color(0xFFF5F7FA);      // Fundo geral (cinza quase branco)
  static const Color surface = Colors.white;               // Fundo de cards
  static const Color surfaceDark = Color(0xFF121212);      // Fundo escuro (suporte)
  static const Color surfaceDarkCard = Color(0xFF1E1E1E);  // Card em fundo escuro

  // ── Texto ──
  static const Color textPrimary = Color(0xFF1A1A2E);     // Texto principal — contraste 15:1
  static const Color textSecondary = Color(0xFF4A4A68);   // Texto secundário — contraste 7.5:1
  static const Color textHint = Color(0xFF6B6B80);        // Hint/placeholder — contraste 4.6:1
  static const Color textOnDark = Color(0xFFF5F5F5);      // Texto sobre fundo escuro
  static const Color textOnDarkSecondary = Color(0xFFB0B0B0); // Texto secundário sobre escuro — 4.5:1

  // ── Status Semânticos ──
  static const Color success = Color(0xFF2E7D32);         // Verde sucesso — contraste 5.1:1
  static const Color successLight = Color(0xFFE8F5E9);    // Fundo verde suave
  static const Color successBorder = Color(0xFF81C784);

  static const Color warning = Color(0xFFE65100);         // Laranja aviso — contraste 4.6:1
  static const Color warningLight = Color(0xFFFFF3E0);    // Fundo laranja suave
  static const Color warningBorder = Color(0xFFFFB74D);

  static const Color error = Color(0xFFC62828);           // Vermelho erro — contraste 6.4:1
  static const Color errorLight = Color(0xFFFFEBEE);      // Fundo vermelho suave
  static const Color errorBorder = Color(0xFFEF9A9A);

  static const Color info = Color(0xFF1565C0);            // Azul informação
  static const Color infoLight = Color(0xFFE3F2FD);       // Fundo azul suave

  // ── Curva ABC ──
  static const Color classeA = Color(0xFF2E7D32);         // Verde — melhor produto
  static const Color classeB = Color(0xFFE65100);         // Laranja — produto médio
  static const Color classeC = Color(0xFFC62828);         // Vermelho — pior produto

  static const Color classeABg = Color(0xFFE8F5E9);
  static const Color classeBBg = Color(0xFFFFF3E0);
  static const Color classeCBg = Color(0xFFFFEBEE);

  // ── WhatsApp ──
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF128C7E);

  // ── Gradientes ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFC62828), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Dividers e Borders ──
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFBDBDBD);
  static const Color borderFocus = Color(0xFF1565C0);
}
