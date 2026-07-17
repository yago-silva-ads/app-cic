-- ==============================================================================
-- 🛡️ BLINDAGEM MÁXIMA MULTI-TENANT & ANTI-INJEÇÃO SQL — VIEWS E RLS (APP-CIC)
-- ==============================================================================
-- Este script blinda o banco de dados contra vazamento de dados entre empresas,
-- garantindo que o Ranking de Top Produtos, KPIs, Gráficos e Estoques
-- considerem EXCLUSIVAMENTE os dados do lojista logado (auth.uid()).
-- Execute este script no SQL Editor do Supabase.
-- ==============================================================================

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ 1. REPARAR E BLINDAR AS VIEWS DE RELATÓRIOS E RANKING (SECURITY INVOKER)   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- 🏆 View 1: Top 10 Produtos Mais Vendidos no Mês (Ranking Porsche)
DROP VIEW IF EXISTS vw_top_produtos_mes CASCADE;
CREATE OR REPLACE VIEW vw_top_produtos_mes
WITH (security_invoker = true) AS
SELECT
    hv.empresa_id,
    hv.produto_codigo,
    COALESCE(p.nome, hv.produto_codigo)             AS produto_nome,
    SUM(hv.quantidade_vendida)                      AS total_vendido,
    SUM(hv.quantidade_vendida * hv.valor_unitario)  AS receita_produto,
    SUM(hv.quantidade_vendida * COALESCE(hv.lucro_unitario, 0)) AS lucro_produto
FROM historico_vendas hv
LEFT JOIN produtos p ON p.codigo = hv.produto_codigo AND p.empresa_id = hv.empresa_id
WHERE hv.data_venda >= date_trunc('month', CURRENT_DATE)
  AND hv.empresa_id = auth.uid()  -- 🔒 ISOLAMENTO DE TENANT ABSOLUTO
GROUP BY hv.empresa_id, hv.produto_codigo, COALESCE(p.nome, hv.produto_codigo)
ORDER BY receita_produto DESC
LIMIT 10;

COMMENT ON VIEW vw_top_produtos_mes IS 'Ranking dos 10 produtos com maior receita no mês. Filtrado por auth.uid() do tenant logado.';


-- 📊 View 2: KPIs Agregados de Vendas do Mês Corrente
DROP VIEW IF EXISTS vw_kpis_vendas_mes CASCADE;
CREATE OR REPLACE VIEW vw_kpis_vendas_mes
WITH (security_invoker = true) AS
SELECT
    empresa_id,
    COUNT(*)                                        AS total_vendas,
    COALESCE(SUM(quantidade_vendida * valor_unitario), 0)  AS receita_total,
    COALESCE(AVG(valor_unitario), 0)                AS ticket_medio,
    COALESCE(SUM(quantidade_vendida * COALESCE(lucro_unitario, 0)), 0) AS lucro_bruto,
    COALESCE(SUM(quantidade_vendida), 0)            AS unidades_vendidas
FROM historico_vendas
WHERE data_venda >= date_trunc('month', CURRENT_DATE)
  AND empresa_id = auth.uid()  -- 🔒 ISOLAMENTO DE TENANT ABSOLUTO
GROUP BY empresa_id;

COMMENT ON VIEW vw_kpis_vendas_mes IS 'KPIs agregados de vendas do mês corrente. Filtrado rigidamente para o lojista logado.';


-- 📈 View 3: Faturamento dos Últimos 12 Meses (Gráfico de Linha Porsche)
DROP VIEW IF EXISTS vw_faturamento_mensal CASCADE;
CREATE OR REPLACE VIEW vw_faturamento_mensal
WITH (security_invoker = true) AS
SELECT
    empresa_id,
    date_trunc('month', data_venda)::DATE           AS mes,
    TO_CHAR(data_venda, 'Mon/YY')                   AS mes_label,
    COALESCE(SUM(quantidade_vendida * valor_unitario), 0) AS faturamento,
    COALESCE(SUM(quantidade_vendida * COALESCE(lucro_unitario, 0)), 0) AS lucro,
    COUNT(*)                                        AS num_vendas
FROM historico_vendas
WHERE data_venda >= CURRENT_DATE - INTERVAL '12 months'
  AND empresa_id = auth.uid()  -- 🔒 ISOLAMENTO DE TENANT ABSOLUTO
GROUP BY empresa_id, date_trunc('month', data_venda), TO_CHAR(data_venda, 'Mon/YY')
ORDER BY mes ASC;

COMMENT ON VIEW vw_faturamento_mensal IS 'Série histórica dos últimos 12 meses. Exclusiva por tenant via auth.uid().';


-- 🚨 View 4: Produtos com Validade Crítica (Próximos 30 dias)
DROP VIEW IF EXISTS vw_produtos_validade_critica CASCADE;
CREATE OR REPLACE VIEW vw_produtos_validade_critica
WITH (security_invoker = true) AS
SELECT
    empresa_id,
    codigo,
    nome,
    data_validade,
    quantidade,
    (data_validade - CURRENT_DATE) AS dias_para_vencer,
    CASE
        WHEN data_validade <= CURRENT_DATE THEN 'VENCIDO'
        WHEN data_validade <= CURRENT_DATE + INTERVAL '7 days' THEN 'CRITICO'
        WHEN data_validade <= CURRENT_DATE + INTERVAL '30 days' THEN 'ATENCAO'
        ELSE 'OK'
    END AS status_validade
FROM produtos
WHERE data_validade IS NOT NULL
  AND data_validade <= CURRENT_DATE + INTERVAL '30 days'
  AND ativo = true
  AND empresa_id = auth.uid()  -- 🔒 ISOLAMENTO DE TENANT ABSOLUTO
ORDER BY data_validade ASC;

COMMENT ON VIEW vw_produtos_validade_critica IS 'Validade de produtos do lojista logado.';


-- 📉 View 5: Produtos com Estoque Abaixo do Mínimo
DROP VIEW IF EXISTS vw_produtos_estoque_baixo CASCADE;
CREATE OR REPLACE VIEW vw_produtos_estoque_baixo
WITH (security_invoker = true) AS
SELECT
    empresa_id,
    codigo,
    nome,
    quantidade,
    estoque_minimo,
    (estoque_minimo - quantidade) AS deficit
FROM produtos
WHERE quantidade <= COALESCE(estoque_minimo, 5)
  AND ativo = true
  AND empresa_id = auth.uid()  -- 🔒 ISOLAMENTO DE TENANT ABSOLUTO
ORDER BY (estoque_minimo - quantidade) DESC;

COMMENT ON VIEW vw_produtos_estoque_baixo IS 'Produtos com estoque abaixo do mínimo do lojista logado.';


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ 2. GARANTIA FORÇADA DE ROW LEVEL SECURITY (RLS) EM TODAS AS TABELAS        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE historico_vendas ENABLE ROW LEVEL SECURITY;
ALTER TABLE custos_operacionais ENABLE ROW LEVEL SECURITY;
ALTER TABLE alertas_sistema ENABLE ROW LEVEL SECURITY;
ALTER TABLE relatorios_ia ENABLE ROW LEVEL SECURITY;

-- Recriação das Políticas Definitivas de RLS para todas as tabelas
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN SELECT unnest(ARRAY['produtos', 'historico_vendas', 'custos_operacionais', 'alertas_sistema', 'relatorios_ia'])
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I;', 'rls_policy_' || t || '_tenant', t);
        EXECUTE format('
            CREATE POLICY %I ON %I
            FOR ALL
            TO authenticated
            USING (empresa_id = auth.uid())
            WITH CHECK (empresa_id = auth.uid());
        ', 'rls_policy_' || t || '_tenant', t);
    END LOOP;
END $$;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ 3. CONCESSÃO DE ACESSO EXCLUSIVO A USUÁRIOS AUTENTICADOS                 ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

GRANT SELECT ON vw_top_produtos_mes TO authenticated;
GRANT SELECT ON vw_kpis_vendas_mes TO authenticated;
GRANT SELECT ON vw_faturamento_mensal TO authenticated;
GRANT SELECT ON vw_produtos_validade_critica TO authenticated;
GRANT SELECT ON vw_produtos_estoque_baixo TO authenticated;

-- FIM DO SCRIPT DE BLINDAGEM TOTAL
