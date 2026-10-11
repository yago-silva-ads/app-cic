import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import '../data/auth_service.dart';
import '../data/repository.dart';
import '../ui/widgets.dart';

/// Tela de login / cadastro (porte de `AuthScreen.tsx`).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth, required this.tema});
  final AuthService auth;
  final TemaController tema;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _cadastro = false;
  bool _verSenha = false;
  bool _carregando = false;
  String? _erro;
  String? _ok;

  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _nome = TextEditingController();
  final _loja = TextEditingController();
  final _doc = TextEditingController();

  @override
  void dispose() {
    for (final c in [_email, _senha, _nome, _loja, _doc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _erro = null;
      _ok = null;
    });
    if (_email.text.trim().isEmpty || _senha.text.isEmpty) {
      setState(() => _erro = 'Preencha seu e-mail e sua senha de acesso.');
      return;
    }
    setState(() => _carregando = true);
    try {
      if (!_cadastro) {
        await widget.auth.entrar(_email.text, _senha.text);
        // O listener de sessão em main.dart troca a tela.
      } else {
        if (_nome.text.trim().isEmpty || _loja.text.trim().isEmpty) {
          throw ErroCic('Preencha o seu nome e o nome do seu estabelecimento.');
        }
        final logado = await widget.auth.cadastrar(
          email: _email.text,
          senha: _senha.text,
          nome: _nome.text,
          lojaNome: _loja.text,
          documento: _doc.text,
        );
        if (!logado && mounted) {
          setState(() {
            _cadastro = false;
            _ok = 'Cadastro realizado! Enviamos um link de confirmação para o seu e-mail. Confirme e depois entre.';
          });
        }
      }
    } on ErroCic catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _google() async {
    setState(() => _erro = null);
    try {
      await widget.auth.entrarComGoogle();
    } on ErroCic catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  // Marca
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: c.goldBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.gold.withValues(alpha: 0.4)),
                      boxShadow: [BoxShadow(color: c.gold.withValues(alpha: 0.12), blurRadius: 18)],
                    ),
                    child: Icon(LucideIcons.qrCode, size: 34, color: c.gold),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text('APP-CIC',
                          style: TextStyle(color: c.text, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const CicBadge('Sistema Comercial', tom: BadgeTom.ouro),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Frente de Caixa, Controle de Estoque e Vendas para sua Loja',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  // Card principal
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: c.cardBorder),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isLight ? 0.06 : 0.4), blurRadius: 30, offset: const Offset(0, 12))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _alternador(c),
                        const SizedBox(height: 20),
                        if (_erro != null) _caixaMsg(c, _erro!, erro: true),
                        if (_ok != null) _caixaMsg(c, _ok!, erro: false),
                        _botaoGoogle(c),
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(child: Divider(color: c.cardBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('ou com seu e-mail', style: TextStyle(color: c.textMuted, fontSize: 11)),
                          ),
                          Expanded(child: Divider(color: c.cardBorder)),
                        ]),
                        const SizedBox(height: 18),
                        AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_cadastro) ...[
                                CicCampo(rotulo: 'Seu nome completo', controller: _nome, dica: 'Ex: Carlos Eduardo', icone: LucideIcons.user, autofillHints: const [AutofillHints.name]),
                                const SizedBox(height: 14),
                                CicCampo(rotulo: 'Nome da empresa ou loja *', controller: _loja, dica: 'Ex: Mercadinho & Drogaria Central', icone: LucideIcons.store),
                                const SizedBox(height: 14),
                                CicCampo(rotulo: 'CNPJ da empresa ou CPF do MEI (opcional)', controller: _doc, dica: '00.000.000/0001-00', icone: LucideIcons.shieldCheck, teclado: TextInputType.number),
                                const SizedBox(height: 4),
                                Text('Usado para o cupom de venda e a chave PIX da sua loja.',
                                    style: TextStyle(color: c.textMuted, fontSize: 10)),
                                const SizedBox(height: 14),
                              ],
                              CicCampo(
                                rotulo: 'Seu e-mail',
                                controller: _email,
                                dica: 'contato@minhaloja.com.br',
                                icone: LucideIcons.mail,
                                teclado: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                              ),
                              const SizedBox(height: 14),
                              CicCampo(
                                rotulo: 'Senha de acesso',
                                controller: _senha,
                                dica: '••••••••',
                                icone: LucideIcons.lock,
                                obscuro: !_verSenha,
                                autofillHints: [_cadastro ? AutofillHints.newPassword : AutofillHints.password],
                                onSubmitted: (_) => _enviar(),
                                sufixo: IconButton(
                                  icon: Icon(_verSenha ? LucideIcons.eyeOff : LucideIcons.eye, size: 17, color: c.textMuted),
                                  onPressed: () => setState(() => _verSenha = !_verSenha),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        CicBotao(
                          _cadastro ? 'Cadastrar Minha Loja' : 'Entrar no Sistema',
                          icone: LucideIcons.arrowRight,
                          largo: true,
                          carregando: _carregando,
                          onPressed: _enviar,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 22,
                    runSpacing: 8,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.shieldCheck, size: 14, color: c.emerald),
                        const SizedBox(width: 6),
                        Text('Dados isolados por loja', style: TextStyle(color: c.textMuted, fontSize: 11)),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.sparkles, size: 14, color: c.gold),
                        const SizedBox(width: 6),
                        Text('Assistente inteligente', style: TextStyle(color: c.textMuted, fontSize: 11)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: widget.tema.alternar,
                    icon: Icon(widget.tema.claro ? LucideIcons.moon : LucideIcons.sun, size: 14, color: c.textMuted),
                    label: Text(widget.tema.claro ? 'Tema escuro' : 'Tema claro', style: TextStyle(color: c.textMuted, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _alternador(CicPalette c) {
    Widget aba(String t, bool ativa, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: ativa ? c.botao : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(t,
              textAlign: TextAlign.center,
              style: TextStyle(color: ativa ? Colors.black : c.textMuted, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.subBorder),
      ),
      child: Row(children: [
        aba('Fazer Login', !_cadastro, () => setState(() {
          _cadastro = false;
          _erro = null;
        })),
        aba('Criar Conta', _cadastro, () => setState(() {
          _cadastro = true;
          _erro = null;
        })),
      ]),
    );
  }

  Widget _caixaMsg(CicPalette c, String texto, {required bool erro}) {
    final cor = erro ? c.red : c.emerald;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(erro ? LucideIcons.circleAlert : LucideIcons.circleCheck, size: 18, color: cor),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: cor, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }

  Widget _botaoGoogle(CicPalette c) => Material(
    color: c.isLight ? Colors.white : const Color(0xFF1F1F1F),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _carregando ? null : _google,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.isLight ? const Color(0xFFCBD5E1) : const Color(0xFF333333)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('G', style: TextStyle(color: const Color(0xFF4285F4), fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(width: 10),
            Text('Continuar com o Google', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}
