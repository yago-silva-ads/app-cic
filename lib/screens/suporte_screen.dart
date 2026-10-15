import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

enum _Estado { verificando, ok, atencao, erro }

class _Check {
  _Check(this.titulo, this.descricao);
  final String titulo;
  final String descricao;
  _Estado estado = _Estado.verificando;
  String detalhe = '';
}

/// Ajuda e diagnóstico REAL: cada item testa o serviço de verdade. Nada é
/// mostrado como "operacional" sem ter sido verificado agora.
class SuporteScreen extends StatefulWidget {
  const SuporteScreen({super.key, required this.estado});
  final AppState estado;

  @override
  State<SuporteScreen> createState() => _SuporteScreenState();
}

class _SuporteScreenState extends State<SuporteScreen> {
  late List<_Check> _checks;
  bool _rodando = false;

  @override
  void initState() {
    super.initState();
    _checks = _novos();
    _rodar();
  }

  List<_Check> _novos() => [
    _Check('Banco de dados (Supabase)', 'Leitura do seu estoque com a sua sessão'),
    _Check('Atualização v3 do banco', 'Venda atômica, código único por loja e movimentações'),
    _Check('Consultor de IA', 'Função segura que fala com as IAs (Gemini, Groq)'),
    _Check('Sessão e isolamento', 'Dados presos à sua loja pela sessão'),
  ];

  Future<void> _rodar() async {
    if (_rodando) return;
    setState(() {
      _rodando = true;
      _checks = _novos();
    });
    final db = Supabase.instance.client;

    // 1. Banco
    try {
      await db.from('produtos').select('codigo').limit(1);
      _set(0, _Estado.ok, 'Conectado');
    } on PostgrestException catch (e) {
      _set(0, _Estado.erro, 'Erro ${e.code ?? ''}: ${e.message}');
    } catch (_) {
      _set(0, _Estado.erro, 'Sem conexão com o servidor');
    }

    // 2. Migração v3: chama a função com lista vazia; ela deve responder ITENS_VAZIOS.
    try {
      await db.rpc('registrar_venda', params: {'p_itens': <Object>[]});
      _set(1, _Estado.atencao, 'Resposta inesperada da função');
    } on PostgrestException catch (e) {
      if (e.message.contains('ITENS_VAZIOS')) {
        _set(1, _Estado.ok, 'Aplicada');
      } else if (e.code == 'PGRST202' || e.code == '42883') {
        _set(1, _Estado.erro, 'PENDENTE: rode supabase/migracao_v3_estoque_atomico_e_isolamento.sql no SQL Editor. Sem isso, vendas e entradas de estoque não funcionam.');
      } else {
        _set(1, _Estado.atencao, 'Erro ${e.code ?? ''}: ${e.message}');
      }
    } catch (_) {
      _set(1, _Estado.erro, 'Sem conexão com o servidor');
    }

    // 3. IA: preflight na função (200/204 = publicada).
    try {
      final r = await (http.Request('OPTIONS', Uri.parse(Config.iaFunctionUrl))
            ..headers['Origin'] = 'https://app'
            ..headers['Access-Control-Request-Method'] = 'POST')
          .send()
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200 || r.statusCode == 204) {
        _set(2, _Estado.ok, 'Função publicada. Perguntas objetivas funcionam mesmo sem IA.');
      } else if (r.statusCode == 404) {
        _set(2, _Estado.atencao, 'Função ainda não publicada. O app responde estoque, faturamento e ABC sem IA; análises abertas mostram só os dados calculados.');
      } else {
        _set(2, _Estado.atencao, 'Resposta ${r.statusCode} da função de IA.');
      }
    } catch (_) {
      _set(2, _Estado.atencao, 'Não foi possível verificar a função de IA agora.');
    }

    // 4. Sessão
    final u = db.auth.currentUser;
    _set(3, u == null ? _Estado.erro : _Estado.ok, u == null ? 'Sem sessão' : 'Logado como ${u.email ?? u.id}');

    if (mounted) setState(() => _rodando = false);
  }

  void _set(int i, _Estado e, String d) {
    if (!mounted) return;
    setState(() {
      _checks[i].estado = e;
      _checks[i].detalhe = d;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CicPagina(children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CicCard(
              padding: const EdgeInsets.all(22),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CicIconeCaixa(LucideIcons.lifeBuoy, tom: BadgeTom.ouro, tamanho: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Central de Ajuda & Status do Sistema', style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('APP-CIC v2.0 — frente de caixa, estoque por loja, importação de NF-e e consultor de IA aterrado em dados reais.',
                        style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.4)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            CicCard(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(LucideIcons.shieldCheck, size: 18, color: c.emerald),
                  const SizedBox(width: 8),
                  Expanded(child: Text('DIAGNÓSTICO AO VIVO', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
                  CicBotao(_rodando ? 'Verificando...' : 'Verificar de novo', icone: LucideIcons.refreshCw, secundario: true, compacto: true, onPressed: _rodando ? null : _rodar),
                ]),
                const SizedBox(height: 14),
                for (final k in _checks) Padding(padding: const EdgeInsets.only(bottom: 10), child: _linha(c, k)),
              ]),
            ),
            const SizedBox(height: 16),
            CicCard(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('COMO USAR NO IPHONE', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                for (final t in const [
                  'Abra o endereço do app no Safari.',
                  'Toque em Compartilhar e depois em "Adicionar à Tela de Início".',
                  'Abra pelo ícone APP-CIC: roda em tela cheia, como um app.',
                  'Na primeira vez que usar a câmera, toque em "Permitir".',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(LucideIcons.chevronRight, size: 14, color: c.gold),
                      const SizedBox(width: 6),
                      Expanded(child: Text(t, style: TextStyle(color: c.textSoft, fontSize: 12.5, height: 1.4))),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _linha(CicPalette c, _Check k) {
    final (cor, rotulo) = switch (k.estado) {
      _Estado.verificando => (c.textMuted, 'VERIFICANDO'),
      _Estado.ok => (c.emerald, 'OK'),
      _Estado.atencao => (c.amber, 'ATENÇÃO'),
      _Estado.erro => (c.red, 'PROBLEMA'),
    };
    return CicSub(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: cor.withValues(alpha: 0.25), spreadRadius: 3)]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.titulo, style: TextStyle(color: c.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
            Text(k.descricao, style: TextStyle(color: c.textMuted, fontSize: 11)),
            if (k.detalhe.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(k.detalhe, style: TextStyle(color: cor, fontSize: 11.5, height: 1.35))),
          ]),
        ),
        const SizedBox(width: 8),
        CicBadge(rotulo, tom: switch (k.estado) {
          _Estado.ok => BadgeTom.verde,
          _Estado.atencao => BadgeTom.ambar,
          _Estado.erro => BadgeTom.vermelho,
          _Estado.verificando => BadgeTom.neutro,
        }),
      ]),
    );
  }
}
