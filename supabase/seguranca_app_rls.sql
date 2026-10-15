-- Reforça o isolamento por loja SEM alterar migrations anteriores e SEM afrouxar regras existentes.
--
-- Modelo do APP-CIC: empresa_id = auth.uid() do lojista (DEFAULT auth.uid() nas tabelas).
-- O que este script faz, para toda tabela pública com empresa_id, user_id ou owner_id:
--   1. liga RLS (se estiver desligado, qualquer usuário logado leria tudo);
--   2. se a tabela NÃO tem nenhuma policy, cria a policy de dono (lê/grava só a própria loja).
-- O que ele NÃO faz (de propósito):
--   - não apaga policies existentes. Ex.: movimentacoes_estoque é um livro-razão só de
--     leitura e inserção; uma policy FOR ALL abriria UPDATE/DELETE e permitiria adulterar
--     o histórico de estoque.
-- Tabelas de negócio sem coluna de dono aparecem como AVISO para revisão manual.
DO $$
DECLARE
  tabela RECORD;
<<<<<<< HEAD
  sem_dono TEXT;
=======
  coluna_dono TEXT;
>>>>>>> seguranca-codex2
BEGIN
  SELECT string_agg(c.relname, ', ') INTO sem_dono
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind IN ('r', 'p')
    AND c.relname ~* '(produto|estoque|venda|cliente|caixa|custo|alerta|relatorio|movimentacao)'
    AND NOT EXISTS (
      SELECT 1 FROM pg_attribute a
      WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
        AND a.attname IN ('empresa_id', 'user_id', 'owner_id')
    );
  IF sem_dono IS NOT NULL THEN
    RAISE WARNING 'Revise manualmente (tabela de negócio sem coluna de dono): %', sem_dono;
  END IF;

  FOR tabela IN
    SELECT c.oid, c.relname,
      CASE
        WHEN bool_or(a.attname = 'empresa_id') THEN 'empresa_id'
        WHEN bool_or(a.attname = 'user_id') THEN 'user_id'
        ELSE 'owner_id'
      END AS coluna_dono,
      EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid) AS tem_policy
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p')
      AND a.attname IN ('empresa_id', 'user_id', 'owner_id')
      AND (
        a.attname = 'empresa_id'
        OR c.relname ~* '(produto|estoque|venda|cliente|caixa|loja|custo|alerta|relatorio|movimentacao)'
      )
    GROUP BY c.oid, c.relname
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tabela.relname);
<<<<<<< HEAD
    IF NOT tabela.tem_policy THEN
      EXECUTE format(
        'CREATE POLICY seguranca_app_tenant ON public.%I FOR ALL TO authenticated USING (%I = auth.uid()) WITH CHECK (%I = auth.uid())',
        tabela.relname, tabela.coluna_dono, tabela.coluna_dono
      );
      RAISE NOTICE 'Policy de dono criada em %', tabela.relname;
    END IF;
=======

    -- Uma policy RESTRICTIVE combina por AND com as permissivas existentes.
    -- Assim, restringe o tenant sem ampliar operações (p.ex. DELETE de vendas).
    EXECUTE format('DROP POLICY IF EXISTS seguranca_app_tenant ON public.%I', tabela.relname);
    EXECUTE format(
      'CREATE POLICY seguranca_app_tenant ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (%I = auth.uid()) WITH CHECK (%I = auth.uid())',
      tabela.relname, coluna_dono, coluna_dono
    );
>>>>>>> seguranca-codex2
  END LOOP;
END;
$$;
