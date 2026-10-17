/// Convites são identificadores de campanha, não autorização de acesso.
/// Valores inválidos são ignorados, sem normalizar ou truncar o slug.
String? validarConvite(String? slug) {
  if (slug == null || slug.isEmpty || slug.length > 80) return null;
  return RegExp(r'[^a-z0-9-]').hasMatch(slug) ? null : slug;
}
