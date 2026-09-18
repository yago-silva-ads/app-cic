import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../main_layout.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// RegisterScreen — Cadastro de Nova Loja Premium v2.0
///
/// Nome da loja, e-mail, senha e confirmação. Registro via Supabase Auth.
/// ═══════════════════════════════════════════════════════════════════════
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmaSenhaController = TextEditingController();
  bool _ocultarSenha = true;
  bool _ocultarConfirma = true;
  bool _carregando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmaSenhaController.dispose();
    super.dispose();
  }

  Future<void> _criarConta() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _senhaController.text,
        data: {'store_name': _nomeController.text.trim()},
      );

      if (!mounted) return;

      if (response.user != null && response.session != null) {
        // Cadastro e login automático
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
          (_) => false,
        );
      } else {
        // Precisa confirmar e-mail
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada! Verifique seu e-mail para confirmar.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      String msg = 'Erro ao criar conta.';
      if (e.message.contains('already registered')) {
        msg = 'Este e-mail já está cadastrado.';
      } else if (e.message.contains('weak password')) {
        msg = 'Senha muito fraca. Use pelo menos 6 caracteres.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro de conexão: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);
    final textPrimary = AppColors.textPrimaryForBrightness(Theme.of(context).brightness);
    final textSecondary = AppColors.textSecondaryForBrightness(Theme.of(context).brightness);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Conta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Ícone ──
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: gold.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.store_rounded, size: 36, color: gold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Cadastre sua Loja',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Comece a gerenciar seu estoque com inteligência',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Nome da Loja ──
                  TextFormField(
                    controller: _nomeController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Informe o nome da loja' : null,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Loja',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── E-mail ──
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                      if (!v.contains('@') || !v.contains('.')) return 'E-mail inválido';
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'E-mail Comercial',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Senha ──
                  TextFormField(
                    controller: _senhaController,
                    obscureText: _ocultarSenha,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe a senha';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_ocultarSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Confirmar Senha ──
                  TextFormField(
                    controller: _confirmaSenhaController,
                    obscureText: _ocultarConfirma,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _criarConta(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirme a senha';
                      if (v != _senhaController.text) return 'As senhas não coincidem';
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirmar Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_ocultarConfirma ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _ocultarConfirma = !_ocultarConfirma),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Botão Criar ──
                  ElevatedButton(
                    onPressed: _carregando ? null : _criarConta,
                    child: _carregando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('CRIAR MINHA CONTA'),
                  ),
                  const SizedBox(height: 20),

                  // ── Link voltar ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Já tem conta? ',
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Entrar agora',
                          style: TextStyle(
                            fontSize: 13,
                            color: gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
