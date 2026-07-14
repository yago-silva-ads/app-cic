-- ============================================================
-- App-CIC: Migração Multi-Tenant com Row Level Security (RLS)
-- ============================================================
-- INSTRUÇÕES:
--   1. Abra o Supabase Dashboard → SQL Editor
--   2. Cole este script INTEIRO
--   3. Clique em "Run"
--   4. Verifique no Table Editor se as colunas empresa_id apareceram
-- ============================================================

-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 1: Adicionar coluna empresa_id nas tabelas       ║
-- ╚══════════════════════════════════════════════════════════╝

-- Tabela: produtos
-- O DEFAULT auth.uid() garante que mesmo sem enviar pelo app,
-- o banco preenche automaticamente com o ID do usuário logado.
ALTER TABLE produtos
  ADD COLUMN IF NOT EXISTS empresa_id UUID DEFAULT auth.uid();

-- Tabela: historico_vendas
ALTER TABLE historico_vendas
  ADD COLUMN IF NOT EXISTS empresa_id UUID DEFAULT auth.uid();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 2: Preencher registros já existentes             ║
-- ╚══════════════════════════════════════════════════════════╝
-- ATENÇÃO: Se você já tem dados, precisa vincular a um owner.
-- Opção A — Se rodar logado no Dashboard (service_role), use
--           um UUID fixo do seu primeiro usuário.
-- Opção B — Substitua o UUID abaixo pelo ID do seu usuário
--           principal (ache em Authentication → Users no Supabase).
--
-- ⚠️ IMPORTANTE: Descomente e edite as linhas abaixo SOMENTE
--    se você já tem dados e precisa migrá-los.
-- ─────────────────────────────────────────────────────────────
-- UPDATE produtos
--   SET empresa_id = 'COLE_SEU_USER_UUID_AQUI'
--   WHERE empresa_id IS NULL;
--
-- UPDATE historico_vendas
--   SET empresa_id = 'COLE_SEU_USER_UUID_AQUI'
--   WHERE empresa_id IS NULL;
-- ─────────────────────────────────────────────────────────────

-- Após migrar, tornar a coluna NOT NULL para blindagem total
-- (só descomente DEPOIS de ter preenchido todos os registros)
-- ALTER TABLE produtos ALTER COLUMN empresa_id SET NOT NULL;
-- ALTER TABLE historico_vendas ALTER COLUMN empresa_id SET NOT NULL;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 3: Criar índices para performance                ║
-- ╚══════════════════════════════════════════════════════════╝
-- Sem índice, toda query com RLS faria full table scan.
-- Com índice, o PostgreSQL filtra por empresa_id em O(log n).

CREATE INDEX IF NOT EXISTS idx_produtos_empresa_id
  ON produtos (empresa_id);

CREATE INDEX IF NOT EXISTS idx_historico_vendas_empresa_id
  ON historico_vendas (empresa_id);


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 4: Habilitar Row Level Security                  ║
-- ╚══════════════════════════════════════════════════════════╝

ALTER TABLE produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE historico_vendas ENABLE ROW LEVEL SECURITY;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 5: Criar Políticas RLS — Tabela PRODUTOS         ║
-- ╚══════════════════════════════════════════════════════════╝
-- Cada política verifica: empresa_id = auth.uid()
-- auth.uid() é uma função INTERNA do PostgREST que extrai
-- o user_id do JWT — NUNCA recebe input do usuário, então
-- é 100% imune a SQL Injection.

-- SELECT: Só vê produtos da própria empresa
CREATE POLICY "produtos_select_own"
  ON produtos
  FOR SELECT
  USING (empresa_id = auth.uid());

-- INSERT: Só insere se empresa_id for o próprio ID
CREATE POLICY "produtos_insert_own"
  ON produtos
  FOR INSERT
  WITH CHECK (empresa_id = auth.uid());

-- UPDATE: Só atualiza produtos da própria empresa
CREATE POLICY "produtos_update_own"
  ON produtos
  FOR UPDATE
  USING (empresa_id = auth.uid())
  WITH CHECK (empresa_id = auth.uid());

-- DELETE: Só deleta produtos da própria empresa
CREATE POLICY "produtos_delete_own"
  ON produtos
  FOR DELETE
  USING (empresa_id = auth.uid());


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 6: Criar Políticas RLS — Tabela HISTORICO_VENDAS ║
-- ╚══════════════════════════════════════════════════════════╝

-- SELECT: Só vê vendas da própria empresa
CREATE POLICY "vendas_select_own"
  ON historico_vendas
  FOR SELECT
  USING (empresa_id = auth.uid());

-- INSERT: Só insere vendas com o próprio empresa_id
CREATE POLICY "vendas_insert_own"
  ON historico_vendas
  FOR INSERT
  WITH CHECK (empresa_id = auth.uid());

-- UPDATE: Só atualiza vendas da própria empresa
CREATE POLICY "vendas_update_own"
  ON historico_vendas
  FOR UPDATE
  USING (empresa_id = auth.uid())
  WITH CHECK (empresa_id = auth.uid());

-- DELETE: Só deleta vendas da própria empresa
CREATE POLICY "vendas_delete_own"
  ON historico_vendas
  FOR DELETE
  USING (empresa_id = auth.uid());


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 7: Criar Políticas RLS — Tabela CUSTOS_OPERACIONAIS║
-- ╚══════════════════════════════════════════════════════════╝

ALTER TABLE custos_operacionais
ADD COLUMN IF NOT EXISTS empresa_id UUID DEFAULT auth.uid();

CREATE INDEX IF NOT EXISTS idx_custos_operacionais_empresa_id
  ON custos_operacionais (empresa_id);

ALTER TABLE custos_operacionais ENABLE ROW LEVEL SECURITY;

CREATE POLICY "custos_select_own"
  ON custos_operacionais
  FOR SELECT
  USING (empresa_id = auth.uid());

CREATE POLICY "custos_insert_own"
  ON custos_operacionais
  FOR INSERT
  WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "custos_update_own"
  ON custos_operacionais
  FOR UPDATE
  USING (empresa_id = auth.uid())
  WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "custos_delete_own"
  ON custos_operacionais
  FOR DELETE
  USING (empresa_id = auth.uid());


-- ╔══════════════════════════════════════════════════════════╗
-- ║  ✅ CONCLUÍDO!                                           ║
-- ╚══════════════════════════════════════════════════════════╝
-- Agora:
--   • Cada usuário autenticado só vê seus dados (produtos, vendas e custos)
--   • INSERT sem empresa_id → banco preenche com auth.uid()
--   • Requests sem JWT válido → retornam vazio (não erro)
--   • Imune a SQL Injection (auth.uid() é interno)
