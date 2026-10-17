# Estudo de concorrentes com REA — APP-CIC

Data: 17/10/2026. Ferramenta: REA 6.5.0 (`rea analyze-javascript-application`), análise **estática** do
JavaScript público que qualquer navegador recebe ao abrir a página. Nada foi executado, nenhum login foi
usado e nenhum código de terceiros foi copiado para o APP-CIC: o objetivo é entender **o que** os
concorrentes oferecem, não **como** está escrito.

## Alvos

| App | O que é | Artefato analisado | Resultado do REA |
|---|---|---|---|
| Kyte (web.kyteapp.com) | PDV + estoque para pequeno comércio, brasileiro, mobile-first — o mais parecido com o APP-CIC | `main.1a5e6e5e.js` (4,1 MB, webpack) | 921 módulos, 24 endpoints, 15 usos de armazenamento, 1 worker |
| Loyverse (r.loyverse.com) | PDV gratuito global | `login.bundle.js` (0,9 MB, AngularJS) | só o fluxo de login/cadastro; pouco útil para funcionalidades |

## Evidências (Kyte)

Endpoints e armazenamentos encontrados pelo REA (`endpoint`/`storage` no grafo da aplicação):

- Estoque em lote e transações: `/product/batch`, `/product/stocks`, `/product/product-transaction`,
  `/category/category-transaction`.
- Conta do cliente (fiado): `/customer`, `/customer/account`, `/customer/account-cancel`.
- Assistente de IA com contexto e **histórico de conversas**: `/kyte-ai-api/user-context`,
  `/create-conversation-session`, `/list-conversation-sessions`, `/conversation-session`,
  `/remove-conversation-session`.
- Liga/desliga de funcionalidades sem publicar app: Firebase Remote Config (`active_config`,
  `throttle_metadata`, IndexedDB `firebase_remote_config`).
- Trabalho pesado fora da tela: `new Worker(...)`.
- Preferências locais: `productViewType`, idioma (`i18nextLngLabel`).

Frequência de temas no bundle (contagem de termos, indicativa):

| Tema | Kyte | APP-CIC |
|---|---:|---:|
| Catálogo / loja online | 1030 | 14 |
| Pedidos / delivery | 636 | 6 |
| Assinatura / planos | 564 | 0 |
| Variações (tamanho/cor) | 476 | 0 |
| Cupom / impressora | 469 | 28 |
| Fiado / conta do cliente | 403 | 0 |
| Relatórios | 298 | 32 |
| Multiusuário / permissões | 240 | 2 |
| Comprovante por WhatsApp | 135 | 6 |
| Código de barras | 85 | 66 |
| Modo offline | 78 | 0 |
| Pix | 48 | 38 |

## Onde o APP-CIC já está à frente

- Leitura de NF-e (XML) para dar entrada no estoque.
- Logística reversa (devolução, avaria, vencimento, recall) registrada no histórico.
- Análise de mercado com piso de margem e IA com aterramento por produto.
- Alertas de validade e Curva ABC.

## Lacunas, em ordem de prioridade para o teste de campo

1. **Fiado / conta do cliente** — no mercadinho de bairro é rotina diária; o Kyte tem endpoints só para
   isso. Sugestão: tabela `clientes` + `lancamentos_fiado` (RLS por empresa), venda no PDV com forma
   "fiado", extrato e lembrete de cobrança pelo WhatsApp.
2. **Comprovante e cobrança pelo WhatsApp** — link `wa.me` com o resumo da venda ou do fiado; custo zero.
3. **Multiusuário com permissões** — dono x caixa (o caixa não vê custo, margem nem conta bancária).
4. **Liga/desliga de funcionalidades** — uma tabela `config_recursos` lida no início do app permite
   liberar recursos por loja durante o teste de campo sem publicar versão nova.
5. **Variações de produto** (tamanho/cor/sabor) com estoque por variação.
6. **Modo offline no PDV** — fila local de vendas sincronizada quando a internet voltar.
7. **Catálogo online com pedido pelo WhatsApp** — página pública por loja; casa com a automação do
   LeadForge (o lojista recebe o app e, se quiser, o site).
8. **Histórico de conversas da IA** — guardar as perguntas do lojista por sessão.

## Como repetir

```bash
npm install --global rea-agents
mkdir kyte && curl -sL -o kyte/main.js https://web.kyteapp.com/static/js/<arquivo-atual>.js
rea analyze-javascript-application "$(pwd)/kyte" --format json > kyte.rea.json
```
O nome do arquivo muda a cada versão do Kyte: pegue o `src` do `<script>` em https://web.kyteapp.com/.
