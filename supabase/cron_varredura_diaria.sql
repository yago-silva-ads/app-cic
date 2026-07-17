-- ============================================================
-- App-CIC: Cron Job de Varredura Diária (pg_cron)
-- ============================================================
-- INSTRUÇÕES:
--   1. Execute schema_evolucao_v2.sql e triggers_inteligentes_v2.sql PRIMEIRO
--   2. Habilite a extensão pg_cron no Supabase:
--      Dashboard → Database → Extensions → Procure "pg_cron" → Enable
--   3. Cole este script no Supabase SQL Editor
--   4. Clique em "Run"
-- ============================================================
-- NOTA: O pg_cron roda com privilégios de superusuário, então
-- as funções abaixo usam SECURITY DEFINER e filtram por tenant
-- manualmente para respeitar o isolamento multi-tenant.
-- ============================================================


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNÇÃO 1: Varredura de Validades (Executada pelo Cron)  ║
-- ║  Varre TODOS os produtos de TODOS os tenants e gera       ║
-- ║  alertas para produtos com validade <= 30 dias             ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cron_varrer_validades()
RETURNS JSON AS $$
DECLARE
    v_produto RECORD;
    v_alertas_gerados INT := 0;
    v_dias_restantes INT;
    v_severidade TEXT;
    v_mensagem TEXT;
BEGIN
    -- Varre todos os produtos de todos os tenants com validade definida
    FOR v_produto IN
        SELECT codigo, nome, lote, data_validade, empresa_id
        FROM produtos
        WHERE data_validade IS NOT NULL
          AND data_validade <= CURRENT_DATE + INTERVAL '30 days'
          AND ativo = true
    LOOP
        v_dias_restantes := (v_produto.data_validade::DATE - CURRENT_DATE::DATE);

        -- Determina severidade

        IF v_dias_restantes <= 0 THEN
            v_severidade := 'CRITICO';
            v_mensagem := format(
                '🚨 VENCIDO: "%s" (Lote: %s) venceu há %s dia(s)!',
                v_produto.nome, COALESCE(v_produto.lote, 'N/A'), ABS(v_dias_restantes)
            );
        ELSIF v_dias_restantes <= 7 THEN
            v_severidade := 'ALTO';
            v_mensagem := format(
                '⚠️ URGENTE: "%s" (Lote: %s) vence em %s dia(s)!',
                v_produto.nome, COALESCE(v_produto.lote, 'N/A'), v_dias_restantes
            );
        ELSE
            v_severidade := 'MEDIO';
            v_mensagem := format(
                '📅 ATENÇÃO: "%s" (Lote: %s) vence em %s dia(s).',
                v_produto.nome, COALESCE(v_produto.lote, 'N/A'), v_dias_restantes
            );
        END IF;

        -- Upsert: remove alerta antigo do mesmo produto/tipo e insere novo
        DELETE FROM alertas_sistema
        WHERE empresa_id = v_produto.empresa_id
          AND produto_codigo = v_produto.codigo
          AND tipo = 'VALIDADE';

        INSERT INTO alertas_sistema (empresa_id, tipo, produto_codigo, mensagem, severidade)
        VALUES (v_produto.empresa_id, 'VALIDADE', v_produto.codigo, v_mensagem, v_severidade);

        v_alertas_gerados := v_alertas_gerados + 1;
    END LOOP;

    RETURN json_build_object(
        'status', 'VARREDURA_VALIDADES_CONCLUIDA',
        'timestamp', now(),
        'alertas_gerados', v_alertas_gerados
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNÇÃO 2: Limpeza de Alertas Lidos Antigos             ║
-- ║  Remove alertas marcados como lidos há mais de 30 dias   ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cron_limpar_alertas_antigos()
RETURNS JSON AS $$
DECLARE
    v_deletados INT;
BEGIN
    WITH deletados AS (
        DELETE FROM alertas_sistema
        WHERE lido = true
          AND criado_em < CURRENT_DATE - INTERVAL '30 days'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deletados FROM deletados;

    RETURN json_build_object(
        'status', 'LIMPEZA_ALERTAS_CONCLUIDA',
        'timestamp', now(),
        'alertas_removidos', v_deletados
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNÇÃO 3: Snapshot Diário de KPIs                       ║
-- ║  Registra um snapshot dos KPIs do dia para análise       ║
-- ║  histórica e alimentação dos gráficos de tendência        ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cron_snapshot_kpis()
RETURNS JSON AS $$
DECLARE
    v_tenant RECORD;
    v_snapshots INT := 0;
BEGIN
    -- Para cada tenant ativo, gera um snapshot de métricas
    FOR v_tenant IN
        SELECT DISTINCT empresa_id
        FROM produtos
        WHERE empresa_id IS NOT NULL
    LOOP
        INSERT INTO relatorios_ia (empresa_id, tipo, conteudo_markdown, metricas)
        SELECT
            v_tenant.empresa_id,
            'DIARIO',
            format(
                '## 📊 Snapshot Diário — %s' || E'\n\n' ||
                '- **Total Vendas (mês):** %s' || E'\n' ||
                '- **Receita Total:** R$ %s' || E'\n' ||
                '- **Ticket Médio:** R$ %s' || E'\n' ||
                '- **Lucro Bruto:** R$ %s' || E'\n' ||
                '- **Produtos em Estoque:** %s' || E'\n' ||
                '- **Alertas Ativos:** %s',
                TO_CHAR(CURRENT_DATE, 'DD/MM/YYYY'),
                COALESCE(kpi.total_vendas, 0),
                TO_CHAR(COALESCE(kpi.receita_total, 0), 'FM999G999G999D00'),
                TO_CHAR(COALESCE(kpi.ticket_medio, 0), 'FM999G999D00'),
                TO_CHAR(COALESCE(kpi.lucro_bruto, 0), 'FM999G999G999D00'),
                (SELECT COUNT(*) FROM produtos WHERE empresa_id = v_tenant.empresa_id AND ativo = true),
                (SELECT COUNT(*) FROM alertas_sistema WHERE empresa_id = v_tenant.empresa_id AND lido = false)
            ),
            json_build_object(
                'data', CURRENT_DATE,
                'total_vendas', COALESCE(kpi.total_vendas, 0),
                'receita_total', COALESCE(kpi.receita_total, 0),
                'ticket_medio', COALESCE(kpi.ticket_medio, 0),
                'lucro_bruto', COALESCE(kpi.lucro_bruto, 0),
                'produtos_ativos', (SELECT COUNT(*) FROM produtos WHERE empresa_id = v_tenant.empresa_id AND ativo = true),
                'alertas_ativos', (SELECT COUNT(*) FROM alertas_sistema WHERE empresa_id = v_tenant.empresa_id AND lido = false)
            )::JSONB
        FROM (
            SELECT
                COUNT(*) AS total_vendas,
                SUM(quantidade_vendida * valor_unitario) AS receita_total,
                AVG(valor_unitario) AS ticket_medio,
                SUM(quantidade_vendida * COALESCE(lucro_unitario, 0)) AS lucro_bruto
            FROM historico_vendas
            WHERE empresa_id = v_tenant.empresa_id
              AND data_venda >= date_trunc('month', CURRENT_DATE)
        ) kpi;

        v_snapshots := v_snapshots + 1;
    END LOOP;

    RETURN json_build_object(
        'status', 'SNAPSHOT_KPIS_CONCLUIDO',
        'timestamp', now(),
        'tenants_processados', v_snapshots
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO FINAL: Agendar os Cron Jobs no pg_cron            ║
-- ╚══════════════════════════════════════════════════════════╝
-- NOTA: Descomente as linhas abaixo SOMENTE depois de habilitar
-- a extensão pg_cron no Supabase Dashboard!

-- Habilitar extensão (se ainda não estiver)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 1. Varredura de validades — Todo dia às 03:00 UTC (00:00 BRT)
SELECT cron.schedule(
    'varredura-validades-diaria',
    '0 3 * * *',
     $$SELECT fn_cron_varrer_validades()$$
 );

 -- 2. Limpeza de alertas antigos — Todo dia às 04:00 UTC
 SELECT cron.schedule(
     'limpeza-alertas-antigos',
     '0 4 * * *',
     $$SELECT fn_cron_limpar_alertas_antigos()$$
 );

-- 3. Snapshot de KPIs — Todo dia às 05:00 UTC
 SELECT cron.schedule(
     'snapshot-kpis-diario',
     '0 5 * * *',
     $$SELECT fn_cron_snapshot_kpis()$$
 );


-- ╔══════════════════════════════════════════════════════════╗
-- ║  TESTE MANUAL: Execute para validar as funções           ║
-- ╚══════════════════════════════════════════════════════════╝

-- Teste 1: Varredura de validades
SELECT fn_cron_varrer_validades() AS resultado_varredura;

-- Teste 2: Limpeza de alertas
SELECT fn_cron_limpar_alertas_antigos() AS resultado_limpeza;

-- Teste 3: Snapshot KPIs
SELECT fn_cron_snapshot_kpis() AS resultado_snapshot;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  ✅ CRON JOBS CONFIGURADOS COM SUCESSO!                  ║
-- ╚══════════════════════════════════════════════════════════╝
SELECT 'Funções de cron criadas. Descomente os agendamentos após habilitar pg_cron!' AS status;
