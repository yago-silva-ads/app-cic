import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

/// Card padrão (`rounded-2xl border bg-card`).
class CicCard extends StatelessWidget {
  const CicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.destaque = false,
    this.cor,
    this.borda,
    this.gradiente,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool destaque;
  final Color? cor;
  final Color? borda;
  final Gradient? gradiente;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradiente == null ? (cor ?? c.card) : null,
        gradient: gradiente,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borda ?? (destaque ? c.goldBorder : c.cardBorder)),
        boxShadow: c.isLight
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3, offset: const Offset(0, 1))]
            : null,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: box),
    );
  }
}

/// Superfície interna (caixas aninhadas).
class CicSub extends StatelessWidget {
  const CicSub({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.radius = 12});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.sub,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.subBorder),
      ),
      child: child,
    );
  }
}

enum BadgeTom { ouro, verde, ambar, vermelho, neutro }

class CicBadge extends StatelessWidget {
  const CicBadge(this.texto, {super.key, this.tom = BadgeTom.neutro, this.icone});
  final String texto;
  final BadgeTom tom;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, borda, fg) = switch (tom) {
      BadgeTom.ouro => (c.goldBg, c.goldBorder, c.gold),
      BadgeTom.verde => (c.emeraldBg, c.emeraldBorder, c.emerald),
      BadgeTom.ambar => (c.amberBg, c.amberBorder, c.amber),
      BadgeTom.vermelho => (c.redBg, c.redBorder, c.red),
      BadgeTom.neutro => (c.sub, c.subBorder, c.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[Icon(icone, size: 11, color: fg), const SizedBox(width: 4)],
          Text(texto, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Botão dourado primário (texto sempre preto).
class CicBotao extends StatelessWidget {
  const CicBotao(
    this.texto, {
    super.key,
    this.onPressed,
    this.icone,
    this.carregando = false,
    this.largo = false,
    this.perigo = false,
    this.secundario = false,
    this.compacto = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool carregando;
  final bool largo;
  final bool perigo;
  final bool secundario;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Color bg = perigo ? const Color(0xFFDC2626) : (secundario ? c.sub : c.botao);
    final Color fg = perigo ? Colors.white : (secundario ? c.text : Colors.black);
    final ativo = onPressed != null && !carregando;
    final btn = Material(
      color: ativo ? bg : bg.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: ativo ? onPressed : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compacto ? 12 : 16, vertical: compacto ? 9 : 13),
          decoration: secundario
              ? BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: c.subBorder))
              : null,
          child: Row(
            mainAxisSize: largo ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (carregando)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else if (icone != null)
                Icon(icone, size: 16, color: fg),
              if (carregando || icone != null) const SizedBox(width: 8),
              Flexible(
                child: Text(
                  texto,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: compacto ? 12 : 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return largo ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Campo de texto com rótulo (padrão dos formulários do AI Studio).
class CicCampo extends StatelessWidget {
  const CicCampo({
    super.key,
    this.rotulo,
    this.controller,
    this.dica,
    this.teclado,
    this.obscuro = false,
    this.icone,
    this.sufixo,
    this.onChanged,
    this.onSubmitted,
    this.formatters,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.maxLength,
    this.autofillHints,
  });

  final String? rotulo;
  final TextEditingController? controller;
  final String? dica;
  final TextInputType? teclado;
  final bool obscuro;
  final IconData? icone;
  final Widget? sufixo;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? formatters;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final int? maxLength;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rotulo != null) ...[
          Text(rotulo!.toUpperCase(),
              style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          keyboardType: teclado,
          obscureText: obscuro,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          inputFormatters: formatters,
          maxLines: obscuro ? 1 : maxLines,
          enabled: enabled,
          autofocus: autofocus,
          maxLength: maxLength,
          autofillHints: autofillHints,
          style: TextStyle(color: c.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: dica,
            counterText: '',
            prefixIcon: icone == null ? null : Icon(icone, size: 17, color: c.textMuted),
            suffixIcon: sufixo,
          ),
        ),
      ],
    );
  }
}

/// Título de seção dentro de cards (`text-sm font-bold uppercase`).
class CicTitulo extends StatelessWidget {
  const CicTitulo(this.titulo, {super.key, this.sub, this.trailing});
  final String titulo;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo.toUpperCase(),
                  style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub!, style: TextStyle(color: c.textMuted, fontSize: 11.5)),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class CicIconeCaixa extends StatelessWidget {
  const CicIconeCaixa(this.icone, {super.key, this.tom = BadgeTom.neutro, this.tamanho = 32});
  final IconData icone;
  final BadgeTom tom;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (tom) {
      BadgeTom.ouro => (c.goldBg, c.gold),
      BadgeTom.verde => (c.emeraldBg, c.emerald),
      BadgeTom.ambar => (c.amberBg, c.amber),
      BadgeTom.vermelho => (c.redBg, c.red),
      BadgeTom.neutro => (c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF262626), c.textSoft),
    };
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icone, size: tamanho * 0.5, color: fg),
    );
  }
}

class CicVazio extends StatelessWidget {
  const CicVazio({super.key, required this.icone, required this.titulo, this.texto, this.acao});
  final IconData icone;
  final String titulo;
  final String? texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 38, color: c.textMuted.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(titulo, textAlign: TextAlign.center, style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
            if (texto != null) ...[
              const SizedBox(height: 6),
              Text(texto!, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
            ],
            if (acao != null) ...[const SizedBox(height: 14), ?acao],
          ],
        ),
      ),
    );
  }
}

/// Faixa de erro visível. Erro nunca é mostrado como "lista vazia".
class CicErroBanner extends StatelessWidget {
  const CicErroBanner({super.key, required this.mensagem, this.onTentar});
  final String mensagem;
  final VoidCallback? onTentar;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.redBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.redBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: c.red, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(mensagem, style: TextStyle(color: c.red, fontSize: 12.5, height: 1.35))),
          if (onTentar != null) TextButton(onPressed: onTentar, child: Text('Tentar de novo', style: TextStyle(color: c.red))),
        ],
      ),
    );
  }
}

/// Mostra uma mensagem rápida (SnackBar).
void aviso(BuildContext context, String msg, {bool erro = false}) {
  final c = context.c;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(erro ? Icons.error_outline : Icons.check_circle_outline, size: 18, color: erro ? c.red : c.emerald),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      duration: Duration(seconds: erro ? 5 : 3),
    ));
}

Future<bool> confirmar(BuildContext context, String titulo, String texto, {String ok = 'Confirmar', bool perigo = false}) async {
  final c = context.c;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo, style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w800)),
      content: Text(texto, style: TextStyle(color: c.textMuted, fontSize: 13.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: TextStyle(color: c.textMuted))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok, style: TextStyle(color: perigo ? c.red : c.gold, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return r ?? false;
}

TextStyle fonteMono(BuildContext context, {double size = 14, FontWeight peso = FontWeight.w700, Color? cor}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: peso, color: cor ?? context.c.text);

/// Grade responsiva: tantas colunas quanto couberem com largura mínima [minLargura].
class CicGrid extends StatelessWidget {
  const CicGrid({super.key, required this.children, this.minLargura = 250, this.espaco = 16, this.maxColunas = 4});
  final List<Widget> children;
  final double minLargura;
  final double espaco;
  final int maxColunas;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      var cols = ((box.maxWidth + espaco) / (minLargura + espaco)).floor();
      cols = cols.clamp(1, maxColunas);
      final w = (box.maxWidth - espaco * (cols - 1)) / cols;
      return Wrap(
        spacing: espaco,
        runSpacing: espaco,
        children: [for (final f in children) SizedBox(width: w, child: f)],
      );
    });
  }
}

/// Página rolável padrão (permite puxar para atualizar).
class CicPagina extends StatelessWidget {
  const CicPagina({super.key, required this.children, this.padding, this.controller});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.fromLTRB(w >= 640 ? 24 : 12, 16, w >= 640 ? 24 : 12, 32),
      children: children,
    );
  }
}
