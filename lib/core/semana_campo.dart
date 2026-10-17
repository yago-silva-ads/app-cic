/// Segunda-feira à meia-noite no calendário local usado pelo formulário.
DateTime inicioSemanaCampo(DateTime agora) {
  return DateTime(agora.year, agora.month, agora.day - (agora.weekday - 1));
}
