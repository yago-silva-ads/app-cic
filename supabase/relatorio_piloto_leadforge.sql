-- Relatório somente de leitura para o operador, no SQL Editor administrativo.
-- Não cria objetos, não altera dados e não expõe e-mails, documentos, Pix ou chaves.
-- Metadados de convite são atribuição de campanha, nunca permissão de acesso.
-- Exporte o resultado como CSV para tool/planejar_piloto.py.
WITH semana AS (
  SELECT date_trunc('week', now() AT TIME ZONE 'America/Sao_Paulo')::date AS inicio
), produtos AS (
  SELECT empresa_id, count(DISTINCT codigo) AS produtos
  FROM public.produtos
  WHERE ativo IS DISTINCT FROM false
  GROUP BY empresa_id
), vendas AS (
  SELECT empresa_id,
    count(DISTINCT coalesce(venda_id::text, id::text)) AS vendas_total,
    count(DISTINCT coalesce(venda_id::text, id::text))
      FILTER (WHERE data_venda >= now() - interval '7 days') AS vendas_7d
  FROM public.historico_vendas
  GROUP BY empresa_id
)
SELECT u.raw_user_meta_data ->> 'convite' AS slug,
  greatest(0, (now() AT TIME ZONE 'America/Sao_Paulo')::date
    - (u.created_at AT TIME ZONE 'America/Sao_Paulo')::date) AS dias_cadastro,
  coalesce(p.produtos, 0) AS produtos,
  coalesce(v.vendas_total, 0) AS vendas_total,
  coalesce(v.vendas_7d, 0) AS vendas_7d,
  (f.id IS NOT NULL) AS feedback_semana,
  f.nota,
  coalesce(f.interesse_site, 'nao_agora') AS interesse_site
FROM auth.users u
CROSS JOIN semana s
LEFT JOIN produtos p ON p.empresa_id = u.id
LEFT JOIN vendas v ON v.empresa_id = u.id
LEFT JOIN public.feedback_campo f ON f.empresa_id = u.id AND f.semana_inicio = s.inicio
WHERE u.raw_user_meta_data ->> 'origem' = 'leadforge'
  AND u.raw_user_meta_data ->> 'convite' ~ '^[a-z0-9-]{1,80}$'
ORDER BY dias_cadastro DESC, slug;
