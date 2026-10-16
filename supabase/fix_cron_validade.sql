-- Correção do cron "varredura-validades-diaria" (falhava todo dia às 03:00 UTC desde pelo menos 14/10/2026):
--   ERROR: invalid input syntax for type integer: "-14 days" — fn_cron_varrer_validades() linha 17.
-- Causa: produtos.data_validade é timestamptz; timestamptz - date vira interval e não cabe em INT.
-- O repositório (cron_varredura_diaria.sql) e o gatilho fn_alerta_validade já usam ::DATE; a função
-- em produção ficou numa versão antiga. Esta é a definição REAL da produção (pg_get_functiondef,
-- já com o search_path fixo) com UMA linha trocada. CREATE OR REPLACE mantém dono e permissões
-- (anon/authenticated continuam sem EXECUTE). Não roda a varredura: ela roda no próximo agendamento.
-- Impacto avaliado (só leitura, 16/10/2026): 6 produtos de 4 lojas, todos vencidos; os 6 alertas
-- VALIDADE atuais (nenhum lido) serão substituídos por 6 alertas CRITICO equivalentes.

CREATE OR REPLACE FUNCTION public.fn_cron_varrer_validades()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
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
$function$;
