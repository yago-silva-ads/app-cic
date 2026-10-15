-- Fecha as funções SECURITY DEFINER antigas (revisão de segurança do Codex, prioridade 3).
--
-- As três funções de cron mexem em TODAS as lojas e estavam liberadas para qualquer um com a chave
-- pública (POST /rest/v1/rpc/...). Os jobs do pg_cron rodam como `postgres` (dono), então continuam
-- funcionando. As funções de trigger não podem ser chamadas pela API; só ganham search_path fixo.
-- Idempotente: pode rodar de novo sem efeito colateral.

revoke execute on function public.fn_cron_varrer_validades() from public, anon, authenticated;
revoke execute on function public.fn_cron_limpar_alertas_antigos() from public, anon, authenticated;
revoke execute on function public.fn_cron_snapshot_kpis() from public, anon, authenticated;

alter function public.fn_cron_varrer_validades() set search_path = pg_catalog, public, pg_temp;
alter function public.fn_cron_limpar_alertas_antigos() set search_path = pg_catalog, public, pg_temp;
alter function public.fn_cron_snapshot_kpis() set search_path = pg_catalog, public, pg_temp;
alter function public.fn_alerta_estoque_baixo() set search_path = pg_catalog, public, pg_temp;
alter function public.fn_alerta_prejuizo_produto() set search_path = pg_catalog, public, pg_temp;
alter function public.fn_alerta_validade() set search_path = pg_catalog, public, pg_temp;
alter function public.fn_calcular_lucro_venda() set search_path = pg_catalog, public, pg_temp;
alter function public.fn_qa_injetar_e_validar_tenant() set search_path = pg_catalog, public, pg_temp;
