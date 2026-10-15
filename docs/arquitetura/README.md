# Arquitetura do APP-CIC

Documentação da release `release-blindada` (PR #7), conferida no commit local `740534b`, sem consulta ao banco em produção. Os diagramas Mermaid são renderizados pelo GitHub ao abrir os arquivos Markdown.

| Diagrama | O que explica |
| --- | --- |
| [Casos de uso](casos-de-uso.md) | Rotina do lojista e funcionalidades |
| [Componentes](componentes.md) | Flutter, domínio, Supabase e provedores de IA |
| [Sequência do assistente](sequencia-assistente.md) | Cálculos, consulta de IA, aterramento e fallback |
| [Classes do domínio](classes-dominio.md) | Estoque, vendas, ABC e contratos de IA |
| [Modelo de dados](modelo-de-dados.md) | Tabelas, chaves e isolamento por loja |

## Versão documentada

A release reúne a cadeia Gemini → Groq → Ollama → OpenRouter, a previsão de demanda e a segurança. As fontes foram lidas na cópia local de `release-blindada`; o branch `docs-uml` contém apenas esta atualização de documentação, sem copiar código da release.

As regras calculadas no app atendem perguntas objetivas. Só perguntas abertas seguem para o servidor, que formata valores em reais, faz as tentativas de provedores e limpa nomes internos de campos antes da validação de aterramento no app.

`Config.demo` ativa a loja em memória de `lib/data/repository_demo.dart` por `--dart-define=DEMO=true`, dispensando login. Perguntas abertas ainda podem usar o servidor. Veja também o [roteiro](../tutorial/roteiro.md) e as [artes](../tutorial/arte/).

Diagramas de classes representam o domínio Dart, e não tabelas um a um. Por exemplo, `Lote` e `Venda` são objetos do domínio; os SQLs armazenam o lote em `produtos` e as linhas vendidas em `historico_vendas`.

A disponibilidade de provedores depende dos secrets, das cotas e do serviço implantado. RLS, confirmação de e-mail e limites de autenticação precisam estar aplicados/configurados no Supabase; a presença do código não comprova o estado da produção.
