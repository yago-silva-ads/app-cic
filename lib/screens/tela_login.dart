import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tela_dashboard.dart';
import '../web/tela_dashboard_web.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _isLoading = false;
  bool _isCadastro = false; // Alterna entre Login e Cadastro
  bool _obscureSenha = true;
  String? _errorMessage;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  /// Valida o formato do email
  String? _validarEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe seu e-mail';
    }
    // Regex básico para validação de email
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'E-mail inválido';
    }
    return null;
  }

  /// Valida a senha (mínimo 6 caracteres)
  String? _validarSenha(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe sua senha';
    }
    if (value.length < 6) {
      return 'A senha precisa ter pelo menos 6 caracteres';
    }
    return null;
  }

  /// Executa Login ou Cadastro
  Future<void> _submit() async {
    // Limpa erro anterior
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    try {
      if (_isCadastro) {
        // ── CADASTRO ──
        await supabase.auth.signUp(
          email: email,
          password: senha,
        );

        if (!mounted) return;

        // Alguns projetos Supabase exigem confirmação de email.
        // Verificamos se o usuário já está logado após o signUp.
        if (supabase.auth.currentUser != null) {
          _navegarParaDashboard();
        } else {
          setState(() {
            _errorMessage = null;
            _isLoading = false;
          });
          _mostrarSnackBar(
            'Cadastro realizado! Verifique seu e-mail para confirmar.',
            cor: Colors.green,
          );
        }
      } else {
        // ── LOGIN ──
        await supabase.auth.signInWithPassword(
          email: email,
          password: senha,
        );

        if (!mounted) return;
        _navegarParaDashboard();
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _traduzirErroAuth(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro inesperado. Tente novamente.';
      });
    }
  }

  /// Traduz mensagens de erro do Supabase para português
  String _traduzirErroAuth(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de fazer login.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'Este e-mail já está cadastrado. Faça login.';
    }
    if (msg.contains('signup is disabled')) {
      return 'Cadastro desabilitado. Contate o administrador.';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Muitas tentativas. Aguarde um momento.';
    }
    return message; // Retorna original se não mapeado
  }

  void _navegarParaDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => kIsWeb ? const TelaDashboardWeb() : const TelaDashboard(),
      ),
    );
  }

  void _mostrarSnackBar(String texto, {Color cor = Colors.blue}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo / Ícone ──
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.blue.shade800,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // ── Título ──
              Text(
                'App CIC',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isCadastro ? 'Crie sua conta' : 'Entre na sua conta',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blueGrey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // ── Card do Formulário ──
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Campo Email ──
                      TextFormField(
                        controller: _emailController,
                        validator: _validarEmail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Campo Senha ──
                      TextFormField(
                        controller: _senhaController,
                        validator: _validarSenha,
                        obscureText: _obscureSenha,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureSenha
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _obscureSenha = !_obscureSenha);
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Mensagem de Erro ──
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // ── Botão Principal ──
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  _isCadastro ? 'Criar Conta' : 'Entrar',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Alternar Login / Cadastro ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isCadastro
                        ? 'Já tem uma conta? '
                        : 'Não tem conta? ',
                    style: TextStyle(color: Colors.blueGrey.shade600),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCadastro = !_isCadastro;
                        _errorMessage = null;
                      });
                    },
                    child: Text(
                      _isCadastro ? 'Faça login' : 'Cadastre-se',
                      style: TextStyle(
                        color: Colors.blue.shade800,
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
    );
  }
}
