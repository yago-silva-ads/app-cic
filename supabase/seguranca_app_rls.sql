-- Reforca o isolamento por loja sem alterar migrations anteriores.
-- Todas as tabelas de negocio protegidas devem identificar o tenant por uma
-- coluna empresa_id, user_id ou owner_id cujo valor corresponda a auth.uid().
DO $$
DECLARE
  tabela RECORD;
  coluna_dono TEXT;
  politica RECORD;
BEGIN
  -- Falha explicitamente se surgir uma tabela de negocio sem chave de dono;
  -- nao habilita RLS silenciosamente deixando os dados inacessiveis ou abertos.
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p')
      AND c.relname ~* '(produto|estoque|venda|cliente|caixa|loja|custo|alerta|relatorio|movimentacao)'
      AND NOT EXISTS (
        SELECT 1 FROM pg_attribute a
        WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
          AND a.attname IN ('empresa_id', 'user_id', 'owner_id')
      )
  ) THEN
    RAISE EXCEPTION 'Tabela de negocio sem empresa_id, user_id ou owner_id. Defina a relacao com auth.uid() antes de aplicar RLS.';
  END IF;

  FOR tabela IN
    SELECT c.oid, c.relname,
      CASE
        WHEN bool_or(a.attname = 'empresa_id') THEN 'empresa_id'
        WHEN bool_or(a.attname = 'user_id') THEN 'user_id'
        ELSE 'owner_id'
      END AS coluna_dono
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p')
      AND a.attname IN ('empresa_id', 'user_id', 'owner_id')
    GROUP BY c.oid, c.relname
  LOOP
    coluna_dono := tabela.coluna_dono;
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tabela.relname);

    -- Remove policies antigas para impedir que policies permissivas se somem
    -- por OR e reabram acesso a linhas de outras lojas.
    FOR politica IN
      SELECT p.polname FROM pg_policy p WHERE p.polrelid = tabela.oid
    LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', politica.polname, tabela.relname);
    END LOOP;

    EXECUTE format(
      'CREATE POLICY seguranca_app_tenant ON public.%I FOR ALL TO authenticated USING (%I = auth.uid()) WITH CHECK (%I = auth.uid())',
      tabela.relname, coluna_dono, coluna_dono
    );
  END LOOP;
END;
$$;
