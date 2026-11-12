-- Execute após migracao_teste_campo.sql.
-- Permite novos envios na mesma semana sem substituir respostas anteriores.
BEGIN;
DROP INDEX IF EXISTS public.feedback_campo_uma_resposta_por_semana;
CREATE INDEX IF NOT EXISTS feedback_campo_empresa_semana
  ON public.feedback_campo (empresa_id, semana_inicio);
COMMIT;
