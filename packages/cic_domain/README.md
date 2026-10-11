# cic_domain — camada de domínio portátil do APP-CIC

Dart puro (sem Flutter, sem UI, sem estado global). Implementa os itens 2, 3, 4 e 8 de
`APP_CIC_PROMPT_UPGRADE.md` para a frente mobile: estoque, Curva ABC `abc-v1` e guarda contra
respostas de IA não aterradas. O app Flutter deve depender deste pacote; a Web deve passar
pelas mesmas fixtures (`fixtures/abc-v1/*.json`).

```bash
dart pub get
dart analyze
dart test
```

Estado: `dart analyze` sem avisos e 56 testes passando (Dart 3.13.5, Windows). Ainda não há
projeto Flutter, nem builds Android/iOS, nem integração com o backend `server.ts`.

## Estrutura

| Arquivo | Conteúdo |
|---|---|
| `lib/src/tempo/fuso_loja.dart` | `Relogio` injetável, `DataCivil`, `FusoLoja` (base IANA via `package:timezone`; padrão `America/Sao_Paulo`) |
| `lib/src/tempo/periodo.dart` | `PeriodoAbc` e `JanelaPeriodo` (limites civis no fuso da loja) |
| `lib/src/estoque/estoque.dart` | `Produto`, `Lote`, `SnapshotEstoque`, `SaldoProduto`, `ResumoEstoque`, `EstoqueService` |
| `lib/src/vendas/eventos.dart` | `Venda`, `Devolucao`, `MovimentacaoEstoque`, `MovimentoCaixa` |
| `lib/src/vendas/apuracao.dart` | Converte eventos em fatos únicos por produto (deduplicação, devoluções, rateio) |
| `lib/src/abc/curva_abc.dart` | `CurvaAbcService`, `ResultadoCurvaAbc`, `ItemCurvaAbc`, `AlertaRuptura`, `conciliarAlertas` |
| `lib/src/ia/*` | Contrato `RespostaConsultor` (`ia-v1`), `ErroIa` + `PoliticaRetentativa`, `verificarAterramento`, `ConsultorSeguro`, `RespostasDeterministicas`, `ConsultaIa` |
| `lib/src/dinheiro.dart` | Centavos, formatação pt-BR, rateio com soma exata |

## Contrato abc-v1 (resumo)

**Dinheiro:** sempre centavos `int`. Percentuais existem só para exibição; a classe é
decidida por multiplicação cruzada (`acumuladoAntes × 100 < 80 × totalPositivo`).

**Períodos** (fuso da loja, nunca do aparelho; instantes em UTC; inclusão
`inicio <= t <= agora`, precisão de ms; futuro sempre excluído):

| Período | Início |
|---|---|
| `hoje` | 00:00 local de hoje |
| `seteDias` | 00:00 local de hoje − 6 (7 datas civis) |
| `mes` | 00:00 local de hoje − 29 (30 datas civis, não mês-calendário) |
| `todos` | sem limite inferior |
| `projetado` | sem janela: estoque disponível × preço atual |

**Eventos:**
- A venda concluída conta.
- A baixa de estoque com `eventoOrigemId` de uma venda não conta de novo.
- A saída comercial independente conta. Sem preço histórico, conta só a quantidade e entra o problema `precoHistoricoAusente`.
- Perda, consumo, ajuste, transferência, entrada, sangria e reforço não geram receita.
- Venda cancelada não gera faturamento.
- Devolução:
  - O estorno entra na data da devolução, vinculado a `vendaId` e `itemId`.
  - Sem valor informado, o estorno é proporcional e acumulado, então devoluções parciais fecham exatamente com o líquido do item.
  - A quantidade é limitada ao que foi vendido (`devolucaoAcimaDoVendido`).
  - Devolução de venda cancelada é ignorada (`devolucaoDeVendaCancelada`).
- Evento com ID repetido conta uma vez (`eventoDuplicado`).

**Valores:**
- Receita líquida = preço histórico × quantidade − desconto do item − rateio do desconto do pedido. O rateio usa o maior resto, com empate pelo índice.
- Frete e impostos destacados ficam fora da receita de produto.
- CMV vem do custo histórico do item. Sem ele, custo, lucro e margem ficam `null` e entra o problema `custoHistoricoAusente`. O preço e o custo atuais nunca entram no realizado.
- Margem bruta = lucro ÷ receita × 100. Markup = lucro ÷ custo × 100. Os dois são campos separados.

**Ordenação e classes:**
- Ordem do realizado: receita líquida decrescente, depois quantidade líquida decrescente, depois `produtoId` crescente.
- Ordem do projetado: potencial decrescente, depois `produtoId` crescente.
- Só valores positivos entram no denominador. Produto com valor zero ou negativo fica C, e os negativos aparecem em `totalNegativoCentavos`.
- A classe vem do acumulado antes do item: menor que 80% é A, menor que 95% é B, o resto é C. Total positivo zero deixa todos em C.
- Produtos ativos sem venda entram como C. Arquivados ou excluídos do cadastro entram se venderam, com o nome histórico.

**Ruptura:**
- Classe A com estoque disponível conhecido ≤ 5 gera alerta.
  - O ID é estável: `ruptura:<produtoId>:<periodo>`.
  - No projetado, o alerta é marcado como `teorico`.
- Estoque desconhecido gera aviso de dado ausente e não gera alerta.
- Estoque negativo gera o problema `estoqueNegativo` e também o alerta.
- `conciliarAlertas` mantém o mesmo ID, preserva "lido" e resolve o alerta quando a condição some. Lido não resolve.

## IA sem alucinação

1. Perguntas objetivas (estoque, faturamento, mais vendido, ABC, produtos acabando) são respondidas por `RespostasDeterministicas`. Elas funcionam com o Gemini fora do ar.
2. Análises abertas usam `ConsultorSeguro.responder`:
   - Retentativas limitadas: 408/504/429/502/503 e timeout, até 3 tentativas com backoff. Erros 4xx e JSON inválido não são retentados.
   - O schema `ia-v1` é validado.
   - `verificarAterramento` rejeita:
     - valor em R$, número, percentual, data ou métrica fora do que os serviços calcularam;
     - `fontes` com ID inexistente;
     - produto citado com classe diferente da calculada;
     - `snapshotVersion` antigo;
     - resposta objetiva com mais de 2 frases ou lista com mais de 5 itens.
   - Em qualquer falha, devolve a resposta calculada com `origem: fallbackSeguro` e um `aviso` visível. Erro nunca aparece como sucesso.
3. `ConsultaIa` não envia `tenantId`: o servidor usa a loja autenticada. Os números enviados são contexto, não fonte financeira autoritativa.
4. `ControleRequisicoes` descarta respostas que chegam fora de ordem.

A guarda é estrita de propósito. Um número legítimo que a guarda não conhece também cai no fallback, que é o resultado seguro. Se isso acontecer, inclua o número no `ContextoAterramento` em vez de afrouxar a regra.

## Pendências

- A Web (`src/`, `server.ts`) ainda não passa por estas fixtures. O tipo `PeriodicidadeFiltro` tem `'mes' | '30dias'`, e `CurvaABCItem` usa potencial em vez de realizado. É preciso alinhar e registrar as mudanças.
- O roteador de intenção do chat e os endpoints `/api/ia/chat` e `/api/ia/analisar` precisam ser ligados a este contrato no backend.
- Quantidades são unidades inteiras. Produtos fracionados (kg, L) precisam de uma extensão do contrato.
- `lib/contracts/abc_contract.dart` e `lib/services/ai_grounding_guard.dart` são o esboço inicial e foram substituídos por `lib/src/`.
  - O esboço usa `double` em percentuais, não aplica fuso, envia `tenantId` do cliente e só detecta contradição pela frase literal "X é C".
  - Remova os dois arquivos quando confirmar que ninguém os importa.
- Projeto Flutter, builds Android/iOS e sincronização offline ainda não existem.
