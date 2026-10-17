-- APP-CIC: logística reversa com baixa atômica e histórico do motivo/destino.
CREATE TABLE IF NOT EXISTS public.logistica_reversa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL DEFAULT auth.uid(),
  produto_codigo TEXT NOT NULL,
  quantidade INT NOT NULL CHECK (quantidade > 0),
  motivo TEXT NOT NULL CHECK (motivo IN ('Devolução ao fornecedor', 'Produto avariado', 'Produto vencido', 'Recall')),
  destino TEXT NOT NULL CHECK (destino IN ('Fornecedor', 'Descarte', 'Assistência técnica', 'Transportadora')),
  documento TEXT,
  observacao TEXT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.logistica_reversa ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS logistica_reversa_select_own ON public.logistica_reversa;
CREATE POLICY logistica_reversa_select_own ON public.logistica_reversa FOR SELECT TO authenticated USING (empresa_id = auth.uid());

CREATE OR REPLACE FUNCTION public.registrar_logistica_reversa(
  p_codigo TEXT,
  p_quantidade INT,
  p_motivo TEXT,
  p_destino TEXT,
  p_documento TEXT DEFAULT NULL,
  p_observacao TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_prod public.produtos%ROWTYPE;
  v_id UUID := gen_random_uuid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'SEM_SESSAO'; END IF;
  IF p_quantidade IS NULL OR p_quantidade <= 0 THEN RAISE EXCEPTION 'ITEM_INVALIDO:quantidade'; END IF;
  IF p_motivo NOT IN ('Devolução ao fornecedor', 'Produto avariado', 'Produto vencido', 'Recall') THEN RAISE EXCEPTION 'ITEM_INVALIDO:motivo'; END IF;
  IF p_destino NOT IN ('Fornecedor', 'Descarte', 'Assistência técnica', 'Transportadora') THEN RAISE EXCEPTION 'ITEM_INVALIDO:destino'; END IF;
  SELECT * INTO v_prod FROM public.produtos WHERE empresa_id = v_uid AND codigo = btrim(p_codigo) AND COALESCE(ativo, true) FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PRODUTO_NAO_ENCONTRADO:%', p_codigo; END IF;
  IF v_prod.quantidade < p_quantidade THEN RAISE EXCEPTION 'ESTOQUE_INSUFICIENTE:%:%', v_prod.codigo, v_prod.quantidade; END IF;
  UPDATE public.produtos SET quantidade = quantidade - p_quantidade WHERE empresa_id = v_uid AND codigo = v_prod.codigo;
  INSERT INTO public.logistica_reversa (id, empresa_id, produto_codigo, quantidade, motivo, destino, documento, observacao)
    VALUES (v_id, v_uid, v_prod.codigo, p_quantidade, p_motivo, p_destino, NULLIF(btrim(p_documento), ''), NULLIF(btrim(p_observacao), ''));
  INSERT INTO public.movimentacoes_estoque (empresa_id, tipo, motivo, produto_codigo, produto_nome, quantidade, valor_unitario, valor_total, documento, observacao)
    VALUES (v_uid, 'SAIDA', 'DEVOLUCAO', v_prod.codigo, v_prod.nome, p_quantidade, COALESCE(v_prod.valor_compra, 0), round(p_quantidade * COALESCE(v_prod.valor_compra, 0), 2), p_documento, concat_ws(' • ', p_motivo, p_destino, NULLIF(btrim(p_observacao), '')));
  RETURN jsonb_build_object('id', v_id, 'codigo', v_prod.codigo, 'quantidade', p_quantidade, 'saldo', v_prod.quantidade - p_quantidade);
END;
$$;
REVOKE ALL ON FUNCTION public.registrar_logistica_reversa(TEXT, INT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_logistica_reversa(TEXT, INT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
