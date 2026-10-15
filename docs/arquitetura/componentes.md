# Componentes

O Flutter atende web e Android. O pacote Dart `cic_domain` concentra regras reutilizáveis; o Supabase autentica o lojista e persiste os dados. A Edge Function recebe o token da sessão e mantém as credenciais dos provedores no servidor.

```mermaid
flowchart LR
    subgraph Cliente["Dispositivo do lojista"]
        UI["App Flutter — web / Android"]
        Estado["AppState — snapshot e atualização"]
        Dominio["cic_domain — estoque, vendas, ABC e aterramento"]
        Repo["Repository — consultas e RPCs"]
        Consultor["IaConsultor — regras locais e perguntas abertas"]
        UI --> Estado
        Estado --> Dominio
        Estado --> Repo
        UI --> Consultor
        Consultor --> Dominio
    end
    subgraph Supabase["Backend Supabase"]
        Auth["Auth — sessão / JWT"]
        DB[("Postgres — RLS por empresa_id = auth.uid()")]
        RPC["RPCs — registrar_venda, ajustar_estoque, salvar_produto"]
        Edge["Edge Function ia-consultor — valida JWT e consulta provedores"]
        Auth -.->|"identidade da sessão"| DB
        RPC --> DB
        Edge -->|"valida sessão"| Auth
    end
    UI --> Auth
    Repo -->|"sessão autenticada"| DB
    Repo --> RPC
    Consultor -->|"pergunta + contexto calculado + JWT"| Edge
    subgraph Provedores["Cadeia do branch ia-gratis — integração pendente nesta base"]
        Gemini["Gemini"]
        Groq["Groq"]
        Ollama["Ollama — servidor acessível pela Edge Function"]
        OpenRouter["OpenRouter — modelo gratuito configurado"]
        Gemini -.->|"indisponível / limite"| Groq
        Groq -.->|"indisponível / limite"| Ollama
        Ollama -.->|"indisponível / limite"| OpenRouter
    end
    Edge --> Gemini
```

As setas entre provedores representam a ordem de tentativa coordenada pela Edge Function, não chamadas de um provedor para outro. Na base `643fdd6`, o arquivo da função contém Gemini e DeepSeek opcional; a cadeia acima documenta a integração solicitada de `ia-gratis`.

“Grátis” depende das cotas e modelos disponíveis. Ollama precisa de uma máquina ligada e alcançável pelo backend: `localhost` dentro da Edge Function não é o computador do desenvolvedor. A indisponibilidade dos provedores deve terminar em resposta calculada no app. As chaves de IA e `service_role` não pertencem ao build Flutter.

Fontes: [AppState](../../lib/state/app_state.dart), [Repository](../../lib/data/repository.dart), [IaConsultor](../../lib/services/ia_consultor.dart), [domínio](../../packages/cic_domain/lib/) e [Edge Function](../../supabase/functions/ia-consultor/index.ts).
