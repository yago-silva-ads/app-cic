/// Configuração pública do app. A chave "anon" do Supabase é pública por
/// desenho: quem protege os dados é a RLS do banco, não o sigilo da chave.
///
/// Pode ser trocada no build:
///   flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class Config {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://drszfkijbemrzzgxvboy.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyc3pma2lqYmVtcnp6Z3h2Ym95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5ODU3NzIsImV4cCI6MjA5NTU2MTc3Mn0.TYgZDdviLlJoPR5ZFlLqHt9ltzeIwv2IWLMGFlqmA3Y',
  );

  /// Endpoint da Edge Function de IA (a chave do Gemini fica no servidor).
  /// `--dart-define=DEMO=true`: loja de exemplo em memória, sem login (tutoriais e teste do cliente).
  static const demo = bool.fromEnvironment('DEMO');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'suporte@app-cic.com');

  static String get iaFunctionUrl => '$supabaseUrl/functions/v1/ia-consultor';
  static String get marketFunctionUrl => '$supabaseUrl/functions/v1/analise-mercado';
}
