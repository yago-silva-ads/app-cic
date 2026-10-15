# Modelo de dados e isolamento por loja

Modelo reconstruído dos SQLs versionados em `supabase/`, considerando a evolução v3. Não é uma exportação do banco em produção. Os `CREATE TABLE` originais de `produtos`, `historico_vendas` e `custos_operacionais` não estão nesta base; seus campos aparecem em alterações, funções, índices e consultas.

No diagrama, `desconhecido` indica tipo não comprovado pelo DDL local. Não foi atribuída PK a `historico_vendas` ou `custos_operacionais` sem evidência da definição original. A migração garante `produtos.id` como PK, mas preserva seu tipo se já existir; cria UUID apenas quando falta a coluna.

```mermaid
erDiagram
    produtos ||--o{ historico_vendas : "FK composta empresa_id e codigo"

    produtos {
        desconhecido id PK "UUID quando criado pela v3; tipo anterior preservado"
        uuid empresa_id UK "Parte da UNIQUE composta; auth.uid()"
        text codigo UK "Parte da UNIQUE composta"
        text nome
        text lote
        int quantidade "Saldo atual"
        numeric valor_compra
        numeric markup
        numeric valor_venda
        text origem
        date data_validade
        date data_entrada
        int estoque_minimo
        text categoria
        text unidade
        boolean ativo
        int vendidas
        timestamptz updated_at
    }
    historico_vendas {
        uuid empresa_id FK "Parte da FK composta; auth.uid()"
        text produto_codigo FK "Parte da FK composta"
        int quantidade_vendida
        numeric valor_unitario
        desconhecido data_venda "Tipo temporal original nao versionado"
        numeric lucro_unitario
        text metodo_pagamento
        text vendedor_nome
        numeric desconto
        uuid venda_id "Agrupa linhas da mesma venda; sem FK declarada"
        text nome_produto
        numeric custo_unitario
    }
    custos_operacionais {
        uuid empresa_id "auth.uid()"
        text nome
        numeric valor
        text tipo
        text categoria
        text observacao
    }
    movimentacoes_estoque {
        uuid id PK
        uuid empresa_id "auth.uid()"
        text tipo "ENTRADA ou SAIDA"
        text motivo
        text produto_codigo "Referencia logica; sem FK declarada"
        text produto_nome
        int quantidade "Maior que zero"
        numeric valor_unitario
        numeric valor_total
        text documento
        text observacao
        uuid venda_id "Referencia logica; sem FK declarada"
        timestamptz criado_em
    }
    contas_estabelecimento {
        uuid empresa_id PK "auth.uid()"
        jsonb dados
        timestamptz atualizado_em
    }
    sessoes_caixa {
        uuid id PK
        uuid empresa_id "auth.uid()"
        text status "ABERTO ou FECHADO"
        jsonb dados
        timestamptz aberta_em
        timestamptz fechada_em
    }
    alertas_sistema {
        bigint id PK "BIGSERIAL"
        uuid empresa_id "auth.uid()"
        text tipo
        text produto_codigo "Opcional; sem FK declarada"
        text mensagem
        text severidade
        boolean lido
        timestamptz criado_em
    }
    relatorios_ia {
        bigint id PK "BIGSERIAL"
        uuid empresa_id "auth.uid()"
        text tipo
        text conteudo_markdown
        jsonb metricas
        timestamptz criado_em
    }
```

`UK` em `produtos` representa uma única constraint `UNIQUE (empresa_id, codigo)`, não duas unicidades independentes. Campos legados como nome, quantidade e valores têm tipos lógicos deduzidos dos usos SQL; precisão e restrições originais exigem conferir o schema implantado. O app também usa `custos_operacionais.id`, mas o DDL desse identificador não está nos SQLs locais, portanto sua chave e tipo não são afirmados no desenho.

## Relações e integridade

- `historico_vendas (empresa_id, produto_codigo)` referencia `produtos (empresa_id, codigo)` com `ON DELETE RESTRICT`. Um código de barras pode existir em lojas diferentes. Produtos com histórico podem ser arquivados em vez de apagados.
- `venda_id` agrupa linhas do histórico e movimentos gerados na mesma venda. Não existe `CREATE TABLE vendas` nesses SQLs.
- `movimentacoes_estoque.produto_codigo` e `alertas_sistema.produto_codigo` são referências lógicas; os respectivos `CREATE TABLE` não declaram FK para produtos.
- As oito tabelas usam `empresa_id` para isolamento. Isso não constitui uma FK automaticamente: não foi encontrada declaração de FK para `auth.users` nesses SQLs.
- Não há tabela relacional de clientes ou lotes declarada nos SQLs locais. Não confundir o objeto Dart `Lote` com uma tabela existente.

## RLS e operações

O modelo atual associa a loja ao usuário autenticado: `empresa_id = auth.uid()`. Um `DEFAULT auth.uid()` ajuda a preencher a coluna, mas o controle de acesso vem das políticas `USING` e `WITH CHECK`, das permissões e da validação nas funções. Não há aqui um modelo de múltiplos funcionários por associação a uma empresa separada.

| Operação | Implementação nos SQLs |
| --- | --- |
| Leitura da loja | RLS compara `empresa_id` com `auth.uid()` |
| Venda | `registrar_venda` valida sessão/itens, trava produto, baixa saldo e grava histórico/movimento na mesma transação |
| Ajuste de saldo | `ajustar_estoque` valida loja e saldo e registra movimentação |
| Cadastro e atualização | `salvar_produto` usa a loja do JWT e registra diferença de estoque |
| Movimento histórico | v3 oferece políticas SELECT/INSERT, sem UPDATE/DELETE |
| Perfil e caixa | `contas_estabelecimento` e `sessoes_caixa` têm políticas SELECT/INSERT/UPDATE por dono |

As RPCs de escrita são `SECURITY DEFINER` com `search_path` fixo e filtro explícito por usuário. A RLS isoladamente não substitui essa validação interna. Os scripts são evolutivos: executar novamente uma política antiga permissiva pode reabrir acesso; conferir o estado final após aplicar migrações.

## Views e fontes

As views `vw_kpis_vendas_mes`, `vw_top_produtos_mes`, `vw_produtos_validade_critica`, `vw_produtos_estoque_baixo` e `vw_faturamento_mensal` são projeções, não tabelas adicionais. O script de blindagem trata a segurança das views e políticas.

| Fonte local | Evidência principal |
| --- | --- |
| [Schema v2](../../supabase/schema_evolucao_v2.sql) | Colunas evolutivas, alertas, relatórios, views e índices |
| [Migração v3](../../supabase/migracao_v3_estoque_atomico_e_isolamento.sql) | PK de produto, UNIQUE/FK compostas, movimentos, conta, caixa e RPCs |
| [RLS inicial](../../supabase/rls_migration.sql) | Isolamento de produtos, histórico e custos |
| [RLS de custos](../../supabase/rls_custos_operacionais.sql) | Políticas de custos |
| [RLS de novas tabelas](../../supabase/rls_novas_tabelas.sql) | Alertas e relatórios |
| [Blindagem de views](../../supabase/blindagem_views_e_rls.sql) | Proteção de consultas derivadas |
| [Triggers](../../supabase/triggers_inteligentes_v2.sql) | Automatismos de negócio |

O arquivo legado `limpeza_e_trava_not_null.sql` contém exclusões e uma FK antiga somente por código com cascata. Ele não descreve a relação final v3 e não deve ser executado cegamente depois dela. Para um ambiente novo, obter primeiro o schema inicial das três tabelas legadas e revisar a ordem dos scripts; esta documentação não promete um bootstrap completo a partir deles.
