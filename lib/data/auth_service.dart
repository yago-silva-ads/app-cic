import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository.dart';
import '../core/convite.dart';

/// Login, cadastro e sessão via Supabase Auth.
///
/// O bloqueio por tentativas aqui é só ergonomia (o aparelho pode limpar os
/// dados). A defesa real contra força bruta é o rate limit do Supabase Auth.
class AuthService {
  AuthService([SupabaseClient? client]) : _auth = (client ?? Supabase.instance.client).auth;

  final GoTrueClient _auth;

  static const _chaveTentativas = 'app_cic_sec_login_attempts';
  static const _maxFalhas = 5;
  static const _janela = Duration(minutes: 5);
  static const _bloqueio = Duration(minutes: 15);
  static const _senhaMinima = 12;

  static bool emailValido(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());

  static bool senhaForte(String senha) => senha.length >= _senhaMinima &&
      RegExp(r'[a-z]').hasMatch(senha) &&
      RegExp(r'[A-Z]').hasMatch(senha) &&
      RegExp(r'\d').hasMatch(senha);

  /// Remove caracteres de controle e limita o tamanho. Não filtra aspas nem
  /// palavras: o PostgREST usa parâmetros, e nomes como "D'Ávila" são válidos.
  static String limpar(String s, [int max = 120]) {
    final t = s.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '').trim();
    return t.length > max ? t.substring(0, max) : t;
  }

  Future<Map<String, dynamic>> _lerTentativas() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_chaveTentativas);
      return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _gravarTentativas(Map<String, dynamic> m) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_chaveTentativas, jsonEncode(m));
    } catch (_) {}
  }

  /// Minutos restantes de bloqueio (0 = liberado).
  Future<int> minutosBloqueado(String email) async {
    final m = await _lerTentativas();
    final r = m[email] as Map?;
    if (r == null) return 0;
    final agora = DateTime.now().millisecondsSinceEpoch;
    final ate = (r['bloqueadoAte'] as num?)?.toInt();
    if (ate != null && ate > agora) return ((ate - agora) / 60000).ceil();
    final ultima = (r['ultima'] as num?)?.toInt() ?? 0;
    if (agora - ultima > _janela.inMilliseconds) {
      m.remove(email);
      await _gravarTentativas(m);
    }
    return 0;
  }

  Future<int> _registrarFalha(String email) async {
    final m = await _lerTentativas();
    final agora = DateTime.now().millisecondsSinceEpoch;
    final r = Map<String, dynamic>.from((m[email] as Map?) ?? {'falhas': 0});
    r['falhas'] = ((r['falhas'] as num?)?.toInt() ?? 0) + 1;
    r['ultima'] = agora;
    var bloqueado = 0;
    if ((r['falhas'] as int) >= _maxFalhas) {
      r['bloqueadoAte'] = agora + _bloqueio.inMilliseconds;
      bloqueado = _bloqueio.inMinutes;
    }
    m[email] = r;
    await _gravarTentativas(m);
    return bloqueado;
  }

  Future<void> _limparFalhas(String email) async {
    final m = await _lerTentativas();
    if (m.remove(email) != null) await _gravarTentativas(m);
  }

  Future<void> entrar(String email, String senha) async {
    final e = limpar(email).toLowerCase();
    if (!emailValido(e) || senha.isEmpty) {
      throw ErroCic('Informe um e-mail válido e sua senha de acesso.');
    }
    final min = await minutosBloqueado(e);
    if (min > 0) {
      throw ErroCic('Muitas tentativas incorretas. Por segurança, aguarde $min minuto(s) antes de tentar novamente.');
    }
    try {
      final r = await _auth.signInWithPassword(email: e, password: senha);
      if (r.user == null) throw ErroCic('Credenciais inválidas.');
      await _limparFalhas(e);
    } on AuthException catch (ex) {
      final bloq = await _registrarFalha(e);
      if (bloq > 0) {
        throw ErroCic('Conta temporariamente bloqueada por $bloq minutos após 5 tentativas incorretas.');
      }
      final msg = ex.message.toLowerCase();
      if (msg.contains('rate') || ex.statusCode == '429') {
        throw ErroCic('Muitas tentativas. Aguarde alguns minutos e tente de novo.');
      }
      // Mesma resposta para conta inexistente, senha errada ou e-mail não confirmado.
      throw ErroCic('Não foi possível entrar. Verifique seus dados ou a caixa de entrada.');
    } on ErroCic {
      rethrow;
    } catch (_) {
      throw ErroCic('Sem conexão com o servidor. Verifique a internet e tente de novo.');
    }
  }

  /// Retorna true se já há sessão ativa (confirmação de e-mail desligada) e
  /// false se o Supabase exige confirmar o e-mail antes.
  Future<bool> cadastrar({
    required String email,
    required String senha,
    required String nome,
    required String lojaNome,
    String documento = '',
    String? convite,
  }) async {
    final e = limpar(email).toLowerCase();
    final n = limpar(nome, 60);
    final l = limpar(lojaNome, 80);
    final slug = validarConvite(convite);
    if (!emailValido(e) || n.isEmpty || l.isEmpty) {
      throw ErroCic('Preencha todos os campos obrigatórios.');
    }
    if (!senhaForte(senha)) {
      throw ErroCic('Use uma senha com ao menos 12 caracteres, incluindo letras maiúsculas, minúsculas e números.');
    }
    try {
      final r = await _auth.signUp(
        email: e,
        password: senha,
        data: {
          'nome': n,
          'lojaNome': l,
          'documento': limpar(documento, 20),
          'convite': ?slug,
          if (slug != null) 'origem': 'leadforge',
        },
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
      );
      // Resultado indistinguível para evitar enumeração de contas pelo cadastro.
      return r.user != null && r.session != null;
    } on AuthException catch (ex) {
      final m = ex.message.toLowerCase();
      if (m.contains('password')) {
        throw ErroCic('Use uma senha com ao menos 12 caracteres, incluindo letras maiúsculas, minúsculas e números.');
      }
      throw ErroCic('Não foi possível criar a conta agora. Tente de novo em instantes.');
    } on ErroCic {
      rethrow;
    } catch (_) {
      throw ErroCic('Sem conexão com o servidor. Verifique a internet e tente de novo.');
    }
  }

  Future<void> entrarComGoogle() async {
    try {
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
    } catch (_) {
      throw ErroCic('Não foi possível entrar com o Google neste momento. Use seu e-mail e senha.');
    }
  }

  Future<void> sair() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Se a revogação remota falhar, ainda encerra a sessão deste dispositivo.
      try {
        await _auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
    } finally {
      try {
        final p = await SharedPreferences.getInstance();
        // Preserva apenas o tema; sessão, cache da loja e tentativas são limpos.
        for (final k in p.getKeys().where((k) => k != 'app_cic_tema_v2')) {
          await p.remove(k);
        }
      } catch (_) {}
    }
  }
}
