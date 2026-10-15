# Sequência de uma pergunta ao assistente

Fluxo de `release-blindada` (`740534b`). Perguntas sobre atenção, poucas unidades, validade, estar ganhando dinheiro, retorno, cobrir custos e reposição são tratadas primeiro por regras calculadas no app. Estoque, faturamento e ABC também têm respostas locais; perguntas fora do assunto da loja podem ser recusadas localmente.

```mermaid
sequenceDiagram
    actor L as Lojista
    participant A as Flutter / IaConsultor
    participant D as Domínio e regras locais
    participant G as ConsultorSeguro / aterramento
    participant E as Edge Function ia-consultor
    participant I as Provedores configurados
    L->>A: Faz uma pergunta
    A->>D: Verifica dados e trata pergunta pelas regras locais
    alt Dados de estoque não confiáveis
        D-->>A: Indisponibilidade dos dados
        A-->>L: Pede atualização sem inventar saldo
    else Dados disponíveis
        Note over A,D: Atenção, poucas unidades, validade, ganhando dinheiro, retorno, cobrir custos, reposição
        A->>D: Consulta estoque, custos, ABC e previsão de 30 dias conforme a pergunta
        D-->>A: Dados calculados e versão do snapshot
        alt Pergunta atendida localmente
            A-->>L: Resposta calculada sem chamar IA
        else Pergunta aberta sobre a loja
            A->>G: Contexto calculado com previsão e fallback de estoque/ABC
            G->>E: Pergunta e contexto; sessão ou chave pública no DEMO
            Note over G,E: Gateway verifica JWT conforme configuração implantada
            E->>E: Limita requisições e limpa pergunta
            E->>E: paraReais converte campos Centavos para textos R$ antes do modelo
            Note over E,I: Gemini → Groq → Ollama → OpenRouter, conforme configuração e tempo
            E->>I: Solicita análise em JSON
            opt Groq retorna 429 ou 503
                loop Próxima combinação enquanto houver tempo
                    E->>I: Alterna até 2 chaves x 3 modelos padrão
                end
            end
            alt Resposta disponível
                I-->>E: JSON de análise
                E->>E: semCampos traduz ou remove nomes internos conhecidos
                E-->>G: Contrato ia-v1 com versão do snapshot
                G->>G: Confere números, produtos, classes, previsão e snapshot
                alt Resposta consistente
                    G-->>A: Análise validada
                    A-->>L: Exibe análise
                else Número inventado ou inconsistência detectada
                    G-->>A: Descarta análise e usa fallback calculado
                    A-->>L: Estoque e ABC calculados com aviso
                end
            else Falha, timeout ou limite final
                E-->>G: Erro
                G->>G: Aplica retentativa limitada quando cabível
                G-->>A: Fallback calculado após falha final
                A-->>L: Dados calculados com aviso
            end
        end
    end
```

O servidor reserva até 15 segundos por chamada. Cada provedor anterior ao último recebe até 7 segundos; o último usa o restante, e novas tentativas cessam se restarem menos de 1,5 segundo. Portanto, não há garantia de percorrer todas as combinações.

Os modelos Groq padrão no código são `openai/gpt-oss-120b`, `llama-3.3-70b-versatile` e `openai/gpt-oss-20b`. As chaves são `GROQ_API_KEY` e `GROQ_API_KEY_2`. São até seis combinações padrão, não seis requisições simultâneas; um `GROQ_MODEL` distinto amplia a lista. Isso descreve a configuração do código, não confirma disponibilidade externa dos modelos.

`paraReais` percorre objetos e listas e converte campos numéricos terminados em `Centavos` para texto monetário brasileiro. Por exemplo, 123456 centavos vira `R$ 1.234,56`; o modelo recebe o valor pronto, sem precisar fazer a conversão. `semCampos` troca nomes como `coberturaDias` por linguagem de lojista e remove nomes internos conhecidos, como `produtoId` e `snapshotVersion`, do texto da resposta.

`ConsultorSeguro` chama `verificarAterramento` com `ContextoAterramento`, incluindo previsão. A validação ocorre mesmo após HTTP 200. `ControleRequisicoes` evita que respostas antigas substituam a consulta atual. O app configura até duas tentativas de 18 segundos cada; o fallback combina estoque e ABC calculados.

O limite da função é de 12 perguntas por minuto por identificador extraído do token, em memória da instância. Não é um limite global distribuído. No modo DEMO sem sessão, é usada a chave pública; os registros da loja continuam em memória, mas a consulta aberta pode sair do aparelho.

Previsão por média móvel é uma estimativa baseada no histórico, não garantia de vendas futuras. A trava descarta números inventados detectados e outras inconsistências; não comprova toda frase em linguagem natural.

Fontes: [IaConsultor](../../lib/services/ia_consultor.dart), [Edge Function](../../supabase/functions/ia-consultor/index.ts), [ConsultorSeguro](../../packages/cic_domain/lib/src/ia/consultor_seguro.dart), [aterramento](../../packages/cic_domain/lib/src/ia/guarda_aterramento.dart) e [retentativas](../../packages/cic_domain/lib/src/ia/erros_ia.dart).
