-- ─────────────────────────────────────────────────────────────
-- MIGRAÇÃO — TABELA DESPESAS_VARIAVEIS (MULTI-TENANT)
-- Armazena pagamentos pontuais de funcionários e outras saídas
-- variáveis registradas pelo botão "Pagar Funcionário / Saída"
-- no Fluxo de Caixa. Separada dos custos fixos operacionais.
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS despesas_variaveis (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  valor NUMERIC(12,2) NOT NULL,
  empresa_id UUID NOT NULL DEFAULT auth.uid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índice para consultas por tenant
CREATE INDEX IF NOT EXISTS idx_despesas_variaveis_empresa_id
  ON despesas_variaveis (empresa_id);

-- Habilitar Row Level Security
ALTER TABLE despesas_variaveis ENABLE ROW LEVEL SECURITY;

-- Políticas RLS exclusivas por tenant (empresa_id = auth.uid())
CREATE POLICY "despesas_var_select_own"
  ON despesas_variaveis
  FOR SELECT
  USING (empresa_id = auth.uid());

CREATE POLICY "despesas_var_insert_own"
  ON despesas_variaveis
  FOR INSERT
  WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "despesas_var_update_own"
  ON despesas_variaveis
  FOR UPDATE
  USING (empresa_id = auth.uid())
  WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "despesas_var_delete_own"
  ON despesas_variaveis
  FOR DELETE
  USING (empresa_id = auth.uid());
