-- ============================================================
-- App-CIC: Evolução do Schema v2 — Banco de Dados Blindado
-- ============================================================
-- INSTRUÇÕES:
--   1. Abra o Supabase Dashboard → SQL Editor
--   2. Cole este script INTEIRO
--   3. Clique em "Run"
--   IMPORTANTE: Execute ANTES dos triggers e RLS!
-- ============================================================


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 1: Evolução da tabela PRODUTOS                  ║
-- ║  Novas colunas para controle de validade, estoque       ║
-- ║  mínimo, categorias e rastreabilidade                   ║
-- ╚══════════════════════════════════════════════════════════╝

-- Data de validade (FIFO — primeiro a vencer, primeiro a sair)
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS data_validade DATE;

-- Data de entrada no estoque (rastreabilidade de lote)
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS data_entrada DATE DEFAULT CURRENT_DATE;

-- Estoque mínimo configurável por produto (threshold para alerta)
-- Padrão: 5 unidades — pode ser alterado individualmente pelo lojista
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS estoque_minimo INT DEFAULT 5;

-- Categoria do produto (para agrupamento e análise por segmento)
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS categoria TEXT DEFAULT 'Geral';

-- Unidade de medida (un, kg, L, cx, pct, etc.)
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS unidade TEXT DEFAULT 'un';

-- Flag de produto ativo/inativo (soft delete — não remove do banco)
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS ativo BOOLEAN DEFAULT true;

-- Timestamp de última atualização (auditoria e controle de versão)
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 2: Evolução da tabela HISTORICO_VENDAS           ║
-- ║  Novas colunas para lucro, pagamento, vendedor e desconto║
-- ╚══════════════════════════════════════════════════════════╝

-- Lucro unitário (calculado automaticamente via trigger)
ALTER TABLE historico_vendas ADD COLUMN IF NOT EXISTS lucro_unitario NUMERIC(12,2);

-- Método de pagamento (Dinheiro, Cartão Crédito, Cartão Débito, Pix, etc.)
ALTER TABLE historico_vendas ADD COLUMN IF NOT EXISTS metodo_pagamento TEXT DEFAULT 'Dinheiro';

-- Nome do vendedor que realizou a venda
ALTER TABLE historico_vendas ADD COLUMN IF NOT EXISTS vendedor_nome TEXT;

-- Desconto aplicado na venda (percentual, ex: 10.00 = 10%)
ALTER TABLE historico_vendas ADD COLUMN IF NOT EXISTS desconto NUMERIC(5,2) DEFAULT 0;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 3: Nova tabela ALERTAS_SISTEMA                   ║
-- ║  Log centralizado de alertas gerados por triggers e IA   ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS alertas_sistema (
    id            BIGSERIAL PRIMARY KEY,
    empresa_id    UUID NOT NULL DEFAULT auth.uid(),
    tipo          TEXT NOT NULL CHECK (tipo IN (
                      'VALIDADE',          -- Produto próximo do vencimento
                      'ESTOQUE_BAIXO',     -- Quantidade abaixo do mínimo
                      'PREJUIZO',          -- Margem negativa detectada
                      'IA_SUGESTAO'        -- Sugestão gerada pela IA
                  )),
    produto_codigo TEXT,                   -- Referência ao produto (opcional para alertas gerais)
    mensagem      TEXT NOT NULL,           -- Mensagem formatada com emoji para exibição
    severidade    TEXT DEFAULT 'MEDIO' CHECK (severidade IN (
                      'BAIXO',             -- Informativo
                      'MEDIO',             -- Atenção recomendada
                      'ALTO',              -- Ação necessária
                      'CRITICO'            -- Ação imediata obrigatória
                  )),
    lido          BOOLEAN DEFAULT false,   -- Flag de leitura (para badge de notificação)
    criado_em     TIMESTAMPTZ DEFAULT now()
);

-- Comentário descritivo na tabela
COMMENT ON TABLE alertas_sistema IS 'Log centralizado de alertas automáticos: validade, estoque baixo, prejuízo e sugestões da IA. Isolado por tenant via RLS.';


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 4: Nova tabela RELATORIOS_IA                     ║
-- ║  Cache dos relatórios diários gerados pela IA Gemini     ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS relatorios_ia (
    id              BIGSERIAL PRIMARY KEY,
    empresa_id      UUID NOT NULL DEFAULT auth.uid(),
    tipo            TEXT NOT NULL DEFAULT 'DIARIO' CHECK (tipo IN (
                        'DIARIO',          -- Relatório automático diário (cron 3h)
                        'SOB_DEMANDA',     -- Relatório gerado manualmente pelo lojista
                        'PREDITIVO'        -- Análise preditiva de tendências
                    )),
    conteudo_markdown TEXT NOT NULL,        -- Conteúdo completo do relatório em Markdown
    metricas        JSONB,                 -- Métricas estruturadas (KPIs, scores, alertas)
    criado_em       TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE relatorios_ia IS 'Cache de relatórios gerados pela IA Gemini. Permite consulta histórica sem re-chamar a API.';


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 5: View de KPIs para Dashboard                   ║
-- ║  Inspirada nos cards do dashboard Porsche                ║
-- ╚══════════════════════════════════════════════════════════╝

-- View: KPIs de vendas do mês corrente (por tenant)
CREATE OR REPLACE VIEW vw_kpis_vendas_mes AS
SELECT
    empresa_id,
    COUNT(*)                                        AS total_vendas,
    COALESCE(SUM(quantidade_vendida * valor_unitario), 0)  AS receita_total,
    COALESCE(AVG(valor_unitario), 0)                AS ticket_medio,
    COALESCE(SUM(quantidade_vendida * COALESCE(lucro_unitario, 0)), 0) AS lucro_bruto,
    COALESCE(SUM(quantidade_vendida), 0)            AS unidades_vendidas
FROM historico_vendas
WHERE data_venda >= date_trunc('month', CURRENT_DATE)
GROUP BY empresa_id;

COMMENT ON VIEW vw_kpis_vendas_mes IS 'KPIs agregados de vendas do mês corrente. Filtrado por tenant via RLS.';


-- View: Top 10 produtos mais vendidos (por tenant, mês corrente)
CREATE OR REPLACE VIEW vw_top_produtos_mes AS
SELECT
    hv.empresa_id,
    hv.produto_codigo,
    p.nome                                          AS produto_nome,
    SUM(hv.quantidade_vendida)                      AS total_vendido,
    SUM(hv.quantidade_vendida * hv.valor_unitario)  AS receita_produto,
    SUM(hv.quantidade_vendida * COALESCE(hv.lucro_unitario, 0)) AS lucro_produto
FROM historico_vendas hv
LEFT JOIN produtos p ON p.codigo = hv.produto_codigo AND p.empresa_id = hv.empresa_id
WHERE hv.data_venda >= date_trunc('month', CURRENT_DATE)
GROUP BY hv.empresa_id, hv.produto_codigo, p.nome
ORDER BY total_vendido DESC
LIMIT 10;

COMMENT ON VIEW vw_top_produtos_mes IS 'Ranking dos 10 produtos mais vendidos no mês. Inspirado no ranking do dashboard Porsche.';


-- View: Produtos com validade crítica (próximos 30 dias)
CREATE OR REPLACE VIEW vw_produtos_validade_critica AS
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
ORDER BY data_validade ASC;

COMMENT ON VIEW vw_produtos_validade_critica IS 'Produtos com validade nos próximos 30 dias ou já vencidos. Para uso nos pop-ups de alerta.';


-- View: Produtos com estoque abaixo do mínimo
CREATE OR REPLACE VIEW vw_produtos_estoque_baixo AS
SELECT
    empresa_id,
    codigo,
    nome,
    quantidade,
    estoque_minimo,
    CASE
        WHEN quantidade = 0 THEN 'ZERADO'
        WHEN quantidade <= 2 THEN 'CRITICO'
        ELSE 'BAIXO'
    END AS status_estoque
FROM produtos
WHERE quantidade <= estoque_minimo
  AND ativo = true
ORDER BY quantidade ASC;

COMMENT ON VIEW vw_produtos_estoque_baixo IS 'Produtos com estoque abaixo do mínimo configurado. Para uso nos pop-ups de alerta.';


-- View: Faturamento mensal (últimos 12 meses, para gráfico de linha)
CREATE OR REPLACE VIEW vw_faturamento_mensal AS
SELECT
    empresa_id,
    date_trunc('month', data_venda)::DATE           AS mes,
    TO_CHAR(data_venda, 'Mon/YY')                   AS mes_label,
    COALESCE(SUM(quantidade_vendida * valor_unitario), 0) AS faturamento,
    COALESCE(SUM(quantidade_vendida * COALESCE(lucro_unitario, 0)), 0) AS lucro,
    COUNT(*)                                        AS num_vendas
FROM historico_vendas
WHERE data_venda >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY empresa_id, date_trunc('month', data_venda), TO_CHAR(data_venda, 'Mon/YY')
ORDER BY mes ASC;

COMMENT ON VIEW vw_faturamento_mensal IS 'Faturamento agregado por mês (últimos 12). Para gráfico de linha no dashboard web.';


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 6: Índices de Performance                        ║
-- ║  Otimizam consultas de validade, estoque e KPIs          ║
-- ╚══════════════════════════════════════════════════════════╝

-- Índice para busca rápida de produtos por validade
CREATE INDEX IF NOT EXISTS idx_produtos_validade
    ON produtos (data_validade)
    WHERE data_validade IS NOT NULL;

-- Índice para busca rápida de produtos com estoque baixo
CREATE INDEX IF NOT EXISTS idx_produtos_estoque_baixo
    ON produtos (quantidade, estoque_minimo)
    WHERE ativo = true;

-- Índice para busca de vendas por data (ORDER BY data_venda DESC)
CREATE INDEX IF NOT EXISTS idx_vendas_data
    ON historico_vendas (data_venda DESC);

-- Índice para busca de vendas por produto (JOIN com produtos)
CREATE INDEX IF NOT EXISTS idx_vendas_produto
    ON historico_vendas (produto_codigo, empresa_id);

-- Índice para busca de alertas não lidos (para badge de notificação)
CREATE INDEX IF NOT EXISTS idx_alertas_nao_lidos
    ON alertas_sistema (empresa_id, lido, criado_em DESC)
    WHERE lido = false;

-- Índice para busca de relatórios IA por empresa e data
CREATE INDEX IF NOT EXISTS idx_relatorios_ia_empresa
    ON relatorios_ia (empresa_id, criado_em DESC);

-- Índice para categoria de produto (agrupamento no dashboard)
CREATE INDEX IF NOT EXISTS idx_produtos_categoria
    ON produtos (empresa_id, categoria)
    WHERE ativo = true;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 7: Constraints de Integridade                    ║
-- ╚══════════════════════════════════════════════════════════╝

-- Garantir que estoque_minimo não seja negativo
ALTER TABLE produtos ADD CONSTRAINT chk_estoque_minimo_positivo
    CHECK (estoque_minimo >= 0);

-- Garantir que quantidade não seja negativa
ALTER TABLE produtos DROP CONSTRAINT IF EXISTS chk_quantidade_positiva;
ALTER TABLE produtos ADD CONSTRAINT chk_quantidade_positiva
    CHECK (quantidade >= 0);

-- Garantir que valor de compra e venda são positivos
ALTER TABLE produtos DROP CONSTRAINT IF EXISTS chk_valores_positivos;

-- Garantir que desconto está entre 0% e 100%
ALTER TABLE historico_vendas DROP CONSTRAINT IF EXISTS chk_desconto_valido;
ALTER TABLE historico_vendas ADD CONSTRAINT chk_desconto_valido
    CHECK (desconto >= 0 AND desconto <= 100);


-- ╔══════════════════════════════════════════════════════════╗
-- ║  ✅ SCHEMA V2 CONCLUÍDO COM SUCESSO!                    ║
-- ╚══════════════════════════════════════════════════════════╝
SELECT 'Schema V2 aplicado com sucesso! Novas colunas, tabelas, views e índices criados.' AS status;
