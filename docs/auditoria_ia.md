# Auditoria adversarial do assistente APP-CIC

> Estado posterior: já foram corrigidos o aterramento por produto/classe, a rejeição de sinais, unidades e datas inválidas, a validação de tipos/métricas e o fallback do domínio; este relatório preserva os achados e diffs históricos, não descreve integralmente a release atual.

Inspeção offline de `release-blindada`, HEAD observado `44cfbef6f19325caa43638bcf359ed3bc6a5c182`, em 15/10/2026. Referências abaixo são caminhos e linhas dessa cópia, não do branch antigo de documentação. Nenhum arquivo da cópia do Claude foi modificado. Não foram feitas chamadas a provedores. Dart/Flutter não estavam no PATH; os testes propostos não foram executados.

## Resultado e critérios

As garantias absolutas “nunca para, nunca inventa número e nunca sai do escopo” não são asseguradas. Há contraexemplos determinísticos de inspeção: números verdadeiros associados ao produto errado passam pela trava, texto fora do escopo passa sem números e erros de tipo podem escapar do fallback. O objetivo verificável é devolver resposta calculada ou aviso dentro de um prazo total, sem exibir afirmações do modelo que não tenham evidência vinculada.

Gravidade: **crítica** = quebra direta da confiança dos dados; **alta** = orientação comercial errada ou indisponibilidade; **média** = fragilidade de contrato ou experiência com recuperação parcial. Os diffs são sugestões de revisão, não foram aplicados nem compilados. Os trechos de contrato novo estão explicitamente identificados; não devem ser aplicados isoladamente como solução completa.

## 1. Aterramento permite trocar produto, medida, data e unidade — crítica

**Local:** `packages/cic_domain/lib/src/ia/guarda_aterramento.dart:34-37,54-89,116-119,152-160,170-211`.

**Cenário:** na fixture `01_classes_e_ruptura.json`, Café tem saldo 5, Fósforo tem 40 e Leite faturou R$ 150. A resposta “Café 500g tem 40 unidades e faturou R$ 150,00.”, com fonte `p-700`, passa: 40 e 150 existem em algum lugar do contexto. A chave de uma métrica também não é conferida: `{'estoqueCafe': 40}` passa. Os números fixos 1, 7, 30 e percentuais de ABC ampliam a lista de valores permitidos. Uma data qualquer dentro da janela é aceita como suposta validade, mesmo sem uma evidência de validade do produto.

**Impacto:** não basta proibir números novos: a IA pode produzir números falsos para a pergunta usando valores reais de outra entidade. `fontes` pode ser vazia. A conferência de classe só procura a classe depois do nome: “Classe C: Café 500g” escapa quando Café é A.

**Patch sugerido — contrato novo, requer mudanças coordenadas no prompt, parser e renderização:** trocar texto financeiro livre por referências a fatos calculados; renderizar as frases numéricas no app. Não adicionar apenas outra regex.

```diff
--- a/packages/cic_domain/lib/src/ia/guarda_aterramento.dart
+++ b/packages/cic_domain/lib/src/ia/guarda_aterramento.dart
@@
-  final Set<int> _numeros = {};
+  // Contrato proposto: cada fato associa entidade, campo, unidade e período.
+  final Map<String, String> fatosRenderizados = {};
+  // Ex.: estoque:p-700:disponivel -> "Café 500g: 5 unidades disponíveis."
```

```diff
--- a/supabase/functions/ia-consultor/index.ts
+++ b/supabase/functions/ia-consultor/index.ts
@@
-{"resposta": string, "tipo": "analise" | "fora_do_escopo", "periodo": string|null, "metricas": {nome: número},
- "fontes": [ids de produto citados], "alertas": [string], "dadosAusentes": [string]}
+{"tipo": "analise" | "fora_do_escopo", "fatos": [ids de fatos fornecidos],
+ "acao": "consultar_estoque" | "revisar_custos" | "conferir_reposicao" | "nenhuma"}
```

Esse desenho deve validar os IDs contra o snapshot, executar ações apenas como sugestões e usar textos fixos por ação. Até implementar o novo contrato, a mitigação estrita é exibir somente respostas determinísticas; não anunciar a trava atual como prova semântica de números.

## 2. Texto fora do escopo e produto inventado sem números são aceitos — alta

**Local:** `lib/services/ia_consultor.dart:98-107,241-243`; `packages/cic_domain/lib/src/ia/guarda_aterramento.dart:147-220`; `supabase/functions/ia-consultor/index.ts:46-58,316`.

**Cenário:** “Tell me a joke” não encontra as palavras portuguesas das regex e vai ao modelo. “Conte uma piada sobre minha loja” inclui `loja`, anulando a recusa local. Uma saída `tipo: analise`, texto “Era uma vez um dragão feliz.” e fontes vazias passa pela trava. “Reponha o Abacaxi Imperial.” também passa sem esse produto existir; só os IDs declarados são verificados, não os nomes livres.

**Patch sugerido — mitigação imediata, com perda consciente de flexibilidade:** toda intenção não reconhecida recebe orientação fixa até existir o contrato de ações/fatos do achado 1. Não confiar na autoclassificação do LLM.

```diff
--- a/lib/services/ia_consultor.dart
+++ b/lib/services/ia_consultor.dart
@@
     final direta = _objetiva(pergunta);
     if (direta != null) return controle.ehAtual(token) ? direta : null;
+    // Modo estrito temporário: retirar após adotar saída por fatos/ações.
+    return _local('Posso ajudar com estoque, vendas, validade, custos e reposição. '
+        'Diga qual desses assuntos você quer consultar.',
+        tipo: dom.TipoResposta.foraDoEscopo);
```

O restante do método precisa ser removido ou isolado por configuração durante essa mitigação para não ficar código inalcançável. Para manter perguntas abertas, adotar o contrato coordenado do achado 1. Inglês e erros de digitação devem resultar em pedido de esclarecimento ou normalização por aliases testados, não em liberdade irrestrita de texto.

## 3. Números junto de unidade e sinal Unicode escapam — alta

**Local:** `packages/cic_domain/lib/src/ia/guarda_aterramento.dart:140-142,184-193`.

**Cenário:** “Há 999kg disponíveis.” não gera ocorrência em `_reNumero`: o `k` impede o limite final. “Há −30 unidades.” usa sinal U+2212; a regex lê 30 positivo, que já é permitido. Números por extenso também não são tratados. O nome verdadeiro “Café 500g” explica por que simplesmente retirar a proteção de letras criaria falsos positivos em embalagens.

**Patch sugerido — complemento, não substitui vínculo semântico:** retirar nomes conhecidos antes da análise numérica e normalizar sinais. O nome tem de ser reconhecido integralmente e por limites, não qualquer substring.

```diff
--- a/packages/cic_domain/lib/src/ia/guarda_aterramento.dart
+++ b/packages/cic_domain/lib/src/ia/guarda_aterramento.dart
@@
-final _reNumero = RegExp(r'(?<![\w,])(-?)(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d+))?(?![\w%])');
+final _reNumero = RegExp(r'(?<![\w,])(-?)(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d+))?(?![\d,%])');
@@
-  var texto = r.resposta.replaceAll(' ', ' ');
+  var texto = r.resposta.replaceAll(' ', ' ').replaceAll('−', '-');
+  final nomes = ctx._nomes.values.toList()
+    ..sort((a, b) => b.length.compareTo(a.length));
+  for (final nome in nomes) {
+    texto = texto.replaceAll(RegExp(
+      '(?<!\\w)${RegExp.escape(nome)}(?!\\w)', caseSensitive: false), ' ');
+  }
```

Continuar rejeitando notações não suportadas em vez de tentar adivinhar seu valor. O patch não resolve números por extenso; o contrato estruturado do achado 1 resolve a origem dessas afirmações.

## 4. Número repetido pelo modelo conflita com a própria regra do servidor — média

**Local:** `supabase/functions/ia-consultor/index.ts:52-53`; `packages/cic_domain/lib/src/ia/guarda_aterramento.dart:178-193`.

**Cenário:** usuário pergunta se deve dar 90% de desconto; o prompt permite “não recomendo 90% de desconto”, mas o contexto não contém 90%, então a resposta é descartada. Ao contrário, “dê 100% de desconto” pode passar porque 100 está na lista fixa de percentuais, independentemente da pergunta. Colocar todos os números da pergunta na lista permitida agravaria a falha.

**Patch sugerido:** o modelo não deve repetir número sem fato calculado; a recusa usa referência textual.

```diff
--- a/supabase/functions/ia-consultor/index.ts
+++ b/supabase/functions/ia-consultor/index.ts
@@
-   Pode repetir um número dito pelo lojista só para recusá-lo (ex.: "não recomendo 90% de desconto").
+   Não repita números da pergunta que não constem dos fatos calculados.
+   Para recusar, diga "Não recomendo esse desconto" sem repetir o percentual.
```

É alinhamento do prompt, não garantia de cumprimento; deve ser combinado com o achado 1. O formato canônico `R$ 1.234,56` e NBSP já são reconhecidos pela trava. Não encontrei falha nesse formato específico; formatos monetários diferentes precisam ser rejeitados ou normalizados integralmente, nunca por prefixo parcial.

## 5. Intenções capturam pergunta errada e ignoram produto/período — alta

**Local:** `lib/services/ia_consultor.dart:37-41,70-87,187-224,251-274,300-334`.

**Cenários concretos:**

- “Quanto lucrei hoje?” chama `_ganhando()`, que fixa a janela de 30 dias e escreve “este mês”. `PeriodoAbc.mes` não é mês-calendário (`packages/cic_domain/lib/src/tempo/periodo.dart:48-52`).
- “Qual o lucro do café hoje?” cai em `_retorno` e informa lucro unitário pelo preço atual, não lucro das vendas de hoje.
- “O Leite está com poucas unidades?” lista todos os produtos baixos, sem limitar ao Leite.
- “Quanto preciso vender de café para cobrir custos?” encontra Café em `achados` e retorna saldo/preço antes de chegar ao bloco `cobrirCustos`.
- Com produto “Dia Feliz”, “vendas do dia” encontra o termo comum `dia` e devolve cadastro. “Sal” também casa com o início de “Salgadinho”; a regex só tem limite no início. Categoria participa do mesmo escore.
- “Qual meu luccro hoje?” não normaliza erro de digitação; pode chamar servidor em vez do cálculo. Não fazer correção aproximada de nomes/códigos sem confirmar o item.

**Patch sugerido — separar intenção de entidade; ajustes mínimos:**

```diff
--- a/lib/services/ia_consultor.dart
+++ b/lib/services/ia_consultor.dart
@@
-        if (RegExp(r'\b' + RegExp.escape(w)).hasMatch(nome)) pts += 2;
+        if (RegExp(r'\b' + RegExp.escape(w) + r'\b').hasMatch(nome)) pts += 2;
@@
-    if (achados.isNotEmpty) {
+    if (achados.isNotEmpty && !cobrirCustos &&
+        RegExp(r'\b(tem|tenho|saldo|estoque|preco)\b').hasMatch(t)) {
```

Esse ajuste evita alguns casos, mas perguntas de faturamento ainda precisam ser roteadas antes da busca de cadastro. Para lucro, propõe-se a mudança de assinatura abaixo e substituir os textos “este mês” por rótulo fiel ao período; consultas a lucro realizado por produto precisam usar os itens ABC do período, e não `p.lucroUnitario`.

```diff
--- a/lib/services/ia_consultor.dart
+++ b/lib/services/ia_consultor.dart
@@
-  dom.RespostaConsultor _ganhando() {
-    final abc = estado.curvaAbc(dom.PeriodoAbc.mes);
+  dom.RespostaConsultor _ganhando(dom.PeriodoAbc periodo) {
+    final abc = estado.curvaAbc(periodo);
@@
-      return _ganhando();
+      return _ganhando(_periodoDe(t));
```

Não descontar silenciosamente custos mensais inteiros de lucro diário: mostrar lucro bruto do período e custos mensais separadamente, ou declarar explicitamente um rateio aprovado. Definir aliases limitados de intenção (`lucro`, `luccro`, `profit`) fora dos nomes dos produtos, com esclarecimento para ambiguidades. Isso requer testes de comportamento, não só testes de regex.

## 6. Falha ao carregar vendas/custos vira dado zero ou antigo — alta

**Local:** `lib/state/app_state.dart:51,71-95,270-272`; `lib/services/ia_consultor.dart:187-205,246-248,331-343`.

**Cenário:** estoque carrega; vendas falham no primeiro acesso. `estoqueConfiavel` permanece true, vendas ficam vazias e a IA afirma que não há vendas ou que há produtos parados. Se custos falham depois de uma carga anterior, usa custos antigos sem sinalizar. Até respostas determinísticas ficam erradas; a trava do modelo não participa delas.

**Patch sugerido — conservador:** recusar análise enquanto houver falha das bases financeiras, preservando operações de estoque em melhoria posterior com dependências por intenção.

```diff
--- a/lib/services/ia_consultor.dart
+++ b/lib/services/ia_consultor.dart
@@
     if (!estado.estoqueConfiavel) {
       return _local('Não consegui ler o seu estoque agora, então não vou informar números que possam estar errados. Puxe a tela para atualizar e tente de novo.',
           tipo: dom.TipoResposta.indisponivel);
     }
+    if (estado.erros.containsKey('vendas') || estado.erros.containsKey('custos')) {
+      return _local('Não consegui atualizar vendas ou custos. Atualize a tela antes de analisar lucro, retorno ou reposição.',
+          tipo: dom.TipoResposta.indisponivel);
+    }
```

Também transportar completude e data por fonte no contexto. Não assumir que um histórico parcial é uma janela completa de 30 dias.

## 7. JSON sintaticamente válido interrompe fallback mesmo sem resposta útil — alta

**Local:** `supabase/functions/ia-consultor/index.ts:246-258,283-288,306-328`.

**Cenário:** primeiro provedor retorna `{}`, `null`, `{"resposta":"   "}`, `{"resposta":{},"tipo":"qualquer"}` ou texto que vira vazio depois de `semCampos`. `JSON.parse` aceita e a cadeia para. O app recebe vazio/502, ou `[object Object]` com tipo convertido para `analise`. Este último pode passar no aterramento. JSON parcial de verdade gera SyntaxError e segue para o próximo provedor: esse caso já está tratado. Corpo de entrada `null` também passa pelo parse e quebra ao acessar `entrada.pergunta` fora do try.

**Patch sugerido:** validar antes do `break`, incluindo o texto depois da limpeza; não converter tipo desconhecido em sucesso.

```diff
--- a/supabase/functions/ia-consultor/index.ts
+++ b/supabase/functions/ia-consultor/index.ts
@@
     entrada = JSON.parse(bruto);
+    if (!entrada || typeof entrada !== 'object' || Array.isArray(entrada)) {
+      return json(400, { erro: 'Esperado objeto JSON' });
+    }
@@
-        JSON.parse(textoIa); // fora do formato: tenta o próximo
+        const candidato = JSON.parse(textoIa);
+        if (!candidato || typeof candidato !== 'object' || Array.isArray(candidato) ||
+            typeof candidato.resposta !== 'string' ||
+            !['analise', 'fora_do_escopo'].includes(candidato.tipo) ||
+            !semCampos(candidato.resposta).trim()) {
+          throw new SyntaxError('Contrato inválido');
+        }
```

Validar também listas, métricas e limites de tamanho antes de selecionar o provedor. Em seguida, reutilizar o objeto validado na resposta final. A coerção atual de listas pode esconder campos errados em vez de rejeitar a resposta. Não truncar no meio de uma afirmação numérica; limitar geração e, se necessário, cortar somente em fronteira de frase ou rejeitar.

## 8. Erros de tipo escapam do fallback e deixam envio bloqueado — alta

**Local:** `packages/cic_domain/lib/src/ia/resposta_consultor.dart:61-78`; `packages/cic_domain/lib/src/ia/consultor_seguro.dart:208-240`; `lib/screens/inteligencia_screen.dart:99-115`.

**Cenário:** `periodo: 42` lança TypeError no cast, não FormatException. `metricas: {'x': double.infinity}` passa na validação `num` e quebra ao arredondar na trava. Esse objeto pode vir de teste/provedor adaptado; o servidor atual filtra métricas finitas e normaliza período, portanto não é o caminho habitual da Edge atual. Porém o contrato Dart promete tolerar resposta inválida e não tolera. Exceção inesperada na rede/parser/cálculo escapa de `ConsultorSeguro`, que captura apenas `ErroIa`. A tela não usa `finally` para liberar `_enviando`.

**Patch sugerido:**

```diff
--- a/packages/cic_domain/lib/src/ia/resposta_consultor.dart
+++ b/packages/cic_domain/lib/src/ia/resposta_consultor.dart
@@
-    if (metricas is! Map || metricas.values.any((v) => v is! num)) {
+    if (metricas is! Map || metricas.keys.any((k) => k is! String) ||
+        metricas.values.any((v) => v is! num || !v.isFinite)) {
@@
     final tipo = campo<String>('tipo');
+    if (json['periodo'] != null && json['periodo'] is! String) {
+      throw const FormatException('Período inválido');
+    }
```

```diff
--- a/packages/cic_domain/lib/src/ia/consultor_seguro.dart
+++ b/packages/cic_domain/lib/src/ia/consultor_seguro.dart
@@
       return fallback.comAviso(
         '${e.mensagemUsuario} Mostrando só os dados calculados.',
         origem: OrigemResposta.fallbackSeguro,
       );
+    } catch (_) {
+      return fallback.comAviso('Não foi possível concluir a análise. Mostrando os dados calculados.',
+          origem: OrigemResposta.fallbackSeguro);
     }
```

```diff
--- a/lib/screens/inteligencia_screen.dart
+++ b/lib/screens/inteligencia_screen.dart
@@
-    final r = await _consultor.perguntar(t);
-    if (!mounted) return;
-    setState(() {
-      _enviando = false;
-      if (r != null) _msgs.add(_Msg(deUsuario: false, texto: r.resposta, origem: r.origem, aviso: r.aviso));
-    });
+    try {
+      final r = await _consultor.perguntar(t);
+      if (mounted && r != null) setState(() => _msgs.add(
+        _Msg(deUsuario: false, texto: r.resposta, origem: r.origem, aviso: r.aviso)));
+    } catch (_) {
+      if (mounted) aviso(context, 'Não consegui concluir a consulta. Tente novamente.', erro: true);
+    } finally {
+      if (mounted) setState(() => _enviando = false);
+    }
```

Tratar a fronteira do chat não dispensa corrigir a causa nem registrar um código de erro sanitizado.

## 9. Prazo de 18 segundos não é total; provedores finais podem nunca ser tentados — alta

**Local:** `supabase/functions/ia-consultor/index.ts:271-295`; `lib/services/ia_consultor.dart:418-425`; `packages/cic_domain/lib/src/ia/erros_ia.dart:111-123`.

**Cenários:** duas tentativas locais de 18 segundos, mais backoff de 800 ms, somam aproximadamente 36,8 segundos. `Retry-After: 60` permite esperar um minuto adicional. O limite de 15 segundos do servidor é compartilhado corretamente entre modelos e provedores, não 15 segundos para cada um; porém começa após ler/processar o corpo. Gemini gastando 7 s e Groq 7 s deixam menos de 1,5 s: Ollama/OpenRouter são pulados. `Future.timeout` não cancela o HTTP subjacente, podendo duplicar consumo ao retentar.

**Patch sugerido — contenção simples de prazo:** uma tentativa no app, que já recebe fallback entre provedores do servidor, e divisão de tempo entre os provedores ainda não tentados.

```diff
--- a/lib/services/ia_consultor.dart
+++ b/lib/services/ia_consultor.dart
@@
-      politica: dom.PoliticaRetentativa(maxTentativas: 2, timeoutPorTentativa: Duration(seconds: 18)),
+      politica: dom.PoliticaRetentativa(maxTentativas: 1, timeoutPorTentativa: Duration(seconds: 18)),
--- a/supabase/functions/ia-consultor/index.ts
+++ b/supabase/functions/ia-consultor/index.ts
@@
-    const fatia = idx < lista.length - 1 ? Math.min(restante, 7_000) : restante;
+    const fatia = Math.min(restante, Math.max(1_000, Math.floor(restante / (lista.length - idx))));
```

Isso não garante que todo provedor responderá, mas evita reservar quase todo tempo aos primeiros. Fechar/cancelar um cliente HTTP exclusivo da consulta em `finally` é necessário para abortar trabalho restante; não fechar o cliente compartilhado da aplicação. Se mantiver retentativas, implementar deadline global e limitar `Retry-After` ao saldo de tempo, com fallback imediato quando não couber.

## 10. Previsão divide por zero e transforma falta de vendas em falsa tranquilidade — alta/média

**Local:** `packages/cic_domain/lib/src/estoque/previsao.dart:86-109`; `lib/services/ia_consultor.dart:119-142,166-180`.

**Cenário A (média, API pública do domínio):** `calcular(abc, diasJanela: 0)` com item não arquivado causa falha em `.round()` de infinito/NaN. Janela negativa e horizonte negativo geram saídas sem sentido. O app chama com 30 atualmente, portanto não é falha acionável pela pergunta comum.

```diff
--- a/packages/cic_domain/lib/src/estoque/previsao.dart
+++ b/packages/cic_domain/lib/src/estoque/previsao.dart
@@
   ResultadoPrevisao calcular(ResultadoCurvaAbc abc, {int diasJanela = 30}) {
+    if (diasJanela <= 0 || diasAlvo <= 0 || diasCriticos < 0 || diasCriticos > diasAlvo) {
+      throw ArgumentError('Janela e horizonte devem ser positivos; limiar crítico deve estar no horizonte');
+    }
```

**Cenário B (alta, fluxo normal):** item com saldo zero e nenhuma venda recebe `ok`; `_atencao` só inclui zerados classificados como ruptura e filtra baixos com quantidade > 0. Assim diz “nenhum produto zerado” mesmo havendo item zerado. Uma loja nova sem histórico recebe “nenhum produto precisa de reposição”, embora faltem dados para estimar demanda.

```diff
--- a/lib/services/ia_consultor.dart
+++ b/lib/services/ia_consultor.dart
@@
-      return _local('Nada urgente agora: nenhum produto zerado, vencendo, acabando ou abaixo do mínimo.');
+      final zerados = estado.estoque.where((p) => p.quantidade <= 0).toList();
+      if (zerados.isNotEmpty) return _local('Há produtos sem estoque e sem histórico suficiente para estimar reposição. Confira o estoque.');
+      return _local('Nenhum alerta foi identificado nos dados disponíveis.');
@@
     if (comprar.isEmpty) {
+      if (prev.itens.isEmpty || prev.itens.every((i) => i.vendidosNoPeriodo == 0)) {
+        return _local('Não há vendas suficientes para estimar uma lista de compras. Confira o estoque e registre as vendas.');
+      }
```

Esse guard também deve considerar itens `semDados`, sem concluir que não precisam de compra. Distinguir “sem movimento confirmado” de “falha de leitura”, conforme achado 6.

## 11. Validade usa duração de horas do aparelho em vez de dia civil da loja — média

**Local:** `lib/data/models.dart:88-89`; `lib/services/ia_consultor.dart:122-129,280-287`.

**Cenário:** produto vence amanhã à meia-noite, consulta hoje ao meio-dia: diferença de 12 horas vira 0 dias. Uma validade daqui a oito datas civis pode aparecer como sete e entrar antecipadamente no alerta de sete dias. Fuso do dispositivo diferente do da loja e mudanças de offset agravam a discrepância. Para uma data SQL à meia-noite, validade de ontem normalmente continua negativa; não há evidência de que esse caso simples seja mostrado como não vencido. O domínio já dispõe de `FusoLoja`, mas essa propriedade não o usa.

**Patch sugerido — helper no consultor, seguido da troca de todas as leituras de `p.diasParaVencer` nesse serviço:**

```diff
--- a/lib/services/ia_consultor.dart
+++ b/lib/services/ia_consultor.dart
@@
   final controle = dom.ControleRequisicoes();
+  int? _diasParaVencer(Produto p) {
+    final validade = p.dataValidade;
+    if (validade == null) return null;
+    final hoje = estado.fusoLoja.dataCivilDe(DateTime.now().toUtc());
+    return DateTime.utc(validade.year, validade.month, validade.day)
+        .difference(DateTime.utc(hoje.ano, hoje.mes, hoje.dia)).inDays;
+  }
```

Injetar relógio para testes determinísticos e capturar “hoje” uma única vez por resposta. No guard, validar existência de dia/mês antes de `DataCivil`: `DateTime.utc` normaliza datas impossíveis; `31/02/2026` pode ser comparada como março em vez de rejeitada. Mesmo data válida dentro da janela não comprova a validade de um produto (achado 1).

```diff
--- a/packages/cic_domain/lib/src/ia/guarda_aterramento.dart
+++ b/packages/cic_domain/lib/src/ia/guarda_aterramento.dart
@@
     final d = DataCivil(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
+    final normalizada = DateTime.utc(d.ano, d.mes, d.dia);
+    if (normalizada.year != d.ano || normalizada.month != d.mes || normalizada.day != d.dia) {
+      violacoes.add('data inexistente: ${m[0]}');
+      return ' ';
+    }
```

## 12. Atenção prioriza ruptura acima de vencidos e arredonda venda baixa a zero — alta/média

**Local:** `lib/services/ia_consultor.dart:93-95,110-139`.

**Cenário:** seis itens em ruptura preenchem o limite antes de percorrer vencidos. Um produto vencido é omitido da lista de urgências. Além disso, uma venda em 30 dias dá média 0,03; `_un` usa uma casa e escreve “vendia 0 un/dia”, mas recomenda repor. São respostas locais, sem validação de aterramento.

**Patch sugerido:** mover o bloco de vencidos antes de ruptura e preservar os centésimos usados no domínio.

```diff
--- a/lib/services/ia_consultor.dart
+++ b/lib/services/ia_consultor.dart
@@
-    final s = v.toStringAsFixed(1).replaceAll('.', ',');
-    return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
+    return v.toStringAsFixed(2).replaceAll('.', ',')
+        .replaceFirst(RegExp(r',00$'), '')
+        .replaceFirstMapped(RegExp(r'(,\d)0$'), (m) => m[1]!);
@@
-    for (final i in prev.de(dom.SituacaoPrevisao.ruptura)) {
-      add(i.produtoId, '- ${i.nome}: ZERADO e vendia ${_un(i.mediaDiaria)} un/dia. Reponha já (${i.reposicaoSugerida} un para ${prev.diasAlvo} dias).');
-    }
     for (final p in estado.estoque.where((p) => (p.diasParaVencer ?? 9999) < 0)) {
       add(p.codigo, '- ${p.nome}: VENCIDO (${p.quantidade} un). Retire do ponto de venda.');
     }
+    for (final i in prev.de(dom.SituacaoPrevisao.ruptura)) {
+      add(i.produtoId, '- ${i.nome}: ZERADO e vendia ${_un(i.mediaDiaria)} un/dia. Reponha já (${i.reposicaoSugerida} un para ${prev.diasAlvo} dias).');
+    }
```

## Verificações que não justificam alegação de falha

- O orçamento de provedores é compartilhado; não há evidência de que o rodízio de seis combinações some seis timeouts completos.
- JSON truncado é capturado pelo parse e tenta outro provedor. O problema é JSON válido sem contrato útil.
- `RespostaConsultor.daIa` rejeita texto vazio e tipo desconhecido quando chamados diretamente; o servidor é que normaliza tipos desconhecidos e interrompe cedo a cadeia.
- `R$ 1.234,56`, valores negativos ASCII e espaço não separável têm tratamento explícito; testes de controle devem preservá-lo.
- Estoque totalmente vazio gera previsões com lista vazia sem divisão por zero. A divisão por zero exige janela inválida e pelo menos um item processado.
- Não foram testadas cotas, chaves, modelos ou políticas implantadas. O rate limit em memória e o parse de JWT não são prova de autenticação do gateway.

## Testes e ordem de correção

O arquivo `testes_ia_propostos.dart` foi preparado para ser copiado para `packages/cic_domain/test/auditoria_adversarial_test.dart` na release. Usa a fixture existente e o helper `calcularFixture`. Rodar a partir de `packages/cic_domain` com `dart test test/auditoria_adversarial_test.dart`. Asserções exprimem o comportamento desejado; várias devem falhar antes das correções. Não confundir ausência de execução local com aprovação.

Priorizar: vínculo de fatos/escopo (1–3), recuperação e prazo (7–9), completude/roteamento (5–6), previsão e validade (10–12). Testes de interface adicionais devem simular: falha só em vendas; erro inesperado do consultor com botão Enviar liberado; saldo zero sem vendas; seis rupturas mais um vencido; lucro hoje versus 30 dias; produto com nome comum; pergunta em inglês e erro de digitação com esclarecimento. Testes da Edge devem usar respostas falsas em memória, nunca chaves reais: primeiro `{}`, depois JSON válido; entrada `null`; dois provedores lentos; limpeza que esvazia texto; limite 429.
