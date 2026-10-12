import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/shell.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'data/auth_service.dart';
import 'screens/auth_screen.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.supabaseAnonKey);
  final tema = TemaController();
  await tema.carregar();
  runApp(CicApp(tema: tema));
}

class CicApp extends StatelessWidget {
  const CicApp({super.key, required this.tema});
  final TemaController tema;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tema,
      builder: (context, _) => MaterialApp(
        title: 'APP-CIC',
        debugShowCheckedModeBanner: false,
        theme: construirTema(tema.paleta),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Letra maior escolhida pelo usuário (soma-se à do próprio celular).
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final sistema = mq.textScaler.scale(1);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear((sistema * tema.escala).clamp(1.0, 2.0))),
            child: child!,
          );
        },
        home: _Porteiro(tema: tema),
      ),
    );
  }
}

/// Decide entre login e app conforme a sessão do Supabase. O estado da loja é
/// recriado a cada usuário, então nada de uma conta vaza para a outra.
class _Porteiro extends StatefulWidget {
  const _Porteiro({required this.tema});
  final TemaController tema;

  @override
  State<_Porteiro> createState() => _PorteiroState();
}

class _PorteiroState extends State<_Porteiro> {
  final _auth = AuthService();
  AppState? _estado;
  String? _uid;

  @override
  void dispose() {
    _estado?.dispose();
    super.dispose();
  }

  AppState _estadoPara(String uid) {
    if (_uid != uid) {
      _estado?.dispose();
      _estado = AppState(tema: widget.tema);
      _uid = uid;
    }
    return _estado!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final sessao = Supabase.instance.client.auth.currentSession;
        if (sessao == null) {
          _estado?.dispose();
          _estado = null;
          _uid = null;
          return AuthScreen(auth: _auth, tema: widget.tema);
        }
        return AppShell(estado: _estadoPara(sessao.user.id), auth: _auth);
      },
    );
  }
}
