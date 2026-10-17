# Segurança e criptografia — o que publicar e em que ordem

## Camadas que o APP-CIC tem

| Camada | Onde |
|---|---|
| Isolamento por loja (RLS, `empresa_id = auth.uid()`) | migrations `rls_*`, `migracao_v3_*` |
| Funções do servidor só para lojista logado (token conferido no Supabase Auth) | `ia-consultor`, `analise-mercado` |
| Limite de uso por minuto, no banco (não zera em reinício) | `limite_ia.sql` + RPC `reservar_cota_ia` |
| CORS só para as origens do app (`ALLOWED_ORIGINS`) | as duas Edge Functions |
| Só links HTTPS nas fontes de preço | `analise-mercado` + `inteligencia_screen.dart` |
| **Criptografia em repouso** de documento, telefone, e-mail, Pix e dados bancários (AES-256, chave no Vault) | `criptografia_conta.sql` + `repository.dart` |
| CSP e build de produção | `web/` + Vercel |
| Transporte cifrado (HTTPS/TLS) e disco cifrado | Vercel e Supabase (padrão das plataformas) |

## Ordem de publicação

1. **Secrets das funções** (Supabase → Edge Functions → Secrets):
   - `ALLOWED_ORIGINS` = endereço de produção do app, o alias de preview da Vercel e
     `http://localhost:8080`, separados por vírgula. **Sem isso o navegador bloqueia o app** depois do passo 3.
   - `GROQ_API_KEY` (primário: `openai/gpt-oss-120b` com `browser_search`; fallback `openai/gpt-oss-20b`).
   - `GROQ_API_KEY_2` (opcional; segunda chave de reserva, tentada antes de trocar o modelo Groq).
   - `GEMINI_API_KEY` (fallback com grounding Google; pode reutilizar o secret do `ia-consultor`).
   - `GEMINI_MODEL` (opcional; primeiro da cadeia Gemini, seguido dos quatro modelos de reserva definidos em `busca.ts`; precisa suportar `google_search`).
   - `BRAVE_SEARCH_API_KEY` (opcional, último fallback quando os anteriores não trouxerem ofertas utilizáveis).
   - Sem nenhuma dessas chaves, a pesquisa retorna ofertas vazias e um aviso de configuração.
2. **SQL Editor**, nesta ordem: `limite_ia.sql` (se ainda não aplicado), `migracao_teste_campo.sql`,
   `migracao_logistica_reversa.sql`, `criptografia_conta.sql`.
   Conferência da criptografia (deve dar 0):
   `SELECT count(*) FROM public.contas_estabelecimento WHERE dados ?| private.campos_sensiveis_conta();`
3. **Publicar as funções** `ia-consultor` e `analise-mercado`.
4. **Publicar o app.** O app novo também funciona antes do passo 2: se as RPCs da conta ainda não
   existirem, ele usa a tabela como antes.

## Testes

- Domínio: `cd packages/cic_domain && dart test`
- Preço da pesquisa de mercado: `deno test supabase/functions/analise-mercado/teste/`
- IA (provedores falsos): `npx esbuild supabase/functions/ia-consultor/index.ts --format=esm --outfile=supabase/functions/ia-consultor/teste/ia_check.mjs && node supabase/functions/ia-consultor/teste/edge_test.mjs`
- Criptografia (Postgres em memória): ver o cabeçalho de `supabase/teste/criptografia_conta.test.mjs`.

## Pesquisa de mercado: fontes, custos e limites

Ordem: **Groq → cadeia Gemini → Brave**, apenas quando as respectivas chaves existem.
Groq usa `chat/completions` com `tools: [{type: "browser_search"}]` e `tool_choice: "required"`.
Os únicos preços aceitos vêm de registros estruturados dentro de
`choices[0].message.executed_tools[]`: `search_results.results[]`, `output` ou `browser_results`.
Cada registro precisa de URL HTTPS própria e preço em R$ no seu `title`/`content`/`text`.
Preços divergentes no mesmo registro são descartados; o mesmo preço repetido no título e conteúdo
conta uma vez. Fonte é o hostname da URL. **Nunca é lido `message.content`**, o texto final do modelo.
Output serializado só é aceito se for JSON com registros estruturados; prosa e HTML não são interpretados.
Os dois formatos são fixtures de contrato defensivo, não capturas de uma consulta real desta conta:
é necessário conferir o formato efetivamente retornado antes de anunciar a busca como validada.

`groq/compound-mini` e `groq/compound` não são usados: a
[documentação Groq](https://console.groq.com/docs/deprecations) informa desativação em 21/09/2026.
Alternativa usada: [browser search nos modelos GPT OSS](https://console.groq.com/docs/tool-use/built-in-tools/browser-search).

Gemini chama `generateContent` com `tools: [{google_search: {}}]`. Só aceita ofertas do
primeiro candidato cujo preço em R$ aparece em `groundingSupports[].segment.text`, ligado a
um `groundingChunks[].web.uri` HTTPS. Trechos sem fonte, links apenas no texto, credenciais na URL,
índices inválidos e trechos ambíguos com vários preços/fontes são descartados. O segmento precisa
existir na resposta; offsets, quando presentes, são conferidos como bytes UTF-8.
Deduplicação por URL e máximo de oito ofertas continuam válidos. Grounding não é garantia de estoque,
produto exato ou preço atualizado no checkout: o lojista deve conferir código, unidade, frete e oferta.

A cadeia faz no máximo quatro chamadas Groq (dois modelos × até duas chaves distintas),
até cinco Gemini (modelo configurado e quatro reservas, sem duplicatas) e uma Brave.
Falha de rede, HTTP, JSON ou ausência de ofertas utilizáveis aciona a próxima tentativa.
Para na primeira resposta com ofertas utilizáveis. Não há fallback para preços sem fonte nem para
conhecimento interno do modelo. Timeout por tentativa: 15 s Groq/Gemini e 8 s Brave; em falhas
sucessivas, a latência pode se somar e precisa ser conferida no teste do celular. Não são enviados custo, margem,
preço interno ou dados da conta, apenas nome/código do produto.

**Não é busca ilimitada.** Preservados autenticação, CORS `ALLOWED_ORIGINS` e reserva de quatro
consultas por minuto via `reservar_cota_ia` (com fallback local já existente quando a RPC falha).
Esse fallback não equivale a limite global garantido se a RPC estiver indisponível.

Na validação de produção informada pelo responsável em 17/10/2026, Gemini 2.5 Flash retornou 404
e os modelos de reserva retornaram 429 `RESOURCE_EXHAUSTED` com grounding. Portanto não assumir
cota de busca por existir uma chave de IA. Cotas e disponibilidade dependem da conta/modelo e
podem mudar; as chaves compartilhadas também atendem o assistente. Esta alteração não habilita
faturamento nem garante gratuidade numa conta faturada: conferir acesso, plano e limites de Groq,
Gemini e Brave antes de publicar. Uma segunda chave não aumenta necessariamente a cota da organização.

Em falhas totais, `diagnostico` retorna somente provedor/modelo, HTTP e status de uma lista permitida;
exceções retornam categoria controlada, nunca `message`, headers, URL da requisição, chave ou produto.

Google Custom Search JSON API **não foi implementado**: a
[documentação oficial](https://developers.google.com/custom-search/v1/overview) informa fechamento
para novos clientes e descontinuação em 01/01/2027. Não é necessário cadastrar `GOOGLE_CSE_KEY`
ou `GOOGLE_CSE_CX` para esta versão.

Antes do deploy, testar com uma conta autorizada, confirmar suporte aos tools e o formato bruto
do browser search, sem registrar credenciais ou dados de clientes. Conferir também
permissões/termos de atribuição do Google e a exibição de fontes/sugestões exigida pelo provedor.
Os testes com fixtures não comprovam essas condições nem a disponibilidade real do serviço.
Nenhuma chave vai para Flutter, logs ou payload de resposta. Esta entrega não publicou a função.
