-- ============================================================
-- App-CIC: Migração Multi-Tenant Definitiva com RLS
-- ============================================================
-- INSTRUÇÕES:
--   1. Abra o Supabase Dashboard → SQL Editor
--   2. Cole este script INTEIRO
--   3. Clique em "Run"
-- ============================================================

-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 1: Adicionar coluna empresa_id nas tabelas       ║
-- ╚══════════════════════════════════════════════════════════╝

ALTER TABLE produtos
  ADD COLUMN IF NOT EXISTS empresa_id UUID DEFAULT auth.uid();

ALTER TABLE historico_vendas
  ADD COLUMN IF NOT EXISTS empresa_id UUID DEFAULT auth.uid();

ALTER TABLE custos_operacionais
  ADD COLUMN IF NOT EXISTS empresa_id UUID DEFAULT auth.uid();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 2: Criar índices para performance                ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE INDEX IF NOT EXISTS idx_produtos_empresa_id
  ON produtos (empresa_id);

CREATE INDEX IF NOT EXISTS idx_historico_vendas_empresa_id
  ON historico_vendas (empresa_id);

CREATE INDEX IF NOT EXISTS idx_custos_operacionais_empresa_id
  ON custos_operacionais (empresa_id);


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 3: Habilitar Row Level Security (RLS)            ║
-- ╚══════════════════════════════════════════════════════════╝

ALTER TABLE produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE historico_vendas ENABLE ROW LEVEL SECURITY;
ALTER TABLE custos_operacionais ENABLE ROW LEVEL SECURITY;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 4: VARREDURA E DESTRUIÇÃO DE POLÍTICAS ANTIGAS    ║
-- ╚══════════════════════════════════════════════════════════╝
-- ATENÇÃO: POR QUE O LUCAS CONSEGUIA VER TUDO ANTES?
-- Porque se existir QUALQUER política antiga (mesmo com nomes estranhos,
-- padrão do Supabase ou criadas manualmente) que permita SELECT público
-- (USING true), o PostgreSQL soma (OR) com a política nova e libera os dados.
--
-- O bloco dinâmico abaixo VARRE o banco de dados e APAGA TODAS AS POLÍTICAS
-- existentes nessas 3 tabelas, independentemente do nome que tenham!

DO $$ 
DECLARE 
    pol RECORD; 
BEGIN 
    FOR pol IN 
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE tablename IN ('produtos', 'historico_vendas', 'custos_operacionais') 
    LOOP 
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I;', pol.policyname, pol.tablename); 
    END LOOP; 
END $$;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 5: Criar Políticas RLS — Tabela PRODUTOS         ║
-- ╚══════════════════════════════════════════════════════════╝
-- AGORA SOMENTE ESTAS POLÍTICAS EXISTIRÃO NA TABELA!

CREATE POLICY "produtos_select_own"
  ON produtos
  FOR SELECT
  USING (empresa_id = auth.uid());

CREATE POLICY "produtos_insert_own"
  ON produtos
  FOR INSERT
  WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "produtos_update_own"
  ON produtos
  FOR UPDATE
  USING (empresa_id = auth.uid())
  WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "produtos_delete_own"
  ON produtos
  FOR DELETE
  USING (empresa_id = auth.uid());


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 6: Criar Políticas RLS — Tabela HISTORICO_VENDAS ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE POLICY "vendas_select_own"
  ON historico_vendas
  FOR SELECT
  USING (empresa_id = auth.uid());

CREATE POLICY "vendas_insert_own"
  ON historico_vendas
  FOR INSERT
  WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "vendas_update_own"
  ON historico_vendas
  FOR UPDATE
  USING (empresa_id = auth.uid())
  WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "vendas_delete_own"
  ON historico_vendas
  FOR DELETE
  USING (empresa_id = auth.uid());


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 7: Criar Políticas RLS — Tabela CUSTOS_OPERACIONAIS║
-- ╚══════════════════════════════════════════════════════════╝

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
-- ║  ✅ CONCLUÍDO COM SUCESSO!                              ║
-- ╚══════════════════════════════════════════════════════════╝
-- 100% das políticas antigas foram destruídas e substituídas exclusivamente
-- pelo filtro por tenant (empresa_id = auth.uid()).
