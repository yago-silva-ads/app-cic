import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../services/storage_service.dart';
import '../main_layout.dart';
import 'register_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// LoginScreen — Tela de Login Premium Dourada v2.0
///
/// Design fintech com logo QR, campos estilizados, "lembrar de mim",
/// botão dourado e link de cadastro. Suporte dark/light theme.
/// ═══════════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;
  bool _lembrarMe = true;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _lembrarMe = StorageService.getRememberMe();
    final savedEmail = StorageService.getSavedEmail();
    if (savedEmail != null) {
      _emailController.text = savedEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );

      // Salvar "lembrar de mim"
      await StorageService.saveRememberMe(
        _lembrarMe,
        _emailController.text.trim(),
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        String msg = 'Erro de autenticação.';
        if (e.message.contains('Invalid login credentials')) {
          msg = 'E-mail ou senha incorretos.';
        } else if (e.message.contains('Email not confirmed')) {
          msg = 'Confirme seu e-mail antes de entrar.';
        } else if (e.message.contains('Too many requests')) {
          msg = 'Muitas tentativas. Aguarde um momento.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro de conexão: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ──
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: gold.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(Icons.qr_code_scanner_rounded, size: 40, color: gold),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Título ──
                  Text(
                    'APP-CIC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestão Inteligente de Estoque, PDV & IA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Campo E-mail ──
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe seu e-mail comercial';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'E-mail inválido';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'E-mail Comercial',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Campo Senha ──
                  TextFormField(
                    controller: _senhaController,
                    obscureText: _ocultarSenha,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _fazerLogin(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe sua senha de acesso';
                      }
                      if (value.length < 6) {
                        return 'Senha deve ter no mínimo 6 caracteres';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Senha de Acesso',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _ocultarSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Lembrar de mim ──
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _lembrarMe,
                          activeColor: gold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) => setState(() => _lembrarMe = val ?? true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lembrar neste dispositivo',
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Botão Login ──
                  ElevatedButton(
                    onPressed: _carregando ? null : _fazerLogin,
                    child: _carregando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('ENTRAR NO SISTEMA'),
                  ),
                  const SizedBox(height: 28),

                  // ── Link Cadastro ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Novo lojista? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: Text(
                          'Cadastre sua loja',
                          style: TextStyle(
                            fontSize: 13,
                            color: gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // ── Versão ──
                  Text(
                    'v2.0.0 • Powered by Gemini IA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                    ),
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
