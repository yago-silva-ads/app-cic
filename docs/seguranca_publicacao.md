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
   - `BRAVE_SEARCH_API_KEY` (opcional; sem ela a pesquisa de mercado avisa que está desligada).
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
