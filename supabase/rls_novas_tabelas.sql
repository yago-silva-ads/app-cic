-- ============================================================
-- App-CIC: RLS para Novas Tabelas (alertas_sistema + relatorios_ia)
-- ============================================================
-- INSTRUÇÕES:
--   1. Execute schema_evolucao_v2.sql PRIMEIRO (cria as tabelas)
--   2. Cole este script no Supabase SQL Editor
--   3. Clique em "Run"
-- ============================================================


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 1: Habilitar RLS nas novas tabelas               ║
-- ╚══════════════════════════════════════════════════════════╝

ALTER TABLE alertas_sistema ENABLE ROW LEVEL SECURITY;
ALTER TABLE relatorios_ia ENABLE ROW LEVEL SECURITY;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 2: Varredura de Políticas Antigas                ║
-- ╚══════════════════════════════════════════════════════════╝

DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname, tablename
        FROM pg_policies
        WHERE tablename IN ('alertas_sistema', 'relatorios_ia')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I;', pol.policyname, pol.tablename);
    END LOOP;
END $$;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 3: Políticas RLS — Tabela ALERTAS_SISTEMA        ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE POLICY "alertas_select_own"
    ON alertas_sistema
    FOR SELECT
    USING (empresa_id = auth.uid());

CREATE POLICY "alertas_insert_own"
    ON alertas_sistema
    FOR INSERT
    WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "alertas_update_own"
    ON alertas_sistema
    FOR UPDATE
    USING (empresa_id = auth.uid())
    WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "alertas_delete_own"
    ON alertas_sistema
    FOR DELETE
    USING (empresa_id = auth.uid());


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 4: Políticas RLS — Tabela RELATORIOS_IA          ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE POLICY "relatorios_select_own"
    ON relatorios_ia
    FOR SELECT
    USING (empresa_id = auth.uid());

CREATE POLICY "relatorios_insert_own"
    ON relatorios_ia
    FOR INSERT
    WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "relatorios_update_own"
    ON relatorios_ia
    FOR UPDATE
    USING (empresa_id = auth.uid())
    WITH CHECK (empresa_id = auth.uid());

CREATE POLICY "relatorios_delete_own"
    ON relatorios_ia
    FOR DELETE
    USING (empresa_id = auth.uid());


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 5: Função QA e Triggers para Novas Tabelas        ║
-- ╚══════════════════════════════════════════════════════════╝

-- Garante que a função QA existe (caso o banco seja novo ou resetado)
CREATE OR REPLACE FUNCTION fn_qa_injetar_e_validar_tenant()
RETURNS TRIGGER AS $$
BEGIN
    -- Se estiver inserindo e não enviou empresa_id, injeta automaticamente
    IF TG_OP = 'INSERT' AND NEW.empresa_id IS NULL THEN
        NEW.empresa_id = auth.uid();
    END IF;

    -- Proteção 1: Impede que alguém insira dados para outra empresa
    IF NEW.empresa_id != auth.uid() THEN
        RAISE EXCEPTION 'QA Blocked: Tentativa de inserção/atualização cross-tenant detectada.';
    END IF;

    -- Proteção 2: Impede que alguém atualize um registro e mude o dono dele
    IF TG_OP = 'UPDATE' AND OLD.empresa_id != NEW.empresa_id THEN
         RAISE EXCEPTION 'QA Blocked: Não é permitido transferir posse de registros entre tenants.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger QA na tabela alertas_sistema
DROP TRIGGER IF EXISTS tr_qa_alertas_tenant ON alertas_sistema;
CREATE TRIGGER tr_qa_alertas_tenant
    BEFORE INSERT OR UPDATE ON alertas_sistema
    FOR EACH ROW
    EXECUTE FUNCTION fn_qa_injetar_e_validar_tenant();

-- Trigger QA na tabela relatorios_ia
DROP TRIGGER IF EXISTS tr_qa_relatorios_tenant ON relatorios_ia;
CREATE TRIGGER tr_qa_relatorios_tenant
    BEFORE INSERT OR UPDATE ON relatorios_ia
    FOR EACH ROW
    EXECUTE FUNCTION fn_qa_injetar_e_validar_tenant();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 6: Trava NOT NULL no empresa_id                   ║
-- ╚══════════════════════════════════════════════════════════╝

ALTER TABLE alertas_sistema ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE relatorios_ia ALTER COLUMN empresa_id SET NOT NULL;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  ✅ RLS NOVAS TABELAS CONCLUÍDO!                        ║
-- ╚══════════════════════════════════════════════════════════╝
SELECT 'RLS blindado aplicado em alertas_sistema e relatorios_ia com sucesso!' AS status;
