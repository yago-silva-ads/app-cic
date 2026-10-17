-- APP-CIC: criptografia em repouso dos dados sensíveis da conta do estabelecimento.
--
-- Documento (CNPJ/CPF), inscrição estadual, telefone, e-mail, dados do Pix e
-- dados bancários saem do JSON aberto `dados` e vão para `dados_cifrados`
-- (pgcrypto, AES-256). A chave fica no Supabase Vault, nunca no app nem no
-- repositório. O app lê e grava pelas RPCs minha_conta() / salvar_minha_conta();
-- quem ler a tabela diretamente (painel, export, backup vazado) vê só o texto cifrado.
--
-- Aplicar depois de migracao_v3_estoque_atomico_e_isolamento.sql. Idempotente.
-- Rotação de chave: ver o bloco comentado no fim do arquivo.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE SCHEMA IF NOT EXISTS private;

-- Chave gerada no próprio banco: 32 bytes aleatórios, guardados cifrados pelo Vault.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'app_cic_chave_conta') THEN
    PERFORM vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'app_cic_chave_conta',
      'Chave AES dos dados sensíveis de contas_estabelecimento'
    );
  END IF;
END $$;

ALTER TABLE public.contas_estabelecimento ADD COLUMN IF NOT EXISTS dados_cifrados BYTEA;

CREATE OR REPLACE FUNCTION private.chave_conta()
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_chave TEXT;
BEGIN
  SELECT decrypted_secret INTO v_chave FROM vault.decrypted_secrets WHERE name = 'app_cic_chave_conta';
  IF v_chave IS NULL OR length(v_chave) < 32 THEN
    RAISE EXCEPTION 'CHAVE_CONTA_AUSENTE' USING ERRCODE = '28000';
  END IF;
  RETURN v_chave;
END;
$$;

REVOKE ALL ON FUNCTION private.chave_conta() FROM PUBLIC, anon, authenticated;

-- Campos sensíveis (chaves de primeiro nível do JSON gravado por ContaEstabelecimento.toJson).
CREATE OR REPLACE FUNCTION private.campos_sensiveis_conta()
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT ARRAY['documentoNumero', 'inscricaoEstadual', 'telefone', 'email', 'dadosPix', 'dadosBancarios']
$$;

-- Antes de gravar: separa os campos sensíveis e cifra. Campos omitidos numa
-- gravação parcial continuam com o valor que já estava no cofre.
CREATE OR REPLACE FUNCTION private.fn_cifrar_conta()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_campos TEXT[] := private.campos_sensiveis_conta();
  v_sensiveis JSONB := '{}'::jsonb;
  v_anteriores JSONB := '{}'::jsonb;
  v_campo TEXT;
BEGIN
  FOREACH v_campo IN ARRAY v_campos LOOP
    IF NEW.dados ? v_campo THEN
      v_sensiveis := v_sensiveis || jsonb_build_object(v_campo, NEW.dados -> v_campo);
    END IF;
  END LOOP;

  IF v_sensiveis = '{}'::jsonb THEN
    IF TG_OP = 'UPDATE' THEN
      NEW.dados_cifrados := OLD.dados_cifrados;
    END IF;
    RETURN NEW;
  END IF;

  -- Quem zera dados_cifrados na mesma gravação (rotação de chave) envia tudo de novo.
  IF TG_OP = 'UPDATE' AND OLD.dados_cifrados IS NOT NULL
     AND NEW.dados_cifrados IS NOT DISTINCT FROM OLD.dados_cifrados THEN
    v_anteriores := extensions.pgp_sym_decrypt(OLD.dados_cifrados, private.chave_conta())::jsonb;
  END IF;

  NEW.dados := NEW.dados - v_campos;
  NEW.dados_cifrados := extensions.pgp_sym_encrypt(
    (v_anteriores || v_sensiveis)::text,
    private.chave_conta(),
    'cipher-algo=aes256, compress-algo=0'
  );
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.fn_cifrar_conta() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_cifrar_conta ON public.contas_estabelecimento;
CREATE TRIGGER trg_cifrar_conta
  BEFORE INSERT OR UPDATE OF dados ON public.contas_estabelecimento
  FOR EACH ROW EXECUTE FUNCTION private.fn_cifrar_conta();

-- Leitura: só a própria loja (auth.uid()), já decifrada.
CREATE OR REPLACE FUNCTION public.minha_conta()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_dados JSONB;
  v_cifrados BYTEA;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'SEM_SESSAO' USING ERRCODE = '28000';
  END IF;
  SELECT c.dados, c.dados_cifrados INTO v_dados, v_cifrados
    FROM public.contas_estabelecimento c WHERE c.empresa_id = v_uid;
  IF NOT FOUND THEN
    RETURN '{}'::jsonb;
  END IF;
  IF v_cifrados IS NULL THEN
    RETURN COALESCE(v_dados, '{}'::jsonb);
  END IF;
  RETURN COALESCE(v_dados, '{}'::jsonb)
      || extensions.pgp_sym_decrypt(v_cifrados, private.chave_conta())::jsonb;
END;
$$;

-- Gravação: sempre na linha da própria loja; o gatilho cifra antes de salvar.
CREATE OR REPLACE FUNCTION public.salvar_minha_conta(p_dados JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'SEM_SESSAO' USING ERRCODE = '28000';
  END IF;
  IF p_dados IS NULL OR jsonb_typeof(p_dados) <> 'object' THEN
    RAISE EXCEPTION 'CONTA_INVALIDA' USING ERRCODE = '22023';
  END IF;
  IF octet_length(p_dados::text) > 65536 THEN
    RAISE EXCEPTION 'CONTA_GRANDE_DEMAIS' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.contas_estabelecimento AS c (empresa_id, dados, atualizado_em)
  VALUES (v_uid, p_dados, now())
  ON CONFLICT (empresa_id) DO UPDATE
    SET dados = EXCLUDED.dados, atualizado_em = EXCLUDED.atualizado_em;
END;
$$;

REVOKE ALL ON FUNCTION public.minha_conta() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.salvar_minha_conta(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.minha_conta() TO authenticated;
GRANT EXECUTE ON FUNCTION public.salvar_minha_conta(JSONB) TO authenticated;

-- Cifra o que já existe (o gatilho roda no UPDATE de `dados`).
UPDATE public.contas_estabelecimento SET dados = dados
 WHERE dados ?| private.campos_sensiveis_conta();

COMMIT;

-- Conferência depois de aplicar (deve voltar 0):
--   SELECT count(*) FROM public.contas_estabelecimento WHERE dados ?| private.campos_sensiveis_conta();
--
-- Rotação de chave (SQL Editor, numa transação só):
--   CREATE TEMP TABLE t AS SELECT empresa_id,
--     extensions.pgp_sym_decrypt(dados_cifrados, private.chave_conta())::jsonb AS s
--     FROM public.contas_estabelecimento WHERE dados_cifrados IS NOT NULL;
--   SELECT vault.update_secret((SELECT id FROM vault.secrets WHERE name = 'app_cic_chave_conta'),
--                              encode(extensions.gen_random_bytes(32), 'hex'));
--   UPDATE public.contas_estabelecimento c SET dados_cifrados = NULL, dados = c.dados || t.s
--     FROM t WHERE t.empresa_id = c.empresa_id;
