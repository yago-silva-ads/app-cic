# Estrutura do Banco (Supabase)

O aplicativo usa o [Supabase](https://supabase.com/) como Backend-as-a-Service, consumindo PostgreSQL via REST API (SDK).

## Arquitetura Multi-Tenant
Todas as tabelas do banco contêm a coluna `empresa_id` (que mapeia para o `auth.uid()` do usuário autenticado).
Nenhum usuário de uma empresa jamais verá os dados de vendas da outra.

## Arquivo de Integração
Todas as conexões passam exclusivamente pelo arquivo:
`lib/services/supabase_helper.dart`

## Políticas RLS (Row Level Security)
Ao configurar o banco no Painel do Supabase, certifique-se de que cada tabela tenha a política:
```sql
CREATE POLICY "Permitir leitura/escrita apenas para a propria empresa" ON "produtos"
  FOR ALL
  TO authenticated
  USING (empresa_id = auth.uid());
```

## Blindagem do Código (Try/Catch)
**Padrão vital**: Nunca dispare um `await supabase.from()` sem envolvê-lo em um bloco `try / catch`. O aplicativo não pode crashar caso falte internet ou haja bug no RLS. Em falha, a função deve estourar o erro suavemente (ex: print do console) e retornar dados vazios (ex: `[]`).
