-- Reforça o isolamento por loja SEM alterar migrations anteriores e SEM ampliar permissões.
--
-- Modelo do APP-CIC: empresa_id = auth.uid() do lojista (DEFAULT auth.uid() nas tabelas).
-- Para toda tabela de negócio com coluna de dono (empresa_id, ou user_id/owner_id em tabelas de negócio):
--   1. liga RLS;
--   2. cria `seguranca_app_tenant` AS RESTRICTIVE: combina por AND com as policies que já existem.
--      Restringe à própria loja sem abrir operações novas (o histórico movimentacoes_estoque
--      continua só leitura/inserção; DELETE de vendas continua proibido se já era).
--   3. se a tabela não tem NENHUMA policy permissiva, cria `seguranca_app_dono` (permissiva, só a
--      própria loja). Sem isso, a RESTRICTIVE sozinha bloquearia até o dono, porque o Postgres
--      exige ao menos uma policy permissiva para liberar qualquer linha.
-- Nenhuma policy existente é apagada. Pode rodar mais de uma vez.
DO $$
DECLARE
  tabela RECORD;
  sem_dono TEXT;
BEGIN
  SELECT string_agg(c.relname, ', ') INTO sem_dono
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind IN ('r', 'p')
    AND c.relname ~* '(produto|estoque|venda|cliente|caixa|loja|custo|alerta|relatorio|movimentacao)'
    AND NOT EXISTS (
      SELECT 1 FROM pg_attribute a
      WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
        AND a.attname IN ('empresa_id', 'user_id', 'owner_id')
    );
  IF sem_dono IS NOT NULL THEN
    -- Aviso em vez de abortar: o restante da blindagem é aplicado e a tabela fica para revisão manual.
    RAISE WARNING 'Revise manualmente (tabela de negócio sem coluna de dono): %', sem_dono;
  END IF;

  FOR tabela IN
    SELECT c.oid, c.relname,
      CASE
        WHEN bool_or(a.attname = 'empresa_id') THEN 'empresa_id'
        WHEN bool_or(a.attname = 'user_id') THEN 'user_id'
        ELSE 'owner_id'
      END AS coluna_dono,
      EXISTS (
        SELECT 1 FROM pg_policy p
        WHERE p.polrelid = c.oid AND p.polpermissive AND p.polname <> 'seguranca_app_dono'
      ) AS tem_permissiva
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

    EXECUTE format('DROP POLICY IF EXISTS seguranca_app_tenant ON public.%I', tabela.relname);
    EXECUTE format(
      'CREATE POLICY seguranca_app_tenant ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (%I = auth.uid()) WITH CHECK (%I = auth.uid())',
      tabela.relname, tabela.coluna_dono, tabela.coluna_dono
    );

    IF NOT tabela.tem_permissiva THEN
      EXECUTE format('DROP POLICY IF EXISTS seguranca_app_dono ON public.%I', tabela.relname);
      EXECUTE format(
        'CREATE POLICY seguranca_app_dono ON public.%I FOR ALL TO authenticated USING (%I = auth.uid()) WITH CHECK (%I = auth.uid())',
        tabela.relname, tabela.coluna_dono, tabela.coluna_dono
      );
      RAISE NOTICE 'Tabela % não tinha policy permissiva: criada seguranca_app_dono', tabela.relname;
    END IF;
  END LOOP;
END;
$$;
