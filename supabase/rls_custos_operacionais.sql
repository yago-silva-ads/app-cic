-- ─────────────────────────────────────────────────────────────
-- MIGRAÇÃO RLS — TABELA CUSTOS_OPERACIONAIS (MULTI-TENANT)
-- ─────────────────────────────────────────────────────────────

ALTER TABLE custos_operacionais
ADD COLUMN IF NOT EXISTS empresa_id UUID DEFAULT auth.uid();

CREATE INDEX IF NOT EXISTS idx_custos_operacionais_empresa_id
  ON custos_operacionais (empresa_id);

ALTER TABLE custos_operacionais ENABLE ROW LEVEL SECURITY;

-- Remove políticas antigas (públicas ou duplicadas)
DROP POLICY IF EXISTS "Enable read access for all users" ON custos_operacionais;
DROP POLICY IF EXISTS "Enable all access for all users" ON custos_operacionais;
DROP POLICY IF EXISTS "custos_select_own" ON custos_operacionais;
DROP POLICY IF EXISTS "custos_insert_own" ON custos_operacionais;
DROP POLICY IF EXISTS "custos_update_own" ON custos_operacionais;
DROP POLICY IF EXISTS "custos_delete_own" ON custos_operacionais;

-- 4. Políticas RLS exclusivas por tenant (empresa_id = auth.uid())
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
