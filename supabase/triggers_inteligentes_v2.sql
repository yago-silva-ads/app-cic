-- ============================================================
-- App-CIC: Triggers Inteligentes v2 — Alertas Automáticos
-- ============================================================
-- INSTRUÇÕES:
--   1. Execute schema_evolucao_v2.sql PRIMEIRO
--   2. Cole este script no Supabase SQL Editor
--   3. Clique em "Run"
-- ============================================================
-- ATENÇÃO: Este script depende das tabelas alertas_sistema e
-- das colunas criadas no schema_evolucao_v2.sql!
-- ============================================================


-- ╔══════════════════════════════════════════════════════════╗
-- ║  TRIGGER 1: Alerta de Validade Próxima                  ║
-- ║  Dispara ao inserir/atualizar produto com data_validade  ║
-- ║  Gera alerta se vence em <= 30 dias                      ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_alerta_validade()
RETURNS TRIGGER AS $$
DECLARE
    v_dias_restantes INT;
    v_severidade TEXT;
    v_mensagem TEXT;
BEGIN
    -- Só processa se tem data de validade
    IF NEW.data_validade IS NULL THEN
        RETURN NEW;
    END IF;

    v_dias_restantes := NEW.data_validade - CURRENT_DATE;

    -- Só gera alerta se vence em 30 dias ou menos
    IF v_dias_restantes > 30 THEN
        RETURN NEW;
    END IF;

    -- Determina severidade baseada nos dias restantes
    IF v_dias_restantes <= 0 THEN
        v_severidade := 'CRITICO';
        v_mensagem := format(
            '🚨 VENCIDO: "%s" (Lote: %s) venceu há %s dia(s)! Retire do estoque imediatamente.',
            NEW.nome, COALESCE(NEW.lote, 'N/A'), ABS(v_dias_restantes)
        );
    ELSIF v_dias_restantes <= 7 THEN
        v_severidade := 'ALTO';
        v_mensagem := format(
            '⚠️ URGENTE: "%s" (Lote: %s) vence em %s dia(s)! Considere promoção relâmpago.',
            NEW.nome, COALESCE(NEW.lote, 'N/A'), v_dias_restantes
        );
    ELSE -- 8 a 30 dias
        v_severidade := 'MEDIO';
        v_mensagem := format(
            '📅 ATENÇÃO: "%s" (Lote: %s) vence em %s dia(s). Planeje ações de desova.',
            NEW.nome, COALESCE(NEW.lote, 'N/A'), v_dias_restantes
        );
    END IF;

    -- Remove alerta antigo do mesmo produto/tipo para evitar duplicatas
    DELETE FROM alertas_sistema
    WHERE empresa_id = NEW.empresa_id
      AND produto_codigo = NEW.codigo
      AND tipo = 'VALIDADE';

    -- Insere o alerta atualizado
    INSERT INTO alertas_sistema (empresa_id, tipo, produto_codigo, mensagem, severidade)
    VALUES (NEW.empresa_id, 'VALIDADE', NEW.codigo, v_mensagem, v_severidade);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Acoplar trigger na tabela produtos
DROP TRIGGER IF EXISTS tr_alerta_validade ON produtos;
CREATE TRIGGER tr_alerta_validade
    AFTER INSERT OR UPDATE OF data_validade ON produtos
    FOR EACH ROW
    EXECUTE FUNCTION fn_alerta_validade();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  TRIGGER 2: Alerta de Estoque Baixo                     ║
-- ║  Dispara quando quantidade cai abaixo do estoque_minimo  ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_alerta_estoque_baixo()
RETURNS TRIGGER AS $$
DECLARE
    v_severidade TEXT;
    v_mensagem TEXT;
BEGIN
    -- Se o estoque está OK (acima do mínimo), limpa alertas antigos e sai
    IF NEW.quantidade > NEW.estoque_minimo THEN
        DELETE FROM alertas_sistema
        WHERE empresa_id = NEW.empresa_id
          AND produto_codigo = NEW.codigo
          AND tipo = 'ESTOQUE_BAIXO';
        RETURN NEW;
    END IF;

    -- Determina severidade e mensagem baseada na quantidade
    IF NEW.quantidade = 0 THEN
        v_severidade := 'CRITICO';
        v_mensagem := format(
            '🚨 ZERADO: "%s" está SEM ESTOQUE! Reposição imediata necessária.',
            NEW.nome
        );
    ELSIF NEW.quantidade <= 2 THEN
        v_severidade := 'ALTO';
        v_mensagem := format(
            '📦 CRÍTICO: "%s" tem apenas %s unidade(s)! (Mínimo configurado: %s)',
            NEW.nome, NEW.quantidade, NEW.estoque_minimo
        );
    ELSE
        v_severidade := 'MEDIO';
        v_mensagem := format(
            '📦 Estoque baixo: "%s" tem %s unidade(s). (Mínimo: %s) — Considere reabastecer.',
            NEW.nome, NEW.quantidade, NEW.estoque_minimo
        );
    END IF;

    -- Remove alerta antigo do mesmo produto/tipo para evitar duplicatas
    DELETE FROM alertas_sistema
    WHERE empresa_id = NEW.empresa_id
      AND produto_codigo = NEW.codigo
      AND tipo = 'ESTOQUE_BAIXO';

    -- Insere o alerta atualizado
    INSERT INTO alertas_sistema (empresa_id, tipo, produto_codigo, mensagem, severidade)
    VALUES (NEW.empresa_id, 'ESTOQUE_BAIXO', NEW.codigo, v_mensagem, v_severidade);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Acoplar trigger na tabela produtos
DROP TRIGGER IF EXISTS tr_alerta_estoque_baixo ON produtos;
CREATE TRIGGER tr_alerta_estoque_baixo
    AFTER INSERT OR UPDATE OF quantidade, estoque_minimo ON produtos
    FOR EACH ROW
    EXECUTE FUNCTION fn_alerta_estoque_baixo();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  TRIGGER 3: Atualização Automática do Timestamp          ║
-- ║  Mantém updated_at sempre atualizado                     ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_atualizar_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Acoplar trigger na tabela produtos
DROP TRIGGER IF EXISTS tr_updated_at_produtos ON produtos;
CREATE TRIGGER tr_updated_at_produtos
    BEFORE UPDATE ON produtos
    FOR EACH ROW
    EXECUTE FUNCTION fn_atualizar_timestamp();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  TRIGGER 4: Cálculo Automático de Lucro na Venda         ║
-- ║  Busca o custo do produto e calcula lucro_unitario        ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_calcular_lucro_venda()
RETURNS TRIGGER AS $$
DECLARE
    v_custo NUMERIC(12,2);
    v_desconto_fator NUMERIC(5,4);
BEGIN
    -- Busca o valor de compra (custo) do produto vendido
    SELECT valor_compra INTO v_custo
    FROM produtos
    WHERE codigo = NEW.produto_codigo
      AND empresa_id = NEW.empresa_id;

    IF v_custo IS NOT NULL THEN
        -- Calcula fator de desconto (ex: 10% desconto = 0.90)
        v_desconto_fator := 1.0 - (COALESCE(NEW.desconto, 0) / 100.0);

        -- Lucro unitário = (preço de venda efetivo) - custo
        NEW.lucro_unitario := (NEW.valor_unitario * v_desconto_fator) - v_custo;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Acoplar trigger na tabela historico_vendas
DROP TRIGGER IF EXISTS tr_calcular_lucro ON historico_vendas;
CREATE TRIGGER tr_calcular_lucro
    BEFORE INSERT ON historico_vendas
    FOR EACH ROW
    EXECUTE FUNCTION fn_calcular_lucro_venda();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  TRIGGER 5: Alerta de Prejuízo por Produto               ║
-- ║  Detecta quando valorVenda < valorCompra                  ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_alerta_prejuizo_produto()
RETURNS TRIGGER AS $$
BEGIN
    -- Verifica se o produto está sendo vendido abaixo do custo
    IF NEW.valor_venda < NEW.valor_compra AND NEW.valor_compra > 0 THEN
        -- Remove alerta antigo
        DELETE FROM alertas_sistema
        WHERE empresa_id = NEW.empresa_id
          AND produto_codigo = NEW.codigo
          AND tipo = 'PREJUIZO';

        INSERT INTO alertas_sistema (empresa_id, tipo, produto_codigo, mensagem, severidade)
        VALUES (
            NEW.empresa_id,
            'PREJUIZO',
            NEW.codigo,
            format(
                '💸 PREJUÍZO: "%s" está com preço de venda (R$%s) ABAIXO do custo (R$%s)! Margem negativa de R$%s por unidade.',
                NEW.nome,
                TO_CHAR(NEW.valor_venda, 'FM999G999D00'),
                TO_CHAR(NEW.valor_compra, 'FM999G999D00'),
                TO_CHAR(NEW.valor_compra - NEW.valor_venda, 'FM999G999D00')
            ),
            'ALTO'
        );
    ELSE
        -- Se preço está OK, limpa alertas de prejuízo antigos
        DELETE FROM alertas_sistema
        WHERE empresa_id = NEW.empresa_id
          AND produto_codigo = NEW.codigo
          AND tipo = 'PREJUIZO';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Acoplar trigger na tabela produtos
DROP TRIGGER IF EXISTS tr_alerta_prejuizo ON produtos;
CREATE TRIGGER tr_alerta_prejuizo
    AFTER INSERT OR UPDATE OF valor_compra, valor_venda ON produtos
    FOR EACH ROW
    EXECUTE FUNCTION fn_alerta_prejuizo_produto();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  ✅ TRIGGERS INTELIGENTES V2 CONCLUÍDOS!                ║
-- ╚══════════════════════════════════════════════════════════╝
-- Resumo dos triggers ativos:
--   1. fn_alerta_validade         → produtos (AFTER INSERT/UPDATE data_validade)
--   2. fn_alerta_estoque_baixo    → produtos (AFTER INSERT/UPDATE quantidade)
--   3. fn_atualizar_timestamp     → produtos (BEFORE UPDATE)
--   4. fn_calcular_lucro_venda    → historico_vendas (BEFORE INSERT)
--   5. fn_alerta_prejuizo_produto → produtos (AFTER INSERT/UPDATE valor_compra/valor_venda)
--   + fn_qa_injetar_e_validar_tenant (já existente no qa_triggers_e_procedures.sql)

SELECT 'Triggers Inteligentes V2 aplicados com sucesso! 5 novos triggers + 1 existente de QA.' AS status;
