# Sequência de uma pergunta ao assistente

O app calcula os números e usa a IA para interpretar o contexto. Perguntas objetivas têm resposta local. A previsão de demanda por média móvel de 30 dias é a extensão informada para `ia-gratis`; sua implementação não está nesta base.

```mermaid
sequenceDiagram
    actor L as Lojista
    participant A as App Flutter / IaConsultor
    participant D as cic_domain / regras calculadas
    participant E as Edge Function ia-consultor
    participant I as Provedores de IA
    participant G as ConsultorSeguro / aterramento
    L->>A: Faz uma pergunta
    A->>D: Obtém snapshot e verifica disponibilidade dos dados
    alt Estoque não confiável
        D-->>A: Dados indisponíveis
        A-->>L: Solicita atualização sem inventar números
    else Dados disponíveis
        A->>D: Calcula estoque, atenção, custos e ABC
        opt Integração ia-gratis
            A->>D: Calcula previsão por média móvel de 30 dias
        end
        D-->>A: Métricas, período, fontes e versão do snapshot
        alt Pergunta objetiva reconhecida
            A-->>L: Resposta determinística calculada
        else Pergunta aberta
            A->>E: Pergunta + contexto calculado + JWT
            E->>E: Valida sessão e identifica usuário pelo JWT
            Note over E,I: ia-gratis: Gemini → Groq → Ollama → OpenRouter
            E->>I: Solicita análise com contexto e regras
            alt Provedor retorna resposta
                I-->>E: Análise estruturada
                E-->>A: JSON de resposta
                A->>G: Valida formato, snapshot, números, produtos e classes
                alt Resposta consistente com o contexto
                    G-->>A: Resposta validada
                    A-->>L: Análise da IA
                else Número inventado ou outra inconsistência detectada
                    G-->>A: Descarta resposta e seleciona fallback
                    A-->>L: Dados calculados + aviso
                end
            else Falha, limite, timeout ou falta de configuração
                E-->>A: Erro de provedor ou indisponibilidade
                A->>G: Aplica política de retentativa limitada
                G-->>A: Fallback calculado após falha final
                A-->>L: Dados calculados + aviso
            end
        end
    end
```

Na implementação local, `ConsultorSeguro` chama `verificarAterramento` usando `ContextoAterramento`. A validação examina inclusive respostas com HTTP 200: sucesso de transporte não garante conteúdo correto. `ControleRequisicoes` impede que uma resposta antiga substitua uma pergunta mais recente.

O fallback atual combina estoque e ABC calculados. A política configurada em `IaConsultor` permite até duas tentativas com timeout de 18 segundos por tentativa. O esquema exato de previsão e suas regras de falta de histórico devem ser conferidos após integrar `ia-gratis`; média móvel é estimativa, não garantia de vendas futuras.

A trava reduz respostas com dados inventados detectáveis; não comprova toda afirmação em linguagem natural. Dados de origem incorretos também precisam ser tratados pelo app.

Fontes: [IaConsultor](../../lib/services/ia_consultor.dart), [ConsultorSeguro](../../packages/cic_domain/lib/src/ia/consultor_seguro.dart), [aterramento](../../packages/cic_domain/lib/src/ia/guarda_aterramento.dart) e [retentativas](../../packages/cic_domain/lib/src/ia/erros_ia.dart).
