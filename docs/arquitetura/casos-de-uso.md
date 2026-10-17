# Casos de uso do lojista

Representação dos casos de uso com `flowchart`, compatível com Mermaid no GitHub. As setas identificam acesso e dependências funcionais; não representam a ordem de todas as telas.

```mermaid
flowchart LR
    L["Lojista"]
    subgraph CIC["APP-CIC — operação da loja"]
        A(["Cadastrar conta, entrar e sair"])
        B(["Ler código de barras GS1"])
        C(["Cadastrar produto e entrada de estoque"])
        D(["Consultar e ajustar estoque e validade"])
        E(["Vender no PDV e registrar pagamento"])
        F(["Abrir e fechar caixa"])
        G(["Consultar movimentações"])
        H(["Acompanhar início e curva ABC"])
        I(["Consultar alertas de estoque e validade"])
        J(["Cadastrar custos e estimar ponto de equilíbrio"])
        K(["Perguntar ao assistente"])
        M(["Importar produtos por XML de NF-e"])
        P(["Consultar previsão de demanda"])
        V(["Validar saldo e registrar venda atomicamente"])
    end
    L --> A
    L --> B
    L --> D
    L --> E
    L --> F
    L --> G
    L --> H
    L --> I
    L --> J
    L --> K
    L --> M
    B --> C
    M --> C
    E --> V
    K --> P
    K --> H
    K --> I
```

O acesso aos dados reais depende de sessão autenticada e das políticas da loja. O build com `--dart-define=DEMO=true` usa `Config.demo` e `DemoRepository` para abrir uma loja de exemplo em memória sem login; perguntas abertas ao assistente ainda podem usar a Edge Function.

No PDV, informar Pix ou outra forma de pagamento registra o método; isso não equivale a uma confirmação automática por instituição financeira. A previsão de demanda está implementada na release em `PrevisaoDemanda`, com janela padrão de 30 dias e horizonte de reposição de 14 dias.

Fontes: [telas](../../lib/screens/), [repositório de dados](../../lib/data/repository.dart) e [venda atômica](../../supabase/migracao_v3_estoque_atomico_e_isolamento.sql).
