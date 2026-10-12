-- ============================================================
-- App-CIC v3: estoque atômico, isolamento real por loja, movimentações
-- ============================================================
-- COMO RODAR: Supabase Dashboard -> SQL Editor -> cole tudo -> Run.
-- É idempotente: pode rodar mais de uma vez.
--
-- O QUE CORRIGE
--  1. "Mistura de contas": `produtos.codigo` era único no banco inteiro (e
--     `historico_vendas` apontava só para ele). Duas lojas não podiam ter o
--     mesmo código de barras, e o upsert por `codigo` podia colidir com a
--     linha de outra loja. Passa a ser único POR LOJA: (empresa_id, codigo).
--  2. "Falta de estoque": o app antigo tratava `quantidade` como total
--     comprado e calculava "restante = quantidade - vendidas" na tela,
--     enquanto os triggers de alerta tratam `quantidade` como SALDO ATUAL.
--     Agora `quantidade` é sempre o saldo atual e toda baixa/entrada passa
--     por funções que travam a linha (sem corrida, sem saldo negativo).
--  3. Venda e baixa de estoque na MESMA transação (ou grava tudo, ou nada).
--  4. Histórico de movimentações (entradas/saídas) no banco, por loja.
--  5. Custo e nome históricos na venda (a Curva ABC não usa preço atual).
--
-- ATENÇÃO (passo opcional no final): se os seus produtos hoje têm
-- `quantidade` = total comprado, rode o PASSO 9 UMA ÚNICA VEZ.
-- ============================================================


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 1: unicidade do código passa a ser POR LOJA       ║
-- ╚══════════════════════════════════════════════════════════╝

-- 1.1 Remove as FKs de historico_vendas -> produtos (serão recriadas)
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.historico_vendas'::regclass AND contype = 'f'
      AND confrelid = 'public.produtos'::regclass
  LOOP
    EXECUTE format('ALTER TABLE public.historico_vendas DROP CONSTRAINT %I', r.conname);
  END LOOP;
END $$;

-- 1.2 Remove PK/UNIQUE que valham SÓ para (codigo)
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT c.conname
    FROM pg_constraint c
    WHERE c.conrelid = 'public.produtos'::regclass
      AND c.contype IN ('p', 'u')
      AND (SELECT array_agg(a.attname::text ORDER BY a.attname)
             FROM unnest(c.conkey) k
             JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k) = ARRAY['codigo']
  LOOP
    EXECUTE format('ALTER TABLE public.produtos DROP CONSTRAINT %I', r.conname);
  END LOOP;
END $$;

-- 1.3 Garante uma chave primária estável (id), se a tabela tiver coluna id
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conrelid = 'public.produtos'::regclass AND contype = 'p') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'produtos' AND column_name = 'id') THEN
      ALTER TABLE public.produtos ADD PRIMARY KEY (id);
    ELSE
      ALTER TABLE public.produtos ADD COLUMN id UUID DEFAULT gen_random_uuid();
      ALTER TABLE public.produtos ADD PRIMARY KEY (id);
    END IF;
  END IF;
END $$;

-- 1.4 Único por loja
ALTER TABLE public.produtos DROP CONSTRAINT IF EXISTS produtos_empresa_codigo_key;
ALTER TABLE public.produtos
  ADD CONSTRAINT produtos_empresa_codigo_key UNIQUE (empresa_id, codigo);

-- 1.5 FK composta. RESTRICT: apagar produto com vendas NÃO apaga o histórico
-- (o app arquiva o produto em vez de excluir quando há vendas).
ALTER TABLE public.historico_vendas
  ADD CONSTRAINT historico_vendas_produto_fkey
  FOREIGN KEY (empresa_id, produto_codigo)
  REFERENCES public.produtos (empresa_id, codigo)
  ON DELETE RESTRICT;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 2: colunas novas                                  ║
-- ╚══════════════════════════════════════════════════════════╝

ALTER TABLE public.produtos ADD COLUMN IF NOT EXISTS ativo BOOLEAN DEFAULT true;
ALTER TABLE public.produtos ADD COLUMN IF NOT EXISTS categoria TEXT DEFAULT 'Geral';
ALTER TABLE public.produtos ADD COLUMN IF NOT EXISTS estoque_minimo INT DEFAULT 5;
ALTER TABLE public.produtos ADD COLUMN IF NOT EXISTS unidade TEXT DEFAULT 'un';
ALTER TABLE public.produtos ADD COLUMN IF NOT EXISTS vendidas INT DEFAULT 0;

ALTER TABLE public.historico_vendas ADD COLUMN IF NOT EXISTS venda_id UUID;
ALTER TABLE public.historico_vendas ADD COLUMN IF NOT EXISTS nome_produto TEXT;
ALTER TABLE public.historico_vendas ADD COLUMN IF NOT EXISTS custo_unitario NUMERIC(12,2);
ALTER TABLE public.historico_vendas ADD COLUMN IF NOT EXISTS metodo_pagamento TEXT DEFAULT 'DINHEIRO';
ALTER TABLE public.historico_vendas ADD COLUMN IF NOT EXISTS vendedor_nome TEXT;
ALTER TABLE public.historico_vendas ADD COLUMN IF NOT EXISTS desconto NUMERIC(5,2) DEFAULT 0;

ALTER TABLE public.custos_operacionais ADD COLUMN IF NOT EXISTS tipo TEXT DEFAULT 'FIXO';
ALTER TABLE public.custos_operacionais ADD COLUMN IF NOT EXISTS categoria TEXT;
ALTER TABLE public.custos_operacionais ADD COLUMN IF NOT EXISTS observacao TEXT;

CREATE INDEX IF NOT EXISTS idx_historico_vendas_venda_id ON public.historico_vendas (venda_id);
CREATE INDEX IF NOT EXISTS idx_historico_vendas_empresa_data ON public.historico_vendas (empresa_id, data_venda);


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 3: tabela de movimentações de estoque             ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.movimentacoes_estoque (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id      UUID NOT NULL DEFAULT auth.uid(),
  tipo            TEXT NOT NULL CHECK (tipo IN ('ENTRADA', 'SAIDA')),
  motivo          TEXT NOT NULL CHECK (motivo IN (
                    'COMPRA_FORNECEDOR', 'VENDA_PDV', 'AJUSTE_ESTOQUE',
                    'PERDA_AVARIA', 'DEVOLUCAO', 'PRODUCAO_COMBO')),
  produto_codigo  TEXT NOT NULL,
  produto_nome    TEXT NOT NULL,
  quantidade      INT  NOT NULL CHECK (quantidade > 0),
  valor_unitario  NUMERIC(12,2) NOT NULL DEFAULT 0,
  valor_total     NUMERIC(12,2) NOT NULL DEFAULT 0,
  documento       TEXT,
  observacao      TEXT,
  venda_id        UUID,
  criado_em       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mov_estoque_empresa_data
  ON public.movimentacoes_estoque (empresa_id, criado_em DESC);

ALTER TABLE public.movimentacoes_estoque ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mov_select_own ON public.movimentacoes_estoque;
DROP POLICY IF EXISTS mov_insert_own ON public.movimentacoes_estoque;
CREATE POLICY mov_select_own ON public.movimentacoes_estoque
  FOR SELECT TO authenticated USING (empresa_id = auth.uid());
CREATE POLICY mov_insert_own ON public.movimentacoes_estoque
  FOR INSERT TO authenticated WITH CHECK (empresa_id = auth.uid());
-- Sem UPDATE/DELETE: o histórico de movimentações é imutável.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 4: conta do estabelecimento e caixa (por loja)    ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.contas_estabelecimento (
  empresa_id    UUID PRIMARY KEY DEFAULT auth.uid(),
  dados         JSONB NOT NULL DEFAULT '{}'::jsonb,
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sessoes_caixa (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id    UUID NOT NULL DEFAULT auth.uid(),
  status        TEXT NOT NULL DEFAULT 'ABERTO' CHECK (status IN ('ABERTO', 'FECHADO')),
  dados         JSONB NOT NULL DEFAULT '{}'::jsonb,
  aberta_em     TIMESTAMPTZ NOT NULL DEFAULT now(),
  fechada_em    TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_sessoes_caixa_empresa ON public.sessoes_caixa (empresa_id, aberta_em DESC);

ALTER TABLE public.contas_estabelecimento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessoes_caixa ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['contas_estabelecimento', 'sessoes_caixa'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select_own', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_insert_own', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_update_own', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (empresa_id = auth.uid())', t || '_select_own', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK (empresa_id = auth.uid())', t || '_insert_own', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING (empresa_id = auth.uid()) WITH CHECK (empresa_id = auth.uid())', t || '_update_own', t);
  END LOOP;
END $$;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 5: venda atômica (baixa + histórico + movimento)  ║
-- ╚══════════════════════════════════════════════════════════╝
-- SECURITY INVOKER: roda com o JWT do lojista, então a RLS continua valendo
-- e `auth.uid()` é sempre a loja dele. O app não envia empresa_id.
--
-- p_itens: [{"codigo":"789...","quantidade":2,"valor_unitario":4.90}, ...]
-- Erros (mensagem começa com um código estável que o app traduz):
--   SEM_SESSAO | ITENS_VAZIOS | ITEM_INVALIDO:<codigo>
--   PRODUTO_NAO_ENCONTRADO:<codigo> | ESTOQUE_INSUFICIENTE:<codigo>:<saldo>

CREATE OR REPLACE FUNCTION public.registrar_venda(
  p_itens           JSONB,
  p_forma_pagamento TEXT    DEFAULT 'DINHEIRO',
  p_operador        TEXT    DEFAULT NULL,
  p_desconto_pct    NUMERIC DEFAULT 0
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_venda   UUID := gen_random_uuid();
  v_item    JSONB;
  v_codigo  TEXT;
  v_qtd     INT;
  v_preco   NUMERIC(12,2);
  v_prod    public.produtos%ROWTYPE;
  v_total   NUMERIC(12,2) := 0;
  v_n       INT := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'SEM_SESSAO'; END IF;
  IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'ITENS_VAZIOS';
  END IF;
  IF p_desconto_pct IS NULL OR p_desconto_pct < 0 OR p_desconto_pct > 100 THEN
    RAISE EXCEPTION 'ITEM_INVALIDO:desconto';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens) LOOP
    v_codigo := btrim(v_item->>'codigo');
    v_qtd    := (v_item->>'quantidade')::INT;
    v_preco  := (v_item->>'valor_unitario')::NUMERIC;
    IF v_codigo IS NULL OR v_codigo = '' OR v_qtd IS NULL OR v_qtd <= 0
       OR v_preco IS NULL OR v_preco < 0 THEN
      RAISE EXCEPTION 'ITEM_INVALIDO:%', COALESCE(v_codigo, '?');
    END IF;

    -- Trava a linha da loja: duas vendas simultâneas do mesmo item não passam.
    SELECT * INTO v_prod FROM public.produtos
     WHERE empresa_id = v_uid AND codigo = v_codigo
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'PRODUTO_NAO_ENCONTRADO:%', v_codigo; END IF;
    IF v_prod.quantidade < v_qtd THEN
      RAISE EXCEPTION 'ESTOQUE_INSUFICIENTE:%:%', v_codigo, v_prod.quantidade;
    END IF;

    UPDATE public.produtos
       SET quantidade = quantidade - v_qtd,
           vendidas   = COALESCE(vendidas, 0) + v_qtd
     WHERE id = v_prod.id;

    INSERT INTO public.historico_vendas
      (empresa_id, produto_codigo, quantidade_vendida, valor_unitario,
       metodo_pagamento, vendedor_nome, desconto, venda_id, nome_produto, custo_unitario)
    VALUES
      (v_uid, v_codigo, v_qtd, v_preco,
       COALESCE(NULLIF(p_forma_pagamento, ''), 'DINHEIRO'), p_operador,
       p_desconto_pct, v_venda, v_prod.nome, v_prod.valor_compra);

    INSERT INTO public.movimentacoes_estoque
      (empresa_id, tipo, motivo, produto_codigo, produto_nome, quantidade,
       valor_unitario, valor_total, documento, observacao, venda_id)
    VALUES
      (v_uid, 'SAIDA', 'VENDA_PDV', v_codigo, v_prod.nome, v_qtd,
       v_preco, round(v_qtd * v_preco, 2), 'VEN-' || upper(substr(v_venda::TEXT, 1, 8)),
       'Venda no PDV (' || COALESCE(NULLIF(p_forma_pagamento, ''), 'DINHEIRO') || ')', v_venda);

    v_total := v_total + round(v_qtd * v_preco * (1 - p_desconto_pct / 100.0), 2);
    v_n := v_n + 1;
  END LOOP;

  RETURN jsonb_build_object('venda_id', v_venda, 'itens', v_n, 'total', v_total);
END;
$$;

REVOKE ALL ON FUNCTION public.registrar_venda(JSONB, TEXT, TEXT, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_venda(JSONB, TEXT, TEXT, NUMERIC) TO authenticated;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 6: entrada / ajuste / perda de estoque            ║
-- ╚══════════════════════════════════════════════════════════╝
-- p_delta > 0 entra, < 0 sai. Nunca deixa o saldo negativo.

CREATE OR REPLACE FUNCTION public.ajustar_estoque(
  p_codigo         TEXT,
  p_delta          INT,
  p_motivo         TEXT,
  p_documento      TEXT    DEFAULT NULL,
  p_observacao     TEXT    DEFAULT NULL,
  p_valor_unitario NUMERIC DEFAULT NULL
) RETURNS INT
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid  UUID := auth.uid();
  v_prod public.produtos%ROWTYPE;
  v_novo INT;
  v_vu   NUMERIC(12,2);
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'SEM_SESSAO'; END IF;
  IF p_delta IS NULL OR p_delta = 0 THEN RAISE EXCEPTION 'ITEM_INVALIDO:delta'; END IF;
  IF p_motivo NOT IN ('COMPRA_FORNECEDOR', 'VENDA_PDV', 'AJUSTE_ESTOQUE',
                      'PERDA_AVARIA', 'DEVOLUCAO', 'PRODUCAO_COMBO') THEN
    RAISE EXCEPTION 'ITEM_INVALIDO:motivo';
  END IF;

  SELECT * INTO v_prod FROM public.produtos
   WHERE empresa_id = v_uid AND codigo = btrim(p_codigo)
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PRODUTO_NAO_ENCONTRADO:%', p_codigo; END IF;

  v_novo := v_prod.quantidade + p_delta;
  IF v_novo < 0 THEN
    RAISE EXCEPTION 'ESTOQUE_INSUFICIENTE:%:%', p_codigo, v_prod.quantidade;
  END IF;

  UPDATE public.produtos SET quantidade = v_novo WHERE id = v_prod.id;

  v_vu := COALESCE(p_valor_unitario, v_prod.valor_compra, 0);
  INSERT INTO public.movimentacoes_estoque
    (empresa_id, tipo, motivo, produto_codigo, produto_nome, quantidade,
     valor_unitario, valor_total, documento, observacao)
  VALUES
    (v_uid, CASE WHEN p_delta > 0 THEN 'ENTRADA' ELSE 'SAIDA' END, p_motivo,
     v_prod.codigo, v_prod.nome, abs(p_delta), v_vu, round(abs(p_delta) * v_vu, 2),
     p_documento, p_observacao);

  RETURN v_novo;
END;
$$;

REVOKE ALL ON FUNCTION public.ajustar_estoque(TEXT, INT, TEXT, TEXT, TEXT, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajustar_estoque(TEXT, INT, TEXT, TEXT, TEXT, NUMERIC) TO authenticated;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 7: cadastro de produto (cria ou atualiza POR LOJA) ║
-- ╚══════════════════════════════════════════════════════════╝
-- p_modo_quantidade: 'somar'   -> quantidade do formulário entra no saldo
--                    'definir' -> o saldo passa a ser exatamente o informado
-- Sempre registra a movimentação correspondente.

CREATE OR REPLACE FUNCTION public.salvar_produto(
  p_produto          JSONB,
  p_modo_quantidade  TEXT DEFAULT 'somar'
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_codigo TEXT := btrim(p_produto->>'codigo');
  v_qtd    INT  := COALESCE((p_produto->>'quantidade')::INT, 0);
  v_prod   public.produtos%ROWTYPE;
  v_delta  INT;
  v_novo   INT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'SEM_SESSAO'; END IF;
  IF v_codigo IS NULL OR v_codigo = '' OR length(btrim(COALESCE(p_produto->>'nome', ''))) = 0 THEN
    RAISE EXCEPTION 'ITEM_INVALIDO:%', COALESCE(v_codigo, '?');
  END IF;
  IF v_qtd < 0 OR COALESCE((p_produto->>'valor_compra')::NUMERIC, 0) < 0
     OR COALESCE((p_produto->>'valor_venda')::NUMERIC, 0) < 0 THEN
    RAISE EXCEPTION 'ITEM_INVALIDO:%', v_codigo;
  END IF;

  SELECT * INTO v_prod FROM public.produtos
   WHERE empresa_id = v_uid AND codigo = v_codigo FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.produtos
      (empresa_id, codigo, nome, lote, quantidade, valor_compra, markup, valor_venda,
       origem, categoria, data_entrada, data_validade, estoque_minimo, unidade, vendidas, ativo)
    VALUES
      (v_uid, v_codigo, btrim(p_produto->>'nome'), COALESCE(p_produto->>'lote', ''), v_qtd,
       COALESCE((p_produto->>'valor_compra')::NUMERIC, 0),
       COALESCE((p_produto->>'markup')::NUMERIC, 1),
       COALESCE((p_produto->>'valor_venda')::NUMERIC, 0),
       COALESCE(p_produto->>'origem', 'Revendido'),
       COALESCE(p_produto->>'categoria', 'Geral'),
       COALESCE((p_produto->>'data_entrada')::DATE, CURRENT_DATE),
       NULLIF(p_produto->>'data_validade', '')::DATE,
       COALESCE((p_produto->>'estoque_minimo')::INT, 5),
       COALESCE(p_produto->>'unidade', 'un'), 0, true);
    v_delta := v_qtd;
    v_novo  := v_qtd;
    IF v_qtd > 0 THEN
      INSERT INTO public.movimentacoes_estoque
        (empresa_id, tipo, motivo, produto_codigo, produto_nome, quantidade,
         valor_unitario, valor_total, documento, observacao)
      VALUES
        (v_uid, 'ENTRADA', 'COMPRA_FORNECEDOR', v_codigo, btrim(p_produto->>'nome'), v_qtd,
         COALESCE((p_produto->>'valor_compra')::NUMERIC, 0),
         round(v_qtd * COALESCE((p_produto->>'valor_compra')::NUMERIC, 0), 2),
         COALESCE(NULLIF(p_produto->>'documento', ''), NULLIF(p_produto->>'lote', ''), 'ENTRADA-MANUAL'),
         COALESCE(NULLIF(p_produto->>'observacao', ''), 'Cadastro inicial do produto'));
    END IF;
    RETURN jsonb_build_object('criado', true, 'quantidade', v_novo);
  END IF;

  v_delta := CASE WHEN p_modo_quantidade = 'definir' THEN v_qtd - v_prod.quantidade ELSE v_qtd END;
  v_novo  := v_prod.quantidade + v_delta;
  IF v_novo < 0 THEN RAISE EXCEPTION 'ESTOQUE_INSUFICIENTE:%:%', v_codigo, v_prod.quantidade; END IF;

  UPDATE public.produtos SET
    nome           = COALESCE(NULLIF(btrim(p_produto->>'nome'), ''), nome),
    lote           = COALESCE(p_produto->>'lote', lote),
    quantidade     = v_novo,
    valor_compra   = COALESCE((p_produto->>'valor_compra')::NUMERIC, valor_compra),
    markup         = COALESCE((p_produto->>'markup')::NUMERIC, markup),
    valor_venda    = COALESCE((p_produto->>'valor_venda')::NUMERIC, valor_venda),
    origem         = COALESCE(p_produto->>'origem', origem),
    categoria      = COALESCE(p_produto->>'categoria', categoria),
    data_validade  = CASE WHEN p_produto ? 'data_validade'
                          THEN NULLIF(p_produto->>'data_validade', '')::DATE
                          ELSE data_validade END,
    estoque_minimo = COALESCE((p_produto->>'estoque_minimo')::INT, estoque_minimo),
    unidade        = COALESCE(p_produto->>'unidade', unidade),
    ativo          = true
  WHERE id = v_prod.id;

  IF v_delta <> 0 THEN
    INSERT INTO public.movimentacoes_estoque
      (empresa_id, tipo, motivo, produto_codigo, produto_nome, quantidade,
       valor_unitario, valor_total, documento, observacao)
    VALUES
      (v_uid, CASE WHEN v_delta > 0 THEN 'ENTRADA' ELSE 'SAIDA' END, 'AJUSTE_ESTOQUE',
       v_codigo, COALESCE(NULLIF(btrim(p_produto->>'nome'), ''), v_prod.nome), abs(v_delta),
       COALESCE((p_produto->>'valor_compra')::NUMERIC, v_prod.valor_compra, 0),
       round(abs(v_delta) * COALESCE((p_produto->>'valor_compra')::NUMERIC, v_prod.valor_compra, 0), 2),
       COALESCE(NULLIF(p_produto->>'documento', ''), NULLIF(p_produto->>'lote', ''), 'ENTRADA-MANUAL'),
       COALESCE(NULLIF(p_produto->>'observacao', ''),
                CASE WHEN p_modo_quantidade = 'definir' THEN 'Saldo redefinido no cadastro'
                     ELSE 'Entrada somada ao saldo existente' END));
  END IF;

  RETURN jsonb_build_object('criado', false, 'quantidade', v_novo);
END;
$$;

REVOKE ALL ON FUNCTION public.salvar_produto(JSONB, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.salvar_produto(JSONB, TEXT) TO authenticated;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 7b: trazer dados das tabelas antigas (idempotente) ║
-- ╚══════════════════════════════════════════════════════════╝
-- Despesas variáveis antigas passam a ser custos do tipo VARIAVEL.
INSERT INTO public.custos_operacionais (empresa_id, nome, valor, tipo, categoria)
SELECT d.empresa_id, d.nome, d.valor, 'VARIAVEL', 'Geral'
  FROM public.despesas_variaveis d
 WHERE d.empresa_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM public.custos_operacionais c
                    WHERE c.empresa_id = d.empresa_id AND c.nome = d.nome
                      AND c.valor = d.valor AND c.tipo = 'VARIAVEL');

-- Aquisições antigas viram movimentações de entrada (só histórico; NÃO mexe no saldo).
INSERT INTO public.movimentacoes_estoque
  (empresa_id, tipo, motivo, produto_codigo, produto_nome, quantidade,
   valor_unitario, valor_total, documento, observacao, criado_em)
SELECT a.empresa_id, 'ENTRADA', 'COMPRA_FORNECEDOR', a.produto_codigo,
       COALESCE(p.nome, a.produto_codigo), a.quantidade, COALESCE(a.valor_unitario, 0),
       round(a.quantidade * COALESCE(a.valor_unitario, 0), 2),
       'LEGADO-AQ-' || a.id, COALESCE(a.fornecedor, a.observacao, 'Importado do histórico antigo'),
       COALESCE(a.criado_em, a.data_aquisicao::TIMESTAMPTZ, now())
  FROM public.historico_aquisicoes a
  LEFT JOIN public.produtos p ON p.empresa_id = a.empresa_id AND p.codigo = a.produto_codigo
 WHERE a.empresa_id IS NOT NULL AND a.quantidade > 0
   AND NOT EXISTS (SELECT 1 FROM public.movimentacoes_estoque m
                    WHERE m.empresa_id = a.empresa_id AND m.documento = 'LEGADO-AQ-' || a.id);


-- ╔══════════════════════════════════════════════════════════╗
-- ║  PASSO 8: confirmação                                    ║
-- ╚══════════════════════════════════════════════════════════╝
SELECT 'Migração v3 aplicada: código único por loja, venda atômica e movimentações.' AS status;


-- ============================================================
-- PASSO 9 (OPCIONAL, UMA ÚNICA VEZ): converter "total comprado" em "saldo"
-- ============================================================
-- Só rode se, hoje, a coluna `quantidade` dos seus produtos significa "total
-- que eu comprei" e `vendidas` o quanto já saiu (era como o app antigo
-- mostrava: restante = quantidade - vendidas). Depois deste UPDATE,
-- `quantidade` passa a ser o saldo real. Rodar duas vezes DESCONTA EM DOBRO.
--
-- Confira antes:  SELECT codigo, nome, quantidade, vendidas FROM produtos;
-- Se a coluna `quantidade` já é o que está na prateleira, NÃO rode.
--
-- UPDATE public.produtos
--    SET quantidade = GREATEST(quantidade - COALESCE(vendidas, 0), 0)
--  WHERE COALESCE(vendidas, 0) > 0;
