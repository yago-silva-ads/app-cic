-- ============================================================
-- App-CIC: Limpeza de Legado e Trava de Segurança (Corrigido)
-- ============================================================
-- INSTRUÇÕES:
--   Cole e rode este script no Supabase SQL Editor.
--   A ordem de exclusão foi ajustada para respeitar as chaves
--   estrangeiras (historico_vendas antes de produtos).
-- ============================================================

-- 1. Apagar PRIMEIRO o histórico de vendas (tabela filha) para não violar Foreign Key
DELETE FROM historico_vendas 
WHERE empresa_id IS NULL 
   OR produto_codigo IN (SELECT codigo FROM produtos WHERE empresa_id IS NULL);

-- 2. Apagar em seguida os produtos (tabela pai) e custos sem dono
DELETE FROM produtos WHERE empresa_id IS NULL;
DELETE FROM custos_operacionais WHERE empresa_id IS NULL;


-- 3. Atualizar a Foreign Key para ON DELETE CASCADE (Opcional e Recomendado)
-- Assim, quando um lojista deletar um produto no futuro, as vendas daquele
-- produto somem sem dar erro de chave estrangeira no aplicativo.
ALTER TABLE historico_vendas 
  DROP CONSTRAINT IF EXISTS historico_vendas_produto_codigo_fkey;

ALTER TABLE historico_vendas 
  ADD CONSTRAINT historico_vendas_produto_codigo_fkey 
  FOREIGN KEY (produto_codigo) 
  REFERENCES produtos (codigo) 
  ON DELETE CASCADE;


-- 4. Travar a coluna empresa_id com NOT NULL (Blindagem Absoluta)
ALTER TABLE produtos ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE historico_vendas ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE custos_operacionais ALTER COLUMN empresa_id SET NOT NULL;


-- 5. Confirmação
SELECT 'Limpeza de legado concluída e trava NOT NULL aplicada com sucesso!' AS status;
