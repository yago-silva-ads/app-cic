# Auditoria de produto e plano de implementação

## Achados corrigidos

| Área | Risco observado | Tratamento |
|---|---|---|
| Posicionamento | A mensagem podia parecer uma venda de site antes de provar valor no negócio | Banner de teste de campo gratuito dentro da Inteligência IA |
| Pesquisa | Feedback dependia de conversa externa e podia ser perdido | Formulário semanal persistido por tenant, com texto opcional |
| Preço | IA poderia inventar preços ou recomendar alteração sem fonte | Busca no servidor + ofertas com URL/data + cálculo determinístico |
| Margem | Seguir a mediana poderia vender abaixo do custo | Piso de 20% de margem quando o custo existe |
| Dados | Uma oferta isolada não representa o mercado | Mínimo de duas ofertas; caso contrário, revisar dados |
| Privacidade | Pesquisa comercial poderia misturar dados de lojas | RLS em `feedback_campo`; estoque permanece no tenant |

## Pendências antes da escala

1. Criar o secret `BRAVE_SEARCH_API_KEY` no Supabase e publicar `analise-mercado`.
2. Executar `supabase/migracao_teste_campo.sql` após as migrations base.
3. Configurar limite de chamadas e cache por produto para não exceder a cota do buscador.
4. Revisar fontes e bloquear marketplaces que retornem preço sem unidade comparável.
5. Adicionar webhook assinado do interesse em site para o LeadForge.
6. Testar com produtos de categorias diferentes e medir falsos positivos de preço.

## Critérios de aceite

- O app continua respondendo com estoque e auditoria quando a busca externa está indisponível.
- O resultado mostra ação, preço atual, preço sugerido, mediana, número de ofertas e fontes.
- Nenhuma recomendação substitui automaticamente o preço cadastrado.
- Cada loja pode enviar no máximo um feedback por semana.
- O interesse em site é opcional e não altera o acesso ao app gratuito.
- O build não contém chaves de buscador ou de IA.
