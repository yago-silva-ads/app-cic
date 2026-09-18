import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Paleta de Cores APP-CIC v2.0 — Design Dourado Premium
///
/// Dois modos completos: Dark (padrão) e Light (alto contraste).
/// Cores semânticas com redundância para acessibilidade WCAG 2.1 AA.
/// ═══════════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ══════════════════════════════════════════
  // IDENTIDADE DOURADA
  // ══════════════════════════════════════════
  static const Color gold = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFE8C36A);
  static const Color goldDark = Color(0xFFB4821E);
  static const Color goldHighContrast = Color(0xFFB4821E); // Para modo claro
  static const Color goldMuted = Color(0xFF8B7355);

  // ══════════════════════════════════════════
  // MODO ESCURO (Dark)
  // ══════════════════════════════════════════
  static const Color darkBackground = Color(0xFF0D0D0D);
  static const Color darkSurface = Color(0xFF161616);
  static const Color darkCard = Color(0xFF181818);
  static const Color darkCardHover = Color(0xFF1F1F1F);
  static const Color darkBorder = Color(0xFF262626);
  static const Color darkBorderSubtle = Color(0xFF1E1E1E);
  static const Color darkDivider = Color(0xFF2A2A2A);

  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFA0A0A0);
  static const Color darkTextHint = Color(0xFF6B6B6B);

  // ══════════════════════════════════════════
  // MODO CLARO (Light)
  // ══════════════════════════════════════════
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightCardHover = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFEEEEEE);
  static const Color lightDivider = Color(0xFFE0E0E0);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextHint = Color(0xFF94A3B8);

  // ══════════════════════════════════════════
  // SEMÂNTICAS — Status
  // ══════════════════════════════════════════

  // Sucesso / Lucro
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color successNeon = Color(0xFF00E699);
  static const Color successBgDark = Color(0x66064E3B);
  static const Color successBorderDark = Color(0xFF059669);
  static const Color successBgLight = Color(0xFFECFDF5);
  static const Color successBorderLight = Color(0xFFA7F3D0);
  static const Color successTextLight = Color(0xFF065F46);

  // Erro / Prejuízo / Crítico
  static const Color error = Color(0xFFDC2626);
  static const Color errorDark = Color(0xFFB91C1C);
  static const Color errorLight = Color(0xFFFCA5A5);
  static const Color errorBgDark = Color(0x66450A0A);
  static const Color errorBorderDark = Color(0xFFB91C1C);
  static const Color errorBgLight = Color(0xFFFEF2F2);
  static const Color errorBorderLight = Color(0xFFFECACA);
  static const Color errorTextLight = Color(0xFF991B1B);

  // Aviso / Atenção
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningBgDark = Color(0x66451A03);
  static const Color warningBorderDark = Color(0xFFD97706);
  static const Color warningBgLight = Color(0xFFFFFBEB);
  static const Color warningBorderLight = Color(0xFFFDE68A);
  static const Color warningTextLight = Color(0xFF92400E);

  // Info
  static const Color info = Color(0xFF3B82F6);
  static const Color infoDark = Color(0xFF2563EB);
  static const Color infoBgDark = Color(0x66172554);
  static const Color infoBorderDark = Color(0xFF2563EB);
  static const Color infoBgLight = Color(0xFFEFF6FF);
  static const Color infoBorderLight = Color(0xFFBFDBFE);
  static const Color infoTextLight = Color(0xFF1E40AF);

  // ══════════════════════════════════════════
  // CURVA ABC
  // ══════════════════════════════════════════
  static const Color classeA = Color(0xFF10B981); // Verde — 80% faturamento
  static const Color classeB = Color(0xFFF59E0B); // Amarelo — 15%
  static const Color classeC = Color(0xFFEF4444); // Vermelho — 5%

  static const Color classeABgDark = Color(0x3310B981);
  static const Color classeBBgDark = Color(0x33F59E0B);
  static const Color classeCBgDark = Color(0x33EF4444);

  static const Color classeABgLight = Color(0xFFECFDF5);
  static const Color classeBBgLight = Color(0xFFFFFBEB);
  static const Color classeCBgLight = Color(0xFFFEF2F2);

  // ══════════════════════════════════════════
  // GRADIENTES
  // ══════════════════════════════════════════
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFD4A843), Color(0xFFB4821E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradientSubtle = LinearGradient(
    colors: [Color(0x33D4A843), Color(0x1AB4821E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ══════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════

  /// Retorna a cor primária gold adequada ao tema
  static Color goldForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? gold : goldHighContrast;
  }

  /// Retorna cor de fundo de card adequada ao tema
  static Color cardForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? darkCard : lightCard;
  }

  /// Retorna cor de texto primário adequada ao tema
  static Color textPrimaryForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;
  }

  /// Retorna cor de texto secundário adequada ao tema
  static Color textSecondaryForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;
  }

  /// Retorna cor de borda adequada ao tema
  static Color borderForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? darkBorder : lightBorder;
  }
}
