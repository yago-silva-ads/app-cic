# Arquitetura do APP-CIC

Documentação baseada no commit local `643fdd6` de `redesign-aistudio`, sem consulta ao banco em produção. Os diagramas Mermaid são renderizados pelo GitHub ao abrir os arquivos Markdown.

| Diagrama | O que explica |
| --- | --- |
| [Casos de uso](casos-de-uso.md) | Rotina do lojista e funcionalidades |
| [Componentes](componentes.md) | Flutter, domínio, Supabase e provedores de IA |
| [Sequência do assistente](sequencia-assistente.md) | Cálculos, consulta de IA, aterramento e fallback |
| [Classes do domínio](classes-dominio.md) | Estoque, vendas, ABC e contratos de IA |
| [Modelo de dados](modelo-de-dados.md) | Tabelas, chaves e isolamento por loja |

## Estado da documentação

- **Confirmado nesta base:** regras locais de estoque, validade, atenção, custos e ABC; consulta autenticada à Edge Function; validação de aterramento e resposta calculada em caso de falha.
- **Integração do branch `ia-gratis`, informada pelo responsável:** previsão por média móvel de 30 dias e cadeia Gemini → Groq → Ollama → OpenRouter. Esse branch não está disponível neste clone. Os diagramas identificam essas partes, sem inventar assinaturas ou configurações.
- **Segurança em integração:** o branch separado `seguranca-app` contém o trabalho de endurecimento. O README diferencia os controles existentes dos que dependem dessa integração e da configuração do Supabase.

Diagramas de classes representam o domínio Dart, e não tabelas um a um. Por exemplo, `Lote` e `Venda` são objetos do domínio; os SQLs locais armazenam o lote em `produtos` e as linhas vendidas em `historico_vendas`.

Ao integrar os branches, conferir nomes e contratos de previsão, ordem dos provedores, variáveis de ambiente e políticas efetivamente aplicadas ao banco. Atualizar esta indicação de versão depois da conferência.
