-- ============================================================
-- App-CIC: Histórico de Aquisições & Custo Médio Ponderado
-- ============================================================
-- Tabela para registrar todas as entradas/compras de mercadorias
-- e calcular automaticamente o Custo Médio Ponderado por produto.
-- ============================================================

CREATE TABLE IF NOT EXISTS historico_aquisicoes (
    id BIGSERIAL PRIMARY KEY,
    empresa_id UUID NOT NULL DEFAULT auth.uid(),
    produto_codigo TEXT NOT NULL,
    data_aquisicao DATE DEFAULT CURRENT_DATE,
    quantidade INT NOT NULL CHECK (quantidade > 0),
    valor_unitario NUMERIC(12,2) NOT NULL CHECK (valor_unitario >= 0),
    fornecedor TEXT,
    observacao TEXT,
    criado_em TIMESTAMPTZ DEFAULT now()
);

-- Índices para otimização de busca por empresa e produto
CREATE INDEX IF NOT EXISTS idx_aquisicoes_empresa_produto 
ON historico_aquisicoes (empresa_id, produto_codigo);

-- Habilitar Row Level Security (RLS Multi-tenant)
ALTER TABLE historico_aquisicoes ENABLE ROW LEVEL SECURITY;

-- Política RLS: Usuário só acessa e altera aquisições de sua própria empresa
DROP POLICY IF EXISTS "Usuário acessa apenas aquisições da sua empresa" ON historico_aquisicoes;
CREATE POLICY "Usuário acessa apenas aquisições da sua empresa" ON historico_aquisicoes
    FOR ALL
    USING (empresa_id = auth.uid())
    WITH CHECK (empresa_id = auth.uid());

COMMENT ON TABLE historico_aquisicoes IS 'Histórico de compras e entradas de estoque para cálculo do custo médio ponderado.';
