/// Fora da Web não há leitor JS: usa-se o leitor nativo (mobile_scanner).
Future<String?> abrirLeitorWeb() async => null;

bool get leitorWebDisponivel => false;
