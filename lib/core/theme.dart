import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paleta do design do AI Studio (React/Tailwind), nos modos escuro e claro.
@immutable
class CicPalette extends ThemeExtension<CicPalette> {
  const CicPalette({
    required this.isLight,
    required this.bg,
    required this.sidebar,
    required this.header,
    required this.card,
    required this.cardBorder,
    required this.sub,
    required this.subBorder,
    required this.input,
    required this.inputBorder,
    required this.text,
    required this.textSoft,
    required this.textMuted,
    required this.gold,
    required this.goldBg,
    required this.goldBorder,
    required this.emerald,
    required this.emeraldBg,
    required this.emeraldBorder,
    required this.amber,
    required this.amberBg,
    required this.amberBorder,
    required this.red,
    required this.redBg,
    required this.redBorder,
  });

  final bool isLight;
  final Color bg, sidebar, header, card, cardBorder, sub, subBorder, input, inputBorder;
  final Color text, textSoft, textMuted;
  final Color gold, goldBg, goldBorder;
  final Color emerald, emeraldBg, emeraldBorder;
  final Color amber, amberBg, amberBorder;
  final Color red, redBg, redBorder;

  static const _ouro = Color(0xFFD4A843);

  static final escuro = CicPalette(
    isLight: false,
    bg: const Color(0xFF0D0D0D),
    sidebar: const Color(0xFF121212),
    header: const Color(0xFF111111),
    card: const Color(0xFF151515),
    cardBorder: const Color(0xFF252525),
    sub: const Color(0xFF1A1A1A),
    subBorder: const Color(0xFF2A2A2A),
    input: const Color(0xFF161616),
    inputBorder: const Color(0xFF2E2E2E),
    text: Colors.white,
    textSoft: const Color(0xFFD4D4D4),
    textMuted: const Color(0xFFA3A3A3),
    gold: _ouro,
    goldBg: _ouro.withValues(alpha: 0.15),
    goldBorder: _ouro.withValues(alpha: 0.30),
    emerald: const Color(0xFF34D399),
    emeraldBg: const Color(0xFF022C22).withValues(alpha: 0.6),
    emeraldBorder: const Color(0xFF065F46),
    amber: const Color(0xFFFBBF24),
    amberBg: const Color(0xFF451A03).withValues(alpha: 0.6),
    amberBorder: const Color(0xFF92400E),
    red: const Color(0xFFF87171),
    redBg: const Color(0xFF450A0A).withValues(alpha: 0.4),
    redBorder: const Color(0xFFB91C1C),
  );

  static const claro = CicPalette(
    isLight: true,
    bg: Color(0xFFF8FAFC),
    sidebar: Colors.white,
    header: Color(0xF2FFFFFF),
    card: Colors.white,
    cardBorder: Color(0xFFE2E8F0),
    sub: Color(0xFFF8FAFC),
    subBorder: Color(0xFFE2E8F0),
    input: Colors.white,
    inputBorder: Color(0xFFCBD5E1),
    text: Color(0xFF0F172A),
    textSoft: Color(0xFF1E293B),
    textMuted: Color(0xFF64748B),
    gold: Color(0xFFB4821E),
    goldBg: Color(0xFFFEF3C7),
    goldBorder: Color(0xFFFDE68A),
    emerald: Color(0xFF059669),
    emeraldBg: Color(0xFFECFDF5),
    emeraldBorder: Color(0xFFA7F3D0),
    amber: Color(0xFFD97706),
    amberBg: Color(0xFFFFFBEB),
    amberBorder: Color(0xFFFDE68A),
    red: Color(0xFFDC2626),
    redBg: Color(0xFFFEF2F2),
    redBorder: Color(0xFFFECACA),
  );

  /// Dourado dos botões primários: igual nos dois temas.
  Color get botao => _ouro;

  @override
  CicPalette copyWith() => this;

  @override
  CicPalette lerp(ThemeExtension<CicPalette>? other, double t) =>
      other is CicPalette ? (t < 0.5 ? this : other) : this;
}

extension CicContext on BuildContext {
  CicPalette get c => Theme.of(this).extension<CicPalette>()!;
}

ThemeData construirTema(CicPalette p) {
  final base = p.isLight ? ThemeData.light() : ThemeData.dark();
  final texto = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: p.text,
    displayColor: p.text,
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.sidebar,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFD4A843),
      brightness: p.isLight ? Brightness.light : Brightness.dark,
    ).copyWith(
      primary: p.gold,
      surface: p.card,
      onSurface: p.text,
      error: p.red,
    ),
    textTheme: texto,
    dividerColor: p.cardBorder,
    extensions: [p],
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: p.input,
      hintStyle: TextStyle(color: p.textMuted.withValues(alpha: 0.7), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.gold, width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.sub,
      contentTextStyle: TextStyle(color: p.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.subBorder),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.cardBorder),
      ),
    ),
  );
}

/// Tema e tamanho de letra escolhidos, persistidos no aparelho.
class TemaController extends ChangeNotifier {
  static const _chave = 'app_cic_tema_v2';
  static const _chaveLetra = 'app_cic_letra_v1';

  /// Tamanhos de letra oferecidos (acessibilidade para quem enxerga pouco).
  static const escalas = [1.0, 1.2, 1.4];
  static const rotulosEscala = ['Normal', 'Grande', 'Muito grande'];

  bool _claro = false;
  double _escala = 1.0;
  bool get claro => _claro;
  double get escala => _escala;
  String get rotuloEscala => rotulosEscala[escalas.indexOf(_escala).clamp(0, escalas.length - 1)];
  CicPalette get paleta => _claro ? CicPalette.claro : CicPalette.escuro;

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _claro = prefs.getString(_chave) == 'light';
      final e = prefs.getDouble(_chaveLetra) ?? 1.0;
      _escala = escalas.contains(e) ? e : 1.0;
    } catch (_) {
      _claro = false;
    }
    notifyListeners();
  }

  /// Alterna Normal → Grande → Muito grande → Normal.
  Future<void> proximaEscala() async {
    final i = escalas.indexOf(_escala);
    _escala = escalas[(i + 1) % escalas.length];
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_chaveLetra, _escala);
    } catch (_) {}
  }

  Future<void> alternar() async {
    _claro = !_claro;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, _claro ? 'light' : 'dark');
    } catch (_) {}
  }
}
