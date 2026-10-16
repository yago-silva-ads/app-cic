-- Cota persistente do assistente: uma reserva atômica por usuário e minuto.
-- Aplicar antes de publicar a versão da Edge Function que usa a RPC.
-- A tabela fica fora do schema exposto pelo PostgREST e não tem policies:
-- somente esta função SECURITY DEFINER pode acessá-la.

BEGIN;

CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.ia_uso (
  empresa_id UUID NOT NULL,
  janela TIMESTAMPTZ NOT NULL,
  total INT NOT NULL CHECK (total >= 0),
  PRIMARY KEY (empresa_id, janela)
);

CREATE INDEX IF NOT EXISTS ia_uso_janela_idx ON private.ia_uso (janela);
ALTER TABLE private.ia_uso ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.ia_uso FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.reservar_cota_ia(p_limite INT)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, private, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_agora TIMESTAMPTZ := clock_timestamp();
  v_janela TIMESTAMPTZ := date_trunc('minute', v_agora);
  -- A RPC é chamável pelo usuário: ele nunca pode aumentar a cota pelo parâmetro.
  v_limite INT := LEAST(GREATEST(COALESCE(p_limite, 12), 1), 12);
  v_total INT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'SEM_SESSAO' USING ERRCODE = '28000';
  END IF;

  -- Índice por janela evita varrer toda a tabela; mantém no máximo um dia.
  DELETE FROM private.ia_uso WHERE janela < v_agora - INTERVAL '1 day';

  INSERT INTO private.ia_uso AS uso (empresa_id, janela, total)
  VALUES (v_uid, v_janela, 1)
  ON CONFLICT (empresa_id, janela) DO UPDATE
    -- Teto fixo e monotônico: uma chamada direta com p_limite menor não pode
    -- diminuir o contador de uma reserva anterior.
    SET total = LEAST(uso.total + 1, 13)
  RETURNING total INTO v_total;

  IF v_total <= v_limite THEN
    RETURN 0;
  END IF;
  RETURN GREATEST(
    1,
    CEIL(EXTRACT(EPOCH FROM (v_janela + INTERVAL '1 minute' - v_agora)))::INT
  );
END;
$$;

REVOKE ALL ON FUNCTION public.reservar_cota_ia(INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reservar_cota_ia(INT) TO authenticated;

COMMIT;
