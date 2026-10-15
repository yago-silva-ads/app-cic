# Classes do domínio

Visão resumida de `packages/cic_domain`, com atributos selecionados. Dinheiro usado nos cálculos do domínio é representado em centavos inteiros. `Produto` aqui é o objeto do domínio, distinto do modelo de persistência em `lib/data/models.dart`.

```mermaid
classDiagram
    class Produto {
        String id
        String nome
        bool arquivado
        int precoVendaAtualCentavos
        int custoAtualCentavos
    }
    class Lote {
        String id
        String produtoId
        int quantidadeFisica
        int quantidadeReservada
    }
    class SnapshotEstoque {
        String versao
        DateTime atualizadoEm
        bool carregado
        bool demonstracao
    }
    class SaldoProduto {
        int fisico
        int reservado
        int quantidadeLotes
    }
    class ResumoEstoque {
        int produtosCadastrados
        int unidadesDisponiveis
        String snapshotVersion
    }
    class EstoqueService
    class EventoComercial {
        <<abstract>>
        String id
        DateTime instante
    }
    class Venda {
        StatusVenda status
        int descontoPedidoCentavos
    }
    class ItemVendido {
        String produtoId
        int quantidade
        int precoUnitarioCentavos
        int descontoItemCentavos
    }
    class Devolucao
    class MovimentacaoEstoque
    class MovimentoCaixa
    class ApuracaoRealizado
    class ResultadoApuracao
    class FatoProduto
    class CurvaAbcService
    class ResultadoCurvaAbc {
        ModoAbc modo
        PeriodoAbc periodo
        String snapshotVersion
    }
    class ItemCurvaAbc {
        String produtoId
        int valorBaseCentavos
        ClasseAbc classe
    }
    class ClasseAbc {
        <<enumeration>>
        A
        B
        C
    }
    class AlertaRuptura
    class EstadoAlerta
    class ProblemaDados
    class FusoLoja
    class Relogio {
        <<interface>>
    }
    class RelogioSistema
    class RelogioFixo
    class DataCivil
    class JanelaPeriodo
    SnapshotEstoque "1" o-- "*" Produto
    SnapshotEstoque "1" o-- "*" Lote
    Produto "1" <-- "*" Lote : produtoId
    Lote --> DataCivil : validade opcional
    SaldoProduto --> Produto
    EstoqueService ..> SnapshotEstoque
    EstoqueService ..> SaldoProduto
    EstoqueService ..> ResumoEstoque
    EventoComercial <|-- Venda
    EventoComercial <|-- Devolucao
    EventoComercial <|-- MovimentacaoEstoque
    EventoComercial <|-- MovimentoCaixa
    Venda "1" *-- "*" ItemVendido
    Devolucao ..> Venda : vendaId e itemId
    ApuracaoRealizado ..> EventoComercial
    ApuracaoRealizado ..> ResultadoApuracao
    ResultadoApuracao o-- FatoProduto
    CurvaAbcService ..> ApuracaoRealizado
    CurvaAbcService ..> EstoqueService
    CurvaAbcService --> FusoLoja
    CurvaAbcService --> Relogio
    Relogio <|.. RelogioSistema
    Relogio <|.. RelogioFixo
    CurvaAbcService ..> ResultadoCurvaAbc
    ResultadoCurvaAbc o-- ItemCurvaAbc
    ResultadoCurvaAbc o-- AlertaRuptura
    ResultadoCurvaAbc o-- ProblemaDados
    ResultadoCurvaAbc --> JanelaPeriodo
    ItemCurvaAbc --> ClasseAbc
    EstadoAlerta --> AlertaRuptura
```

Campos opcionais foram simplificados no desenho: preços e custos atuais de `Produto`, por exemplo, podem ser nulos. Um saldo desconhecido não deve ser convertido em zero.

```mermaid
classDiagram
    class ConsultaIa {
        String pergunta
        String snapshotVersion
        DateTime atualizadoEm
    }
    class ContextoAterramento
    class ConsultorSeguro
    class PoliticaRetentativa
    class ControleRequisicoes
    class RespostasDeterministicas
    class RespostaConsultor {
        String resposta
        TipoResposta tipo
        OrigemResposta origem
        String snapshotVersion
    }
    class ResumoEstoque
    class ResultadoCurvaAbc
    class AiGroundingGuard
    class AbcReportResult
    class AbcItemResult
    class PrevisaoDemanda {
        <<ia_gratis>>
    }
    class ItemPrevisao {
        <<ia_gratis>>
    }
    class SituacaoPrevisao {
        <<ia_gratis>>
    }
    ConsultaIa --> ResumoEstoque
    ConsultaIa --> ResultadoCurvaAbc
    ContextoAterramento ..> ResumoEstoque
    ContextoAterramento ..> ResultadoCurvaAbc
    ConsultorSeguro --> PoliticaRetentativa
    ConsultorSeguro ..> ContextoAterramento
    ConsultorSeguro ..> RespostaConsultor
    RespostasDeterministicas ..> RespostaConsultor
    AiGroundingGuard ..> AbcReportResult
    AbcReportResult o-- AbcItemResult
```

`ControleRequisicoes` é usado pelo serviço do app para ignorar respostas antigas. A validação do fluxo atual passa por `ConsultorSeguro` e pela função `verificarAterramento`; `AiGroundingGuard` e os contratos `AbcReportResult`/`AbcItemResult` também existem no pacote, mas não são a mesma implementação desse fluxo.

Os três nomes de previsão foram incluídos conforme o branch `ia-gratis` informado pelo responsável: `PrevisaoDemanda` representa a funcionalidade de previsão, `ItemPrevisao` seus itens e `SituacaoPrevisao` sua situação. Não há declaração local para confirmar campos, métodos, valores de enum ou associações, por isso eles aparecem sem relações inventadas. A regra funcional solicitada é a média móvel de 30 dias.

Fontes: [estoque](../../packages/cic_domain/lib/src/estoque/estoque.dart), [eventos comerciais](../../packages/cic_domain/lib/src/vendas/eventos.dart), [apuração](../../packages/cic_domain/lib/src/vendas/apuracao.dart), [ABC](../../packages/cic_domain/lib/src/abc/curva_abc.dart), [tempo](../../packages/cic_domain/lib/src/tempo/), [IA](../../packages/cic_domain/lib/src/ia/), [guard adicional](../../packages/cic_domain/lib/services/ai_grounding_guard.dart) e [contrato ABC](../../packages/cic_domain/lib/contracts/abc_contract.dart).
