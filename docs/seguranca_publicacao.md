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
   - `GEMINI_API_KEY` (primário da pesquisa de mercado com busca Google; pode reutilizar o secret do `ia-consultor`).
   - `GEMINI_MODEL` (opcional; padrão da pesquisa: `gemini-2.5-flash`; precisa suportar `google_search`).
   - `BRAVE_SEARCH_API_KEY` (opcional, fallback quando Gemini falhar, estiver sem cota ou não trouxer ofertas com fontes).
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

O primário chama `generateContent` com `tools: [{google_search: {}}]`. Só aceita ofertas do
primeiro candidato cujo preço em R$ aparece em `groundingSupports[].segment.text`, ligado a
um `groundingChunks[].web.uri` HTTPS. Trechos sem fonte, links apenas no texto, credenciais na URL,
índices inválidos e trechos ambíguos com vários preços/fontes são descartados. O segmento precisa
existir na resposta; offsets, quando presentes, são conferidos como bytes UTF-8.
Deduplicação por URL e máximo de oito ofertas continuam válidos. Grounding não é garantia de estoque,
produto exato ou preço atualizado no checkout: o lojista deve conferir código, unidade, frete e oferta.

A cadeia faz no máximo uma chamada por provedor configurado. Falha de rede, HTTP, JSON ou ausência
de ofertas utilizáveis aciona Brave, se configurado. Não há fallback para preços sem fonte nem para
conhecimento interno do modelo. Timeout: 15 s Gemini e 8 s Brave. Não são enviados custo, margem,
preço interno ou dados da conta, apenas nome/código do produto.

**Não é busca ilimitada.** Preservados autenticação, CORS `ALLOWED_ORIGINS` e reserva de quatro
consultas por minuto via `reservar_cota_ia` (com fallback local já existente quando a RPC falha).
Esse fallback não equivale a limite global garantido se a RPC estiver indisponível.

Em 17/10/2026, a [tabela oficial Gemini](https://ai.google.dev/gemini-api/docs/pricing) informa
grounding gratuito de até 500 requisições/dia no plano gratuito do 2.5 Flash, compartilhado com
Flash-Lite. Cotas e disponibilidade dependem da conta/modelo e podem mudar; a chave compartilhada
também atende o assistente. Esta alteração não habilita faturamento nem garante custo zero numa
conta já faturada: conferir plano e limites antes de publicar. Brave também depende do plano da conta.

Google Custom Search JSON API **não foi implementado**: a
[documentação oficial](https://developers.google.com/custom-search/v1/overview) informa fechamento
para novos clientes e descontinuação em 01/01/2027. Não é necessário cadastrar `GOOGLE_CSE_KEY`
ou `GOOGLE_CSE_CX` para esta versão.

Antes do deploy, testar com uma conta autorizada, confirmar suporte do modelo a `google_search`,
permissões/termos de atribuição do Google e a exibição de fontes/sugestões exigida pelo provedor.
Os testes com fixtures não comprovam essas condições nem a disponibilidade real do serviço.
Nenhuma chave vai para Flutter, logs ou payload de resposta. Esta entrega não publicou a função.
