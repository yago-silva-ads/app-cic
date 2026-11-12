-- Execute após migracao_teste_campo.sql, antes de publicar o novo formulário.
-- As respostas antigas permanecem intactas. As notas de facilidade e de
-- recomendação do questionário v2 ficam em respostas, com suas escalas originais.
-- Não convertemos essas notas em satisfação ou recomendação booleana legadas.
BEGIN;
ALTER TABLE public.feedback_campo
  ADD COLUMN IF NOT EXISTS respostas JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.feedback_campo
  ALTER COLUMN nota DROP NOT NULL,
  ALTER COLUMN recomendaria DROP NOT NULL;
COMMIT;
