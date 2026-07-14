-- ─────────────────────────────────────────────────────────────
-- MIGRAÇÃO RLS — TABELA CUSTOS_OPERACIONAIS (MULTI-TENANT)
-- ─────────────────────────────────────────────────────────────

-- 1. Adicionar coluna empresa_id com valor padrão auth.uid()
ALTER TABLE custos_operacionais
ADD COLUMN IF NOT EXISTS empresa_id UUID DEFAULT auth.uid();

-- 2. Criar índice para performance na filtragem por empresa
CREATE INDEX IF NOT EXISTS idx_custos_operacionais_empresa_id
  ON custos_operacionais (empresa_id);

-- 3. Habilitar Row Level Security (RLS)
ALTER TABLE custos_operacionais ENABLE ROW LEVEL SECURITY;

-- 4. Políticas RLS (SELECT, INSERT, UPDATE, DELETE) atreladas ao auth.uid()

-- SELECT: Só vê custos da própria empresa
CREATE POLICY "custos_select_own"
  ON custos_operacionais
  FOR SELECT
  USING (empresa_id = auth.uid());

-- INSERT: Só insere custos com o próprio empresa_id
CREATE POLICY "custos_insert_own"
  ON custos_operacionais
  FOR INSERT
  WITH CHECK (empresa_id = auth.uid());

-- UPDATE: Só atualiza custos da própria empresa
CREATE POLICY "custos_update_own"
  ON custos_operacionais
  FOR UPDATE
  USING (empresa_id = auth.uid())
  WITH CHECK (empresa_id = auth.uid());

-- DELETE: Só deleta custos da própria empresa
CREATE POLICY "custos_delete_own"
  ON custos_operacionais
  FOR DELETE
  USING (empresa_id = auth.uid());
